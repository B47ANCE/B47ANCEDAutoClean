-- Native reads/constructors only. Mutations are delegated by Poc to vanilla Lua actions.
local P={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function P.new(options)
    options=options or {}
    for _,name in ipairs({'Fluids/ISFluidContainer','Fluids/ISFluidUtil','Fluids/ISFluidTransferAction',
        'TimedActions/ISTakeWaterAction','TimedActions/ISCleanBlood'}) do require(name) end
    local port={dose=options.dose or 0.01} -- building adapter uses authoritative Rooms settings
    -- Only the explicit offline installer may select local authority. A network
    -- client (including an ambiguous combined role) can never use this path.
    port.localAuthority=options.singlePlayer==true
    function port.server()
        if port.localAuthority then return not isServer() and not isClient() end
        return isServer() and not isClient()
    end
    port.now=getTimestampMs;port.id=getRandomUUID
    function port.tolerance(a,b)
        -- Eight float32 ULPs for the measured operands; never a recipe/minimum dose.
        local magnitude=math.max(math.abs(a),math.abs(b),0.01)
        local _,exponent=math.frexp(magnitude)
        return math.ldexp(1,exponent-24)*8
    end
    function port.cleanAmount() return ZomboidGlobals.CleanBloodBleachAmount end
    function port.actorValid(actor)
        if not port.server() or not actor or actor:isDead() then return false end
        if port.localAuthority then return getSpecificPlayer(actor:getPlayerNum())==actor end
        local players=getOnlinePlayers()
        for i=0,players:size()-1 do if players:get(i)==actor then return true end end
        return false
    end
    local function liveSquare(sq)
        return sq and getCell():getGridSquare(sq:getX(),sq:getY(),sq:getZ())==sq
    end
    local function allowed(sq,actor)
        return liveSquare(sq) and SafeHouse.isSafehouseAllowInteract(sq,actor) and SafeHouse.isSafehouseAllowLoot(sq,actor)
    end
    local function near(actor,sq)
        local stand=actor:getCurrentSquare()
        return liveSquare(stand) and stand:getZ()==sq:getZ()
            and math.max(math.abs(stand:getX()-sq:getX()),math.abs(stand:getY()-sq:getY()))<=1
            and (stand==sq or not stand:isBlockedTo(sq))
    end
    local function owned(actor,item)
        return item and actor:getInventory():getItemWithIDRecursiv(item:getID())==item
            and not item:getIsCraftingConsumed() and not item:isFavorite()
    end
    local function fluid(f)
        local total=f:getAmount() -- refresh species percentage caches before reading
        local s={total=total,capacity=f:getCapacity(),bleach=f:getSpecificFluidAmount(Fluid.Bleach),
            water=f:getSpecificFluidAmount(Fluid.Water)}
        for _,n in pairs(s) do assert(finite(n) and n>=0,'invalidFluidNumber') end
        assert(s.total<=s.capacity+port.tolerance(s.total,s.capacity),'overCapacity')
        assert(math.abs(s.total-s.bleach-s.water)<=port.tolerance(s.total,s.bleach+s.water),'unsupportedMixture')
        return s
    end
    local function footprint(target,actor)
        -- Native floor removal has no Z filter: conservatively validate every cell level.
        local cell=getCell();local lo,hi=cell:getMinZ(),cell:getMaxZ()
        assert(finite(lo) and finite(hi) and lo==math.floor(lo) and hi==math.floor(hi)
            and hi>=lo and hi-lo<64,'unsupportedLevels')
        local out={};local chunk=target:getChunk()
        for z=lo,hi do for y=target:getY()-1,target:getY()+1 do for x=target:getX()-1,target:getX()+1 do
            local sq=cell:getGridSquare(x,y,z)
            assert(sq and sq:getChunk()==chunk and allowed(sq,actor),'footprintUnavailableOrDenied')
            assert(not options.cleanAllowed or options.cleanAllowed(actor,sq),'roomCleaningDeniedOrOutsideScope')
            out[#out+1]=sq
        end end end
        return out
    end
    function port.bind(actor,selection)
        assert(port.actorValid(actor) and type(selection)=='table','invalidActor')
        local c={actor=actor,mode=options.building and selection.mode or 'recipe'}
        assert(c.mode=='recipe' or c.mode=='prepared' or c.mode=='refill','invalidMode')
        for _,k in ipairs({'bucket','bleach','tool','water','target'}) do c[k]=assert(selection[k],k) end
        assert(c.bucket~=c.bleach and c.bucket~=c.tool and c.bleach~=c.tool,'duplicateResource')
        assert(c.bucket:getFullType()=='Base.Bucket' and c.bleach:getFullType()=='Base.Bleach','unsupportedFixture')
        c.bucketFluid=assert(c.bucket:getFluidContainer());c.bleachFluid=assert(c.bleach:getFluidContainer())
        c.waterFluid=assert(c.water:getFluidContainer());c.waterSquare=assert(c.water:getSquare())
        c.bucketID=c.bucket:getID();c.bleachID=c.bleach:getID();c.toolID=c.tool:getID()
        c.footprint=footprint(c.target,actor)
        local keys={c.bucket,c.bleach,c.tool,c.water,c.bucketFluid,c.bleachFluid,c.waterFluid}
        for _,sq in ipairs(c.footprint) do keys[#keys+1]=sq end
        local initial=fluid(c.bucketFluid)
        c.dose=math.max(0,port.dose-initial.bleach)
        assert(c.bucketFluid:getCapacity()==10,'bucketMustBe10L')
        assert(c.mode=='recipe' and initial.total==0 or c.mode=='prepared' and initial.total>=port.cleanAmount() and initial.bleach>0
            or c.mode=='refill' and initial.total<port.cleanAmount() and initial.total+c.dose<10,'bucketStateInvalid')
        assert(c.bleachFluid:isPureFluid(Fluid.Bleach),'pureBleachRequired')
        assert(c.mode=='prepared' or c.bleachFluid:getAmount()>=c.dose+0.001,'bleachResidualRequired')
        assert(c.waterFluid:isPureFluid(Fluid.Water),'pureFiniteWaterRequired')
        assert(c.mode=='prepared' or c.waterFluid:getAmount()>=10-initial.total-c.dose+0.001,'waterResidualRequired')
        return c,keys
    end
    function port.measure(c)
        return {bucket=fluid(c.bucketFluid),bleach=fluid(c.bleachFluid),water=fluid(c.waterFluid),
            blood=c.target:haveBlood(),grime=c.target:haveGrime()}
    end
    function port.initialPhase(c) return c.mode=='prepared' and 'clean' or c.dose>0 and 'bleach' or 'water' end
    function port.doseFor(c) return c.dose end
    function port.initialAllowed() return true end -- mode-specific native validation is in bind
    function port.inspect(c,phase)
        local actor=c.actor
        assert(port.actorValid(actor),'actorUnavailable')
        for _,k in ipairs({'bucket','bleach','tool'}) do assert(owned(actor,c[k]) and c[k]:getID()==c[k..'ID'],'itemChanged') end
        assert(c.bucket:getFluidContainer()==c.bucketFluid and c.bleach:getFluidContainer()==c.bleachFluid,'componentChanged')
        assert(c.tool:hasTag(ItemTag.CLEAN_STAINS) and not c.tool:isBroken(),'invalidTool')
        assert(actor:getPrimaryHandItem()==c.tool,'toolMustBeEquipped')
        assert(liveSquare(c.target) and (options.building and phase~='clean' or near(actor,c.target)),'targetUnreachable')
        local current=footprint(c.target,actor)
        assert(#current==#c.footprint,'footprintChanged')
        for i,sq in ipairs(current) do assert(sq==c.footprint[i],'footprintChanged') end
        assert(c.water:getSquare()==c.waterSquare and allowed(c.waterSquare,actor)
            and (options.building and phase=='clean' or near(actor,c.waterSquare)),'sourceUnreachable')
        assert(not options.waterAllowed or options.waterAllowed(actor,c.waterSquare),'roomWaterDenied')
        assert(c.water:isExistInTheWorld() and c.water:getObjectIndex()>=0,'sourceRemoved')
        assert(c.water:getFluidContainer()==c.waterFluid and not c.water:getUsesExternalWaterSource(),'sourceChanged')
        assert(c.water:hasFluid() and c.waterFluid:isPureFluid(Fluid.Water),'sourceEmptyOrMixed')
        local state=port.measure(c)
        -- Native infinite-source sentinel is 10,000 L; exclude it and indirect plumbing.
        assert(state.water.total<10000 and c.water:getFluidAmount()==state.water.total,'nonFiniteSource')
        assert(actor:getFreeInventoryCapacity()>=c.bucketFluid:getCapacity()-state.bucket.total,'insufficientCarryHeadroom')
        return state
    end
    function port.makeAction(c,phase)
        local a
        if phase=='bleach' then
            a=ISFluidTransferAction:new(c.actor,ISFluidContainer:new(c.bleachFluid),c.bleachFluid,
                ISFluidContainer:new(c.bucketFluid),c.bucketFluid,c.dose)
            c.bleachStart=a.sourceStartAmount
        elseif phase=='water' then
            a=ISTakeWaterAction:new(c.actor,c.bucket,c.water,false)
            c.fillStart=a.startUsedAmount;c.fillAmount=a.waterUnit
            assert(math.abs(c.fillAmount-(c.bucketFluid:getCapacity()-c.fillStart))<=port.tolerance(c.fillAmount,10),'partialFillNotAllowed')
        else a=ISCleanBlood:new(c.actor,c.target,c.bucket) end
        return a
    end
    function port.actionMatches(c,phase,a)
        if not a or a.character~=c.actor then return false end
        if phase=='bleach' then
            return a.sourceFluidObject==c.bleachFluid and a.targetFluidObject==c.bucketFluid and a.amount==c.dose
                and a.source:getFluidContainer()==c.bleachFluid and a.target:getFluidContainer()==c.bucketFluid
                and a.sourceStartAmount==c.bleachStart
        elseif phase=='water' then
            return a.item==c.bucket and a.waterObject==c.water and a.startUsedAmount==c.fillStart
                and a.waterUnit==c.fillAmount and a.endUsedAmount==c.bucketFluid:getCapacity()
        else return a.square==c.target and a.cleaner==c.bucket end
    end
    function port.canMutate(c,phase,a)
        if phase=='bleach' then
            local remaining=c.bleachFluid:getAmount()-(a.sourceStartAmount-a.amount)
            return remaining<=0 or FluidContainer.CanTransfer(c.bleachFluid,c.bucketFluid)
        elseif phase=='water' then
            return c.bucketFluid:getAmount()>=c.bucketFluid:getCapacity()
                or FluidContainer.CanTransfer(c.waterFluid,c.bucketFluid)
        end
        return c.bucketFluid:contains(Fluid.Bleach) and c.bucketFluid:getAmount()>=port.cleanAmount()
            and ISCleanBlood.isValid(a)==true
    end
    return port
end
return P
