-- Explicit integration installer; this file is never auto-loaded or packaged.
local Action=require 'research/auto-clean/NativeAction'
local Server=require 'research/auto-clean/ServerTransport'
local Wire=require 'research/auto-clean/NativeWire'
local Job=require 'research/auto-clean/BuildingJob'
local Native=require 'research/auto-clean/BuildingNative'
local W={}
local function service()
 local ok,api=pcall(require,'B47ANCEDRooms/API')
 if not ok or not api.capabilities or api.capabilities().cleaning~=1 then return nil,'RoomsCleaningUnavailable' end
 for _,name in ipairs({'cleaningOptions','beginCleaningBuilding','readCleaningBuilding','validateCleaningBuilding','canCleanBuildingTile',
  'containsCleaningBuildingTile','endCleaningBuilding','canAccessAt'}) do if type(api[name])~='function' then return nil,'RoomsCleaningUnavailable' end end
 return api
end
function W.server()
 local rooms,why=service();if not rooms then return nil,why end
 local native=Native.new(rooms)
 if not native.server() then return nil,'notServer' end
 local job=Job.new(rooms,native)
 local transport,err=Wire.server(job,native,{describe=native.describe})
 if not transport then return nil,err end
 local budgets=setmetatable({},{__mode='k'})
 local function handler(module,command,actor,args)
  if module~=Server.module or not native.actorValid(actor) then return end
  if command~='buildingBegin' and command~='buildingPoll' and command~='buildingCancel' then return end
  if type(args)~='table' or args.protocol~=1 or not Action.token(args.request) then return end
  for k in pairs(args) do
   if k~='protocol' and k~='request' and not (k=='operation' and command~='buildingBegin') and not (k=='begin' and command=='buildingCancel') then return end
  end
  if command=='buildingPoll' and not Action.token(args.operation) or args.operation~=nil and not Action.token(args.operation)
   or command=='buildingCancel' and not Action.token(args.begin) then return end
  local b=budgets[actor];if not b or native.now()-b.time>=1000 then b={time=native.now(),count=0};budgets[actor]=b end
  b.count=b.count+1;if b.count>16 then return end
  local ok,result=pcall(function()
   if command=='buildingBegin' then return job.begin(actor,args.request) end
   if command=='buildingCancel' then
    job.cancelRequest(actor,args.begin)
    return args.operation and job.status(actor,args.operation) or {status='cancelled',closed=true}
   end
   return job.directive(actor,args.operation)
  end)
  if not ok then
   if args.operation then job.cancel(actor,args.operation,'nativeReadFailed') end
   result={status='cancelled',operation=args.operation,closed=true}
  end
  if not result then return end
  result.protocol=1;result.request=args.request
  sendServerCommand(actor,Server.module,'buildingState',result)
 end
 Events.OnClientCommand.Add(handler)
 local uninstall=transport.uninstall;local closed=false
 function transport.uninstall()
  if closed then return end;closed=true
  Events.OnClientCommand.Remove(handler);uninstall();job.close()
 end
 transport.jobs=job
 return transport
end
function W.client()
 local rooms,why=service();if not rooms then return nil,why end
 if not isClient() or isServer() then return nil,'notClient' end
 require 'TimedActions/WalkToTimedAction'
 require 'TimedActions/ISEquipWeaponAction'
 require 'TimedActions/ISUnequipAction'
 local function idle(actor) return #ISTimedActionQueue.getTimedActionQueue(actor).queue==0 end
 local function resolve(actor,view,phase)
  if phase~='fetch' and phase~='return' and phase~='equip' and phase~='unequip' then return nil end
  if type(view)~='table' or type(view.item)~='number' then return nil end
  local item=actor:getInventory():getItemWithID(view.item)
  if phase=='equip' then return item and ISEquipWeaponAction:new(actor,item,50,true,false,false) or nil end
  if phase=='unequip' then return item and ISUnequipAction:new(actor,item,50) or nil end
  local pos=view.position
  if type(pos)~='table' then return nil end
  local sq=getCell():getGridSquare(pos.x,pos.y,pos.z)
  if not sq or type(view.index)~='number' or view.index<0 or view.index>=sq:getObjects():size() then return nil end
  local obj=sq:getObjects():get(view.index)
  if type(view.ci)~='number' or view.ci<0 or view.ci>=obj:getContainerCount() then return nil end
  local container=obj:getContainerByIndex(view.ci)
  item=phase=='fetch' and container:getItemWithID(view.item) or item
  if not item then return nil end
  if type(view.ticks)~='number' or view.ticks<50 or view.ticks>500 then return nil end
  local a=ISBaseTimedAction:new(actor);a.item=item;a.maxTime=view.ticks
  function a:start() self.character:faceThisObject(obj);self:setActionAnim('Loot');self.character:reportEvent('EventLootItem') end
  return a -- client has no transfer callback; server calls the native transfer helper
 end
 local transport,err=Wire.client({resolve=resolve})
 if not transport then return nil,err end
 local active={};local api={active=active}
 local function send(actor,command,r)
  r.pending=getRandomUUID();r.sent=getTimestampMs()
  if command=='buildingBegin' then r.begin=r.pending end
  sendClientCommand(actor,Server.module,command,{protocol=1,request=r.pending,operation=r.operation,begin=command=='buildingCancel' and r.begin or nil})
 end
 local function done(actor,r,state)
  active[actor]=nil
  if actor.setHaloNote then
   local message=getText('UI_B47Rooms_CleaningSummary',state.actions or 0,state.skipped or 0,state.retained or 0)
   if state.status~='done' and state.status~='partial' then
    local keys={missingSupplies='CleaningMissingSupplies',insufficientCapacity='CleaningInsufficientCapacity',waterUnavailable='CleaningWaterUnavailable',unsupportedEquipment='CleaningUnsupportedEquipment'}
    message=getText('UI_B47Rooms_CleaningStopped',getText('UI_B47Rooms_'..(keys[state.reason] or keys[state.status] or 'CleaningChanged'))) ..' '..message
   elseif state.status=='partial' then message=getText('UI_B47Rooms_CleaningPartial')..' '..message end
   actor:setHaloNote(message)
  end
 end
 function api.cancel(actor)
  local r=active[actor];if not r then return end
  active[actor]=nil
  send(actor,'buildingCancel',r);transport.cancel(actor)
  if r.walk and r.walk.forceStop then pcall(r.walk.forceStop,r.walk) end
 end
 function api.start(actor)
  if active[actor] or not idle(actor) or not rooms.cleaningOptions().enabled then return false end
  local r={time=getTimestampMs(),next=0};active[actor]=r;send(actor,'buildingBegin',r);return true
 end
 local function handler(module,command,state)
  if module~=Server.module or command~='buildingState' or type(state)~='table' or state.protocol~=1 then return end
  local actor,r
  for a,v in pairs(active) do if v.pending==state.request then actor=a;r=v;break end end
  if not r or r.operation and r.operation~=state.operation then return end
  r.pending=nil;r.next=getTimestampMs()+250
  if not r.operation then r.operation=state.operation end
  if state.closed or state.status=='done' or state.status=='partial' or state.status=='cancelled' or state.status=='uncertain'
   or not r.operation then done(actor,r,state);return end
  if state.status=='action' then
   if not idle(actor) or not Action.phase(state.phase) or not transport.request(actor,r.operation,state.phase) then api.cancel(actor) end
  elseif state.status=='walk' then
   local p=state.position;local sq=p and getCell():getGridSquare(p.x,p.y,p.z)
   if not sq or not idle(actor) then api.cancel(actor);return end
   local stand=AdjacentFreeTileFinder.Find(sq,actor)
   if not stand then api.cancel(actor);return end
   local walk=ISWalkToTimedAction:new(actor,stand);r.walk=walk;r.walkAt=getTimestampMs()
   local stop=walk.stop
   function walk:stop() r.walk=nil;api.cancel(actor);if stop then stop(self) end end
   function walk:forceCancel() api.cancel(actor) end
   walk:setOnComplete(function() if active[actor]==r then r.walk=nil;r.next=0 end end)
   ISTimedActionQueue.add(walk)
  end
 end
 local function tick()
  for actor,r in pairs(active) do
   if actor:isDead() or getTimestampMs()-r.time>=1800000 or r.pending and getTimestampMs()-r.sent>=5000
    or r.walk and getTimestampMs()-r.walkAt>=30000 then api.cancel(actor)
   elseif not r.pending and not r.walk and not transport.busy(actor) then
    if not idle(actor) then api.cancel(actor)
    elseif r.operation and getTimestampMs()>=r.next then send(actor,'buildingPoll',r) end
   end
  end
 end
 local function menu(num,context,objects,test)
  if test then return end
  local actor=getSpecificPlayer(num);if not actor then return end
  if active[actor] then context:addOption(getText('UI_B47Rooms_CancelCleanBuilding'),nil,function() api.cancel(actor) end)
  elseif rooms.cleaningOptions().enabled and actor:getCurrentSquare() and actor:getCurrentSquare():getBuilding() and idle(actor) then
   context:addOption(getText('UI_B47Rooms_CleanBuilding'),nil,function() api.start(actor) end)
  end
 end
 Events.OnServerCommand.Add(handler);Events.OnTick.Add(tick);Events.OnFillWorldObjectContextMenu.Add(menu)
 local closed=false
 function api.uninstall()
  if closed then return end;closed=true
  for actor in pairs(active) do api.cancel(actor) end
  Events.OnServerCommand.Remove(handler);Events.OnTick.Remove(tick);Events.OnFillWorldObjectContextMenu.Remove(menu);transport.uninstall()
 end
 return api
end
return W
