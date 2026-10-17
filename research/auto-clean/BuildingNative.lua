-- Exact native references on the server. Client coordinates are presentation only.
local NativePort=require 'research/auto-clean/NativePort'
local N={}
local function listContains(container,item) return container and item and container:getItemWithID(item:getID())==item and item:getContainer()==container end
local function point(s) return {x=s:getX(),y=s:getY(),z=s:getZ()} end
local function cleanItem(item)
 return item and not item:isFavorite() and not item:getIsCraftingConsumed() and item:getAttachedSlot()==-1
end
function N.new(rooms)
 require 'TimedActions/ISTransferAction'
 require 'TimedActions/ISEquipWeaponAction'
 require 'TimedActions/ISUnequipAction'
 local probe=NativePort.new()
 local p={server=probe.server,now=probe.now,id=probe.id,position=point,hand=function(a) return a:getPrimaryHandItem() end}
 function p.actorValid(actor)
  if not probe.actorValid(actor) then return false end
  local q=B47ANCEDQuartermaster
  return not (q and q.Movement and (q.Movement.runs[actor] or q.Movement.operations[actor]))
 end
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
 local function configured(actor,record)
  local q=B47ANCEDQuartermaster
  if not q or not q.Targets or not q.Store or not q.Presets or not q.Targets.valid(record,actor) then return false end
  local config=q.Store.load(record,actor);local effective=config and q.Presets.resolve(config)
  if not effective then return false end
  for _,field in ipairs({'cats','items'}) do for _ in pairs(effective[field] or {}) do return true end end
  return false
 end
 function p.sourceValid(actor,r,action)
  local sq=r.obj and r.obj:getSquare()
  if not sq or sq~=r.square or getCell():getGridSquare(sq:getX(),sq:getY(),sq:getZ())~=sq or r.obj:getObjectIndex()<0
   or r.obj:getContainerByIndex(r.ci)~=r.container or r.container:getType()=='floor' or r.container:getContainingItem() then return false end
  if rooms.canAccessAt(actor,sq:getX(),sq:getY(),sq:getZ(),action).state~='allow' then return false end
  if action=='withdraw' and (rooms.canAccessAt(actor,sq:getX(),sq:getY(),sq:getZ(),'inspect').state~='allow' or not configured(actor,r)) then return false end
  if action=='deposit' then return configured(actor,r) and r.container:isItemAllowed(r.item) and r.container:hasRoomFor(actor,r.item) end
  return listContains(r.container,r.item) and r.container:isRemoveItemAllowed(r.item) and cleanItem(r.item) and not r.item:isEquipped()
 end
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
 function p.survey(actor,tiles,options)
  local s={tile=1,object=0,ci=0,item=0,targets={},water={},candidates={bucket={},bleach={},tool={}},seen={},work=0}
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
        s.items=s.container:getItems();s.item=0
        if s.items:size()>4096 then return {status='inventoryTooLarge'} end
       else s.ci=s.ci+1 end
      end
     end
    else
     local tile=tiles[s.tile]
     if not tile then
      if #s.targets==0 then return {status='ok',targets={},water=s.water} end
      local supplies={}
      for _,kind in ipairs({'bucket','bleach','tool'}) do
       table.sort(s.candidates[kind],function(a,b)
        if kind=='tool' and (a.item==actor:getPrimaryHandItem())~=(b.item==actor:getPrimaryHandItem()) then return a.item==actor:getPrimaryHandItem() end
        if a.carried~=b.carried then return a.carried==true end
        local pos=actor:getCurrentSquare()
        local function distance(r) return r.square and math.abs(pos:getX()-r.square:getX())+math.abs(pos:getY()-r.square:getY())+10*math.abs(pos:getZ()-r.square:getZ()) or 0 end
        if distance(a)~=distance(b) then return distance(a)<distance(b) end;return a.item:getID()<b.item:getID()
       end)
       supplies[kind]=s.candidates[kind][1];if not supplies[kind] then return {status='missingSupplies'} end
      end
      if supplies.tool.item:isRequiresEquippedBothHands() and actor:getSecondaryHandItem() and actor:getSecondaryHandItem()~=supplies.tool.item then return {status='unsupportedEquipment'} end
      local needed=10-supplies.bucket.item:getFluidContainer():getAmount()
      for _,r in pairs(supplies) do if not r.carried then needed=needed+r.item:getActualWeight() end end
      if actor:getFreeInventoryCapacity()<needed then return {status='insufficientCapacity'} end
      return {status='ok',targets=s.targets,supplies=supplies,water=s.water}
     end
     local sq=getCell():getGridSquare(tile.x,tile.y,tile.z);if not sq then return {status='buildingUnloaded'} end
     s.square=sq;s.objects=sq:getObjects();s.object=0;s.ci=0;s.waterSeen=false
     if s.objects:size()>512 then return {status='surveyTooLarge'} end
     if sq:haveBlood() then s.targets[#s.targets+1]=sq end
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
  return NativePort.new({building=true,dose=options.bleachML/1000,
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
 function p.action(actor,phase,record,options)
  local a
  if phase=='equip' then a=ISEquipWeaponAction:new(actor,record.item,50,true,false,false)
  elseif phase=='unequip' then a=ISUnequipAction:new(actor,record.item,50)
  else
   a=ISBaseTimedAction:new(actor);a.maxTime=options.transferSeconds*50;a.item=record.item
   a.srcContainer=phase=='fetch' and record.container or actor:getInventory()
   a.destContainer=phase=='fetch' and actor:getInventory() or record.container
   function a:complete()
    -- Native helper removes/synchronizes the source. Explicit native add sync
    -- is required for the destination when called outside ItemTransaction.
    local item=ISTransferAction:transferItem(actor,self.item,self.srcContainer,self.destContainer,nil)
    if item~=record.item or self.srcContainer:getItemWithID(item:getID())~=nil or not listContains(self.destContainer,item) then return false end
    sendAddItemToContainer(self.destContainer,item)
    return true
   end
  end
  return a
 end
 function p.actionValid(actor,phase,r,a,options)
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
