-- Offline fixture: native Lua callbacks, simulated world/network and float32 fluid model.
local Poc=require 'research/auto-clean/Poc'
local NativePort=require 'research/auto-clean/NativePort'
local cases=0
local function check(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));cases=cases+1
end
local function approx(a,b) assert(math.abs(a-b)<0.00002,tostring(a)..' ~= '..tostring(b)) end
local uid=0
SERVER=true;CLIENT=false
function isServer() return SERVER end
function isClient() return CLIENT end
function getTimestampMs() return NOW end
function getRandomUUID() uid=uid+1;return 'offline-'..uid end
function instanceof(o,kind) return o and o.kind==kind end
Fluid={Bleach='bleach',Water='water'}
ItemTag={CLEAN_STAINS='clean'}
Metabolics={LightDomestic=1,HeavyDomestic=2,MediumWork=3}
SafeHouse={isSafehouseAllowInteract=function(s) return not s.denied end,isSafehouseAllowLoot=function(s) return not s.denied end}
function emulateAnimEvent(action) action.events=(action.events or 0)+1 end
function sendItemStats(item) item.stats=(item.stats or 0)+1 end
ISBaseObject={}
function ISBaseObject:derive(name)
    local o={Type=name};o.__index=o;setmetatable(o,{__index=self});return o
end
function ISBaseObject:new() return setmetatable({},{__index=self}) end
ISBaseTimedAction=ISBaseObject:derive('ISBaseTimedAction')
function ISBaseTimedAction.new(self,c) return setmetatable({character=c},{__index=self}) end
function ISBaseTimedAction:getJobDelta() return self.progress or 0 end
function ISBaseTimedAction.stop(self) self.stopped=true end
function ISBaseTimedAction.perform(self) self.localQueueFinished=true end
-- Read and execute actual installed native Lua; no native Java is executed.
for _,p in ipairs({'shared/Fluids/ISFluidContainer.lua','shared/Fluids/ISFluidUtil.lua',
    'shared/Fluids/ISFluidTransferAction.lua','shared/TimedActions/ISTakeWaterAction.lua',
    'shared/TimedActions/ISCleanBlood.lua'}) do dofile(GAME_ROOT..'/media/lua/'..p) end
for _,name in ipairs({'Fluids/ISFluidContainer','Fluids/ISFluidUtil','Fluids/ISFluidTransferAction',
    'TimedActions/ISTakeWaterAction','TimedActions/ISCleanBlood'}) do package.loaded[name]=true end
FluidUtil={getTransferActionTimePerLiter=function() return 40 end,getMinTransferActionTime=function() return 20 end}
FluidContainer={}
function FluidContainer.CanTransfer(a,b) return a and b and a~=b and not b.locked and a:getAmount()>0 and b:getAmount()<b.capacity end
function FluidContainer.Transfer(a,b,amount)
    if not FluidContainer.CanTransfer(a,b) then return end
    amount=F32(math.min(amount,a:getAmount(),b.capacity-b:getAmount()))
    local total=a:getAmount()
    for _,k in ipairs({'bleach','water'}) do
        local moved=F32(amount*F32(a[k]/total))
        b[k]=F32(b[k]+moved);a[k]=F32(a[k]-moved)
        if math.abs(a[k])<0.0001 then a[k]=0 end
    end
end
local function fluid(capacity,bleach,water)
    local f={kind='FluidContainer',capacity=capacity,bleach=F32(bleach or 0),water=F32(water or 0)}
    function f:getCapacity() return self.capacity end
    function f:getAmount()
        local n=F32(self.bleach+self.water)
        if self.capacity-n<0.001 then return self.capacity end
        return n
    end
    function f:getSpecificFluidAmount(k) return self[k] or 0 end
    function f:contains(k) return (self[k] or 0)>0 end
    function f:isPureFluid(k) return self:getAmount()>0 and (k=='water' and self.bleach==0 or k=='bleach' and self.water==0) end
    function f:getOwner() return self.owner end
    function f:adjustAmount(amount)
        local scale=F32(F32(math.max(0,math.min(self.capacity,amount)))/self:getAmount())
        for _,k in ipairs({'bleach','water'}) do self[k]=F32(self[k]*scale);if self[k]<0.0001 then self[k]=0 end end
    end
    return f
end
local function item(id,fullType,fc)
    local i={kind='InventoryItem',id=id,fullType=fullType,fc=fc,syncs=0}
    if fc then fc.owner=i end
    function i:getID() return self.id end
    function i:getFullType() return self.fullType end
    function i:getFluidContainer() return self.fc end
    function i:getIsCraftingConsumed() return self.crafting==true end
    function i:isFavorite() return self.favorite==true end
    function i:isBroken() return self.broken==true end
    function i:hasTag() return self.tool==true end
    function i:isInPlayerInventory() return self.owner~=nil end
    function i:getContainer() return self.owner and self.owner.inv end
    function i:isEquipped() return false end
    function i:syncItemFields() self.syncs=self.syncs+1 end
    function i:setJobDelta() end
    function i:setBeingFilled() end
    return i
end
local function fixture()
    SERVER=true;CLIENT=false;NOW=0
    local chunk={};local cells={}
    local function key(x,y,z) return x..':'..y..':'..z end
    for x=9,11 do for y=9,11 do
        local sq={x=x,y=y,z=0,chunk=chunk}
        function sq:getX() return self.x end
        function sq:getY() return self.y end
        function sq:getZ() return self.z end
        function sq:getChunk() return self.chunk end
        function sq:isBlockedTo() return self.blocked==true end
        cells[key(x,y,0)]=sq
    end end
    local cell={min=0,max=0}
    function cell:getGridSquare(x,y,z) return cells[key(x,y,z)] end
    function cell:getMinZ() return self.min end
    function cell:getMaxZ() return self.max end
    function getCell() return cell end
    local target=cells[key(10,10,0)];target.blood=true;target.grime=true;target.cleans=0
    function target:haveBlood() return self.blood end
    function target:haveGrime() return self.grime end
    function target:removeBlood(a,b) assert(a==false and b==false);self.blood=false;self.cleans=self.cleans+1 end
    function target:removeGrime() self.grime=false end
    local actor={inv={items={}},stand=target,capacity=20}
    function actor:isDead() return self.dead==true end
    function actor:getInventory() return self.inv end
    function actor:getCurrentSquare() return self.stand end
    function actor:getPrimaryHandItem() return self.tool end
    function actor:getFreeInventoryCapacity() return self.capacity end
    function actor:isEquippedClothing() return false end
    function actor:isTimedActionInstant() return false end
    function actor:setMetabolicTarget() end
    function actor:faceThisObject() end
    function actor:stopOrTriggerSound() end
    function actor.inv:getItemWithIDRecursiv(id) return self.items[id] end
    function actor.inv:containsID(id) return self.items[id]~=nil end
    function actor.inv:containsEvalRecurse(predicate) for _,i in pairs(self.items) do if predicate(i) then return true end end;return false end
    function actor.inv:containsTagEval(tag,predicate) for _,i in pairs(self.items) do if i:hasTag(tag) and predicate(i) then return true end end;return false end
    local bucket=item(1,'Base.Bucket',fluid(10))
    local bleach=item(2,'Base.Bleach',fluid(1,1))
    local tool=item(3,'Base.Sponge');tool.tool=true;actor.tool=tool
    for _,i in ipairs({bucket,bleach,tool}) do i.owner=actor;actor.inv.items[i.id]=i end
    local water={kind='IsoObject',fc=fluid(20,0,12),sq=cells[key(10,11,0)],syncs=0}
    water.fc.owner=water
    function water:getSquare() return self.sq end
    function water:getFluidContainer() return self.fc end
    function water:getFluidAmount() return self.infinite and 10000 or self.fc:getAmount() end
    function water:getUsesExternalWaterSource() return self.external==true end
    function water:hasFluid() return self.fc:getAmount()>0 end
    function water:isExistInTheWorld() return not self.removed end
    function water:getObjectIndex() return self.removed and -1 or 0 end
    function water:sync() self.syncs=self.syncs+1 end
    function water:transferFluidTo(to,amount) FluidContainer.Transfer(self.fc,to,amount);self:sync();return amount end
    local players={actor}
    function getOnlinePlayers() return {size=function() return #players end,get=function(_,n) return players[n+1] end} end
    local port=NativePort.new();local poc=Poc.new(port)
    local selection={bucket=bucket,bleach=bleach,tool=tool,water=water,target=target}
    local f={poc=poc,port=port,actor=actor,bucket=bucket,bleach=bleach,tool=tool,water=water,target=target,selection=selection,cell=cell,cells=cells,players=players}
    function f:begin() local id,why=self.poc.begin(self.actor,self.selection);assert(id,why);self.id=id;return id end
    function f:next()
        local a,phase=self.poc.next(self.actor,self.id);assert(a,phase)
        a.netAction={getProgress=function() return a.progress or 0 end}
        return a,phase
    end
    function f:step() local a=self:next();assert(a:serverStart());assert(a:complete());return a end
    return f
end
check('happy path measured recipe and once-only clean',function()
    local f=fixture();f:begin();f:step();approx(f.bucket.fc.bleach,0.01);assert(f.bucket.fc.water==0)
    f:step();approx(f.bucket.fc:getAmount(),10);approx(f.bucket.fc.water,9.99)
    local a=f:step();assert(f.target.cleans==1 and not f.target.blood)
    approx(f.bucket.fc:getAmount(),10-ZomboidGlobals.CleanBloodBleachAmount)
    assert(not a:complete());assert(f.target.cleans==1)
    local result=f.poc.status(f.actor,f.id);assert(result.status=='done' and #result.steps==3)
    assert(result.steps[1].before.bucket.total==0);approx(result.steps[2].after.bucket.bleach,0.01)
    AUTO_CLEAN_POC_RESULT=result
end)
check('no mutation before start',function()
    local f=fixture();f:begin();local a=f:next();assert(not a:complete());assert(not a:update());assert(f.bucket.fc:getAmount()==0)
end)
check('one attached action per phase',function()
    local f=fixture();f:begin();local a=f:next();assert(not f.poc.next(f.actor,f.id));assert(a:serverStart());assert(not a:serverStart())
end)
check('client entry and callbacks fail closed',function()
    local f=fixture();f:begin();local a=f:next();CLIENT=true;assert(not f.poc.begin(f.actor,f.selection));assert(not a:serverStart());assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
end)
check('other actor cannot use or inspect operation',function()
    local f=fixture();f:begin();local other={};assert(not f.poc.next(other,f.id));assert(not f.poc.status(other,f.id));assert(not f.poc.cancel(other,f.id))
end)
check('forged or unknown id rejected',function()
    local f=fixture();assert(not f.poc.next(f.actor,'forged'));assert(not f.poc.status(f.actor,'forged'))
end)
check('bleach partial cancellation conserves actual work',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart());a.progress=0.25;assert(a:update())
    local amount=f.bucket.fc:getAmount();approx(amount,0.0025);a:serverStop();assert(not a:complete());assert(f.bucket.fc:getAmount()==amount and f.target.cleans==0)
    assert(f.poc.status(f.actor,f.id).status=='cancelled');assert(not f.poc.begin(f.actor,f.selection))
end)
check('fill animation partial cancellation is not refunded',function()
    local f=fixture();f:begin();f:step();local a=f:next();assert(a:serverStart());a.progress=0.5;a:animEvent('takeFluid',nil)
    local amount=f.bucket.fc:getAmount();approx(amount,5.005);local left=f.water.fc:getAmount()
    a:serverStop();a.progress=1;a:animEvent('takeFluid',nil);assert(not a:complete())
    assert(f.bucket.fc:getAmount()==amount and f.water.fc:getAmount()==left and f.target.cleans==0)
end)
check('repeated progress does not double consume',function()
    local f=fixture();f:begin();f:step();local a=f:next();assert(a:serverStart());a.progress=0.5;a:animEvent('takeFluid')
    local amount=f.bucket.fc:getAmount();a:animEvent('takeFluid');assert(f.bucket.fc:getAmount()==amount);assert(a:complete());approx(f.bucket.fc:getAmount(),10)
end)
check('changed mixture after grant rejects native mutation',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart());f.bucket.fc.water=F32(1)
    assert(not a:complete());assert(f.bleach.fc.bleach==1 and f.target.cleans==0)
end)
check('stale bucket instance and component rejected',function()
    for _,kind in ipairs({'item','component'}) do
        local f=fixture();f:begin();local a=f:next();assert(a:serverStart())
        if kind=='item' then f.actor.inv.items[1]=item(1,'Base.Bucket',fluid(10)) else f.bucket.fc=fluid(10) end
        assert(not a:complete());assert(f.bleach.fc.bleach==1)
    end
end)
check('saved cleaner cannot be substituted',function()
    local f=fixture();f:begin();f:step();f:step();local a=f:next();assert(a:serverStart());a.cleaner=f.bleach
    assert(not a:complete());assert(f.target.cleans==0)
end)
check('source removed or access revoked fails closed',function()
    for _,kind in ipairs({'removed','permission','ownership'}) do
        local f=fixture();f:begin();local a=f:next();assert(a:serverStart())
        if kind=='removed' then f.water.removed=true elseif kind=='permission' then f.water.sq.denied=true else f.actor.inv.items[2]=nil end
        assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
    end
end)
check('death disconnect and expiry stop next mutation',function()
    for _,kind in ipairs({'death','disconnect','expiry'}) do
        local f=fixture();f:begin();local a=f:next();assert(a:serverStart())
        if kind=='death' then f.actor.dead=true elseif kind=='disconnect' then table.remove(f.players) else NOW=120000 end
        f.poc.tick();assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
    end
end)
check('already cleaned target rejects before consuming solution',function()
    local f=fixture();f:begin();f:step();f:step();local a=f:next();assert(a:serverStart());f.target.blood=false;local before=f.bucket.fc:getAmount()
    assert(not a:complete());assert(f.bucket.fc:getAmount()==before and f.target.cleans==0)
end)
check('two actors cannot claim overlapping footprint',function()
    local f=fixture();f:begin()
    -- A second trusted selection of the same resources/target must be blocked even if actor validation is stubbed.
    local port=f.port;local actorValid=port.actorValid;port.actorValid=function() return true end
    local other={};local bind=port.bind;local context,keys=bind(f.actor,f.selection)
    port.bind=function() return context,keys end
    assert(not f.poc.begin(other,f.selection));port.actorValid=actorValid
end)
check('missing multilevel footprint and chunk edge rejected',function()
    for _,kind in ipairs({'level','chunk','nil','permission'}) do
        local f=fixture()
        if kind=='level' then f.cell.max=1 elseif kind=='chunk' then f.cells['9:9:0'].chunk={}
        elseif kind=='nil' then f.cells['9:9:0']=nil else f.cells['9:9:0'].denied=true end
        assert(not f.poc.begin(f.actor,f.selection))
    end
end)
check('tool invalid reach protected resources and headroom rejected',function()
    for _,kind in ipairs({'broken','equipped','favorite','carry','blocked'}) do
        local f=fixture()
        if kind=='broken' then f.tool.broken=true elseif kind=='equipped' then f.actor.tool=nil
        elseif kind=='favorite' then f.bleach.favorite=true elseif kind=='carry' then f.actor.capacity=1
        else f.actor.stand=f.water.sq;f.actor.stand.blocked=true end
        assert(not f.poc.begin(f.actor,f.selection))
    end
end)
check('finite pure sources only and empty bucket required',function()
    for _,kind in ipairs({'infinite','external','mixed','empty','bucket','dose'}) do
        local f=fixture()
        if kind=='infinite' then f.water.infinite=true elseif kind=='external' then f.water.external=true
        elseif kind=='mixed' then f.water.fc.bleach=1 elseif kind=='empty' then f.water.fc.water=1
        elseif kind=='bucket' then f.bucket.fc.water=1 else f.bleach.fc.bleach=0.01 end
        assert(not f.poc.begin(f.actor,f.selection))
    end
end)
check('forged quantity and native accounting fields denied',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart());a.amount=0/0;assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
    f=fixture();f:begin();f:step();a=f:next();assert(a:serverStart());a.waterUnit=math.huge;assert(not a:complete());approx(f.bucket.fc:getAmount(),0.01)
end)
check('native error after mutation is uncertain and never replayed',function()
    local f=fixture();f:begin();f:step();f:step();local a=f:next();assert(a:serverStart())
    local remove=f.target.removeBlood
    f.target.removeBlood=function(s,...) remove(s,...);error('after world mutation') end
    assert(not a:complete());assert(f.poc.status(f.actor,f.id).status=='uncertain');local amount=f.bucket.fc:getAmount()
    assert(not a:complete());assert(f.target.cleans==1 and f.bucket.fc:getAmount()==amount)
end)
check('reentrant complete cannot duplicate native callback',function()
    local f=fixture();f:begin();f:step();f:step();local a=f:next();assert(a:serverStart())
    local sync=f.bucket.syncItemFields
    f.bucket.syncItemFields=function(s) assert(not a:complete());sync(s) end
    assert(a:complete());assert(f.target.cleans==1)
end)
check('local perform cannot advance authoritative phase',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart());a:perform()
    assert(f.poc.status(f.actor,f.id).phase=='bleach' and f.bucket.fc:getAmount()==0)
end)
check('status copies and restart do not confer authority',function()
    local f=fixture();f:begin();local r=f.poc.status(f.actor,f.id);r.initial.bucket.total=99
    assert(f.poc.status(f.actor,f.id).initial.bucket.total==0)
    local restarted=Poc.new(f.port);assert(not restarted.next(f.actor,f.id));assert(f.bucket.fc:getAmount()==0)
end)
check('water invalid amount rejected without creating fluid',function()
    for _,amount in ipairs({-1,math.huge,0/0}) do
        local f=fixture();f:begin();f:step();local a=f:next();assert(a:serverStart());assert(not a:transferFluid(amount));approx(f.bucket.fc:getAmount(),0.01)
    end
end)
check('native filter denial prevents delegate invocation',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart());f.bucket.fc.locked=true
    assert(not a:complete());assert(f.bucket.fc:getAmount()==0 and f.bleach.fc.bleach==1)
end)
check('native resource gain is recorded uncertain without compensation',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart())
    local transfer=FluidContainer.Transfer
    FluidContainer.Transfer=function(source,target,amount) target.bleach=F32(target.bleach+amount) end
    assert(not a:complete());FluidContainer.Transfer=transfer
    assert(f.poc.status(f.actor,f.id).status=='uncertain');approx(f.bucket.fc.bleach,0.01);assert(f.bleach.fc.bleach==1)
    assert(not a:complete());approx(f.bucket.fc.bleach,0.01)
end)
check('cancellation releases claims and retains only bounded tombstones',function()
    local f=fixture()
    local first
    for _=1,40 do f:begin();first=first or f.id;f.poc.cancel(f.actor,f.id) end
    assert(f.poc.status(f.actor,f.id).status=='cancelled')
    assert(not f.poc.status(f.actor,first))
    assert(f.bucket.fc:getAmount()==0)
end)
check('native class methods are preserved',function()
    local c,t,w=ISCleanBlood.complete,ISFluidTransferAction.complete,ISTakeWaterAction.transferFluid
    local f=fixture();f:begin();f:step();f:step();f:step()
    assert(ISCleanBlood.complete==c and ISFluidTransferAction.complete==t and ISTakeWaterAction.transferFluid==w)
end)
check('partial fill before native failure stays uncertain',function()
    local f=fixture();f:begin();f:step();local a=f:next();assert(a:serverStart())
    local transfer=f.water.transferFluidTo
    f.water.transferFluidTo=function(s,to,amount) transfer(s,to,amount/2);error('partial transfer') end
    assert(not a:complete());local r=f.poc.status(f.actor,f.id)
    assert(r.status=='uncertain' and r.latest.bucket.water>0 and f.target.cleans==0)
    local amount=f.bucket.fc:getAmount();assert(not a:complete());assert(f.bucket.fc:getAmount()==amount)
end)
check('target re-resolution catches replacement square',function()
    local f=fixture();f:begin();local a=f:next();assert(a:serverStart());f.cells['10:10:0']={}
    assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
end)
AUTO_CLEAN_FIXTURE=fixture -- test-only shared fixture for native transport reconstruction tests
print('PASS OFFLINE Auto Clean guard: '..cases..' scenario groups; actual native Lua callbacks, simulated fluid/world/transport')
return cases
