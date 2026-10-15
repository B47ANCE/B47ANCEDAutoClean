-- Exact native references on the server. Client coordinates are presentation only.
local NativePort=require 'B47ANCEDAutoClean/NativePort'
local Supplies=require 'B47ANCEDQuartermaster/SupplyAPI'
local Options=require 'B47ANCEDAutoClean/Options'
local Trash=require 'B47ANCEDAutoClean/Trash'
local N={}
local function listContains(container,item) return container and item and container:getItemWithID(item:getID())==item and item:getContainer()==container end
local function point(s) return {x=s:getX(),y=s:getY(),z=s:getZ()} end
local function cleanItem(item)
 return item and not item:isFavorite() and not item:getIsCraftingConsumed() and item:getAttachedSlot()==-1
end
function N.new(rooms,options)
 require 'TimedActions/ISEquipWeaponAction'
 require 'TimedActions/ISUnequipAction'
 local singlePlayer=options and options.singlePlayer==true
 local probe=NativePort.new({singlePlayer=singlePlayer})
 local p={server=probe.server,localAuthority=probe.localAuthority,now=probe.now,id=probe.id,position=point,hand=function(a) return a:getPrimaryHandItem() end}
 function p.actorValid(actor)
  if not probe.actorValid(actor) then return false end
  return Supplies.actorAvailable(actor)
 end
 rooms=require('B47ANCEDAutoClean/AreaScope').new(rooms,p)
 p.scopes=rooms
 p.cleaningOptions=Options.read;p.optionsValid=Options.matches
 function p.trashSafe(actor,scope,record) return Trash.allowed(actor,record,scope,p,rooms) end
 function p.near(actor,square)
  local a=actor:getCurrentSquare()
  return a and square and a:getZ()==square:getZ() and math.max(math.abs(a:getX()-square:getX()),math.abs(a:getY()-square:getY()))<=1
   and (a==square or not a:isBlockedTo(square))
 end
 function p.canStart(actor)
  for _,item in ipairs({actor:getPrimaryHandItem() or false,actor:getSecondaryHandItem() or false}) do
   if item then
    local cleaning=item==actor:getPrimaryHandItem() and cleanItem(item) and item:hasTag(ItemTag.CLEAN_STAINS)
    if item:isForceDropHeavyItem() or item:canBeActivated() or (item:isRequiresEquippedBothHands() or item:isTwoHandWeapon()) and not cleaning then return false end
   end
  end
  local back=actor:getClothingItem_Back()
  return not back or not back:hasTag(ItemTag.REPLACE_PRIMARY)
 end
 function p.carried(actor,item) return listContains(actor:getInventory(),item) end
 function p.returned(record) return listContains(record.container,record.item) end
 local function configured(actor,record) return Supplies.configuredStorage(actor,record) end
 function p.sourceValid(actor,record,action) return Supplies.storageAllowed(actor,record,action) end
 local function role(item)
  if not cleanItem(item) then return nil end
  local f=item:getFluidContainer()
  if item:getFullType()=='Base.Bucket' and f and f:getCapacity()==10 then
   local total=f:getAmount()
   if total==0 or f:contains(Fluid.Bleach) and total>=probe.cleanAmount()
    and math.abs(total-f:getSpecificFluidAmount(Fluid.Bleach)-f:getSpecificFluidAmount(Fluid.Water))<=probe.tolerance(total,total) then return 'bucket' end
  elseif item:getFullType()=='Base.Bleach' and f and f:isPureFluid(Fluid.Bleach) then return 'bleach'
  elseif item:hasTag(ItemTag.CLEAN_STAINS) and not item:isBroken()
   and not item:IsClothing() and not item:IsInventoryContainer() and not item:isForceDropHeavyItem() and not item:canBeActivated()
   and (not instanceof(item,'HandWeapon') or item:getSwingAnim()~='Handgun')
   and item:getType()~='CandleLit' and item:getType()~='Lantern_HurricaneLit' then return 'tool' end
 end
 function p.survey(actor,tiles,options,scope)
  local s={tile=1,object=0,ci=0,item=0,targets={},trash={},water={},candidates={bucket={},bleach={},tool={}},seen={},work=0}
  local function missing(reason)
   if #s.trash>0 then return {status='ok',targets=s.targets,trash=s.trash,water=s.water,cleanFailure=reason} end
   return {status=reason}
  end
  local function candidate(item,record)
   local kind=role(item);if not kind or s.seen[item] then return end
   s.seen[item]=true;record.item=item;record.role=kind
   if kind=='bleach' and item:getFluidContainer():getAmount()<options.bleachML/1000+0.001 then return end
   if not record.carried and not p.sourceValid(actor,record,'withdraw') then return end
   s.candidates[kind][#s.candidates[kind]+1]=record
  end
  local carried=actor:getInventory():getItems()
  if carried:size()>4096 then return {step=function() return {status='inventoryTooLarge'} end} end
  s.carried=carried;s.carriedIndex=0
  function s.step()
   for _=1,64 do
    s.work=s.work+1;if s.work>262144 then return {status='surveyTooLarge'} end
    if s.carriedIndex<carried:size() then
     candidate(carried:get(s.carriedIndex),{carried=true});s.carriedIndex=s.carriedIndex+1
    elseif s.items then
     if s.item>=s.items:size() then s.items=nil;s.ci=s.ci+1
     else local i=s.items:get(s.item);s.item=s.item+1
      candidate(i,{obj=s.obj,ci=s.ci,container=s.container,square=s.square})
     end
    elseif s.objects then
     if s.object>=s.objects:size() then s.objects=nil;s.tile=s.tile+1
     else
      s.obj=s.objects:get(s.object)
      if s.ci==0 and not s.waterSeen then
       s.waterSeen=true
       if options.trashEnabled and (not scope or rooms.cleaningTargetTile(actor,scope,s.square:getX(),s.square:getY(),s.square:getZ())) then
        local record=Trash.capture(s.obj,s.square)
        if record then s.trash[#s.trash+1]=record end
       end
       local f=s.obj:getFluidContainer()
       if f and f:isPureFluid(Fluid.Water) and f:getAmount()>0 and f:getAmount()<10000 and s.obj:getFluidAmount()==f:getAmount()
        and not s.obj:getUsesExternalWaterSource() then s.water[#s.water+1]=s.obj end
      end
      local count=s.obj:getContainerCount()
      if count>100 then return {status='surveyTooLarge'} end
      if s.ci>=count then s.object=s.object+1;s.ci=0;s.waterSeen=false
      else
       s.container=s.obj:getContainerByIndex(s.ci)
       local r={obj=s.obj,ci=s.ci,container=s.container,square=s.square}
       if options.borrow and configured(actor,r) then
        local reason;s.items,reason=Supplies.storageItems(actor,r);s.item=0
        if not s.items then
         if reason=='inventoryTooLarge' then return {status='inventoryTooLarge'} end
         s.ci=s.ci+1
        end
       else s.ci=s.ci+1 end
      end
     end
    else
     local tile=tiles[s.tile]
     if not tile then
      if #s.targets==0 then return {status='ok',targets={},trash=s.trash,water=s.water} end
      local supplies={}
      for _,kind in ipairs({'bucket','bleach','tool'}) do
       table.sort(s.candidates[kind],function(a,b)
        if kind=='tool' and (a.item==actor:getPrimaryHandItem())~=(b.item==actor:getPrimaryHandItem()) then return a.item==actor:getPrimaryHandItem() end
        if a.carried~=b.carried then return a.carried==true end
        local pos=actor:getCurrentSquare()
        local function distance(r) return r.square and math.abs(pos:getX()-r.square:getX())+math.abs(pos:getY()-r.square:getY())+10*math.abs(pos:getZ()-r.square:getZ()) or 0 end
        if distance(a)~=distance(b) then return distance(a)<distance(b) end;return a.item:getID()<b.item:getID()
       end)
       supplies[kind]=s.candidates[kind][1];if not supplies[kind] then return missing('missingSupplies') end
      end
      if supplies.tool.item:isRequiresEquippedBothHands() and actor:getSecondaryHandItem() and actor:getSecondaryHandItem()~=supplies.tool.item then return missing('unsupportedEquipment') end
      local needed=10-supplies.bucket.item:getFluidContainer():getAmount()
      for _,r in pairs(supplies) do if not r.carried then needed=needed+r.item:getActualWeight() end end
      if actor:getFreeInventoryCapacity()<needed then return missing('insufficientCapacity') end
      return {status='ok',targets=s.targets,trash=s.trash,supplies=supplies,water=s.water}
     end
     local sq=getCell():getGridSquare(tile.x,tile.y,tile.z);if not sq then return {status='buildingUnloaded'} end
     s.square=sq;s.objects=sq:getObjects();s.object=0;s.ci=0;s.waterSeen=false
     if s.objects:size()>512 then return {status='surveyTooLarge'} end
     if sq:haveBlood() and (not scope or rooms.cleaningTargetTile(actor,scope,tile.x,tile.y,tile.z)) then s.targets[#s.targets+1]=sq end
    end
   end
   return {status='waiting'}
  end
  return s
 end
 function p.bucketMode(bucket)
  local f=bucket:getFluidContainer();local total=f:getAmount()
  if total>=probe.cleanAmount() and f:contains(Fluid.Bleach) then return 'prepared' end
  return total==0 and 'recipe' or 'refill'
 end
 function p.waterSource(actor,sources,bucket,options,fill)
  local fluid=bucket:getFluidContainer()
  local dose=math.max(0,options.bleachML/1000-fluid:getSpecificFluidAmount(Fluid.Bleach))
  local needed=fill and 10-fluid:getAmount()-dose+0.001 or 0.001
  for _,o in ipairs(sources) do
   local s=o:getSquare();local f=o:getFluidContainer()
   if s and o:isExistInTheWorld() and not o:getUsesExternalWaterSource() and f and f:isPureFluid(Fluid.Water)
    and f:getAmount()>=needed and f:getAmount()<10000 and o:getFluidAmount()==f:getAmount()
    and rooms.canAccessAt(actor,s:getX(),s:getY(),s:getZ(),'withdraw').state=='allow' then return o end
  end
 end
 function p.cleanPort(actor,scope,options)
  return NativePort.new({building=true,singlePlayer=singlePlayer,dose=options.bleachML/1000,
   cleanAllowed=function(a,s) return a==actor and rooms.canCleanBuildingTile(a,scope,s:getX(),s:getY(),s:getZ()).state=='allow' end,
   waterAllowed=function(a,s) return rooms.containsCleaningBuildingTile(a,scope,s:getX(),s:getY(),s:getZ())
    and rooms.canAccessAt(a,s:getX(),s:getY(),s:getZ(),'withdraw').state=='allow' end})
 end
 p.blood=function(s) return s:haveBlood() end
 function p.targetSafe(actor,scope,target)
  local cell=getCell();local lo,hi=cell:getMinZ(),cell:getMaxZ()
  if hi<lo or hi-lo>=64 then return false end
  for z=lo,hi do for y=target:getY()-1,target:getY()+1 do for x=target:getX()-1,target:getX()+1 do
   local s=cell:getGridSquare(x,y,z)
   if not s or s:getChunk()~=target:getChunk() or rooms.canCleanBuildingTile(actor,scope,x,y,z).state~='allow' then return false end
  end end end
  return true
 end
 function p.action(actor,phase,record,options,scope)
  if phase=='trash' then return Trash.action(actor,record,scope,options,p,rooms) end
  local a
  if phase=='equip' then a=ISEquipWeaponAction:new(actor,record.item,50,true,false,false)
  elseif phase=='unequip' then a=ISUnequipAction:new(actor,record.item,50)
  else
   a=Supplies.transferAction(actor,record,phase,options.transferSeconds)
  end
  return a
 end
 function p.actionValid(actor,phase,r,a,options,scope)
  if phase=='trash' then return a.trashObject==r.object and a.character==actor and p.trashSafe(actor,scope,r) and p.near(actor,r.square) end
  if (not cleanItem(r.item) and not r.restore) or r.item:getIsCraftingConsumed() or a.item~=r.item or a.character~=actor then return false end
  if phase=='fetch' or phase=='return' then
   if phase=='fetch' and (role(r.item)~=r.role or r.role=='bleach' and r.item:getFluidContainer():getAmount()<options.bleachML/1000+0.001) then return false end
   local src=phase=='fetch' and r.container or actor:getInventory()
   local dst=phase=='fetch' and actor:getInventory() or r.container
   return a.srcContainer==src and a.destContainer==dst and listContains(src,r.item) and p.near(actor,r.square)
    and p.sourceValid(actor,r,phase=='fetch' and 'withdraw' or 'deposit') and src:isRemoveItemAllowed(r.item)
    and dst:isItemAllowed(r.item) and dst:hasRoomFor(actor,r.item)
  end
  if not p.carried(actor,r.item) or r.item:isForceDropHeavyItem() then return false end
  for _,item in ipairs({actor:getPrimaryHandItem() or false,actor:getSecondaryHandItem() or false}) do
   if item and item:isForceDropHeavyItem() then return false end
  end
  local back=actor:getClothingItem_Back()
  if back and back:hasTag(ItemTag.REPLACE_PRIMARY) then return false end
  if phase=='equip' then return a.primary==true and a.alwaysTurnOn==false and a.twoHands==(r.item:isRequiresEquippedBothHands()==true) and a:isValid() end
  return phase=='unequip' and a:isValid()
 end
 function p.describe(a,phase)
  if phase=='trash' then return {position=point(a.trashObject:getSquare()),index=a.trashObject:getObjectIndex(),sprite=a.trashObject:getSprite():getName(),ticks=a.maxTime} end
  if phase=='equip' or phase=='unequip' then return {item=a.item:getID(),ticks=a.maxTime} end
  if phase=='fetch' or phase=='return' then
   local container=phase=='fetch' and a.srcContainer or a.destContainer
   local obj=container:getParent();local sq=obj:getSquare()
   local ci
   for i=0,obj:getContainerCount()-1 do if obj:getContainerByIndex(i)==container then ci=i;break end end
   return {item=a.item:getID(),position=point(sq),index=obj:getObjectIndex(),ci=ci,ticks=a.maxTime}
  end
 end
 return p
end
return N
