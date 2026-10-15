-- Server-owned building job. Rooms owns geometry/policy; Native owns vanilla calls.
local Poc=require 'research/auto-clean/Poc'
local B={}
function B.new(rooms,native)
 local jobs,owners,claims,history={},{},{},{}
 local requests=setmetatable({},{__mode='k'})
 local api={}
 local function remember(actor,request,value)
  local seen=requests[actor]
  if not seen then seen={map={},order={}};requests[actor]=seen end
  if not seen.map[request] then seen.order[#seen.order+1]=request end
  seen.map[request]=value
  if #seen.order>16 then seen.map[table.remove(seen.order,1)]=nil end
 end
 local function find(actor,id)
  local j=jobs[id];if not native.server() or not j or j.actor~=actor then return nil end;return j
 end
 local function close(j,status,reason)
  if j.closed then return false end
  if j.inFlight then j.cancelReason=reason or 'cancelled';return false,'inFlight' end
  j.closed=true;j.status=status;j.reason=reason
  if j.child then j.poc.cancel(j.actor,j.child,reason) end
  rooms.endCleaningBuilding(j.actor,j.scope)
  owners[j.actor]=nil
  for _,item in pairs(j.supplies or {}) do if claims[item.item]==j then claims[item.item]=nil end end
  j.action=nil;j.survey=nil;j.tiles=nil;j.poc=nil;j.child=nil
  j.retained=0;j.unaccounted=0
  for _,record in pairs(j.supplies or {}) do if not record.carried then
   local ok,carried=pcall(native.carried,j.actor,record.item)
   local observed,returned=pcall(native.returned,record)
   if ok and carried then j.retained=j.retained+1
   elseif not ok or not observed or not returned then j.unaccounted=j.unaccounted+1 end
  end end
  j.supplies=nil;j.borrowed=nil;j.targets=nil;j.sources=nil;j.record=nil;j.water=nil;j.options=nil;j.originalHand=nil
  history[#history+1]=j.id;if #history>32 then jobs[table.remove(history,1)]=nil end
  return false
 end
 local function valid(j)
  return not j.closed and native.actorValid(j.actor) and native.now()-j.time<1800000
   and rooms.validateCleaningBuilding(j.actor,j.scope).status=='ok'
 end
 function api.begin(actor,request)
  if not native.server() or not native.actorValid(actor) then return {status='invalid'} end
  if native.canStart and not native.canStart(actor) then return {status='unsupportedEquipment'} end
  local seen=requests[actor]
  if seen and seen.map[request] then
   local previous=jobs[seen.map[request]]
   return {status=previous and previous.status or 'cancelled',operation=previous and previous.id or nil,closed=previous==nil or previous.closed==true}
  end
  local old=owners[actor]
  if old then return {status=old.request==request and 'waiting' or 'busy',operation=old.request==request and old.id or nil} end
  local count=0;for _ in pairs(owners) do count=count+1 end;if count>=4 then return {status='busy'} end
  local scope=rooms.beginCleaningBuilding(actor)
  if scope.status~='waiting' then return scope end
  local id=native.id()
  local j={id=id,actor=actor,scope=scope.scope,request=request,time=native.now(),status='ready',phase='waiting',
   actions=0,alreadyClean=0,skipped=0,skipReasons={},borrowed={},returned=0,retained=0,originalHand=native.hand(actor)}
  jobs[id]=j;owners[actor]=j
  remember(actor,request,id)
  return {status='waiting',operation=id}
 end
 local function skip(j,reason)
  j.skipped=j.skipped+1;j.skipReasons[reason]=(j.skipReasons[reason] or 0)+1;j.index=j.index+1
 end
 local function initialize(j)
  local scope=rooms.readCleaningBuilding(j.actor,j.scope)
  if scope.status=='waiting' then return false end
  if scope.status~='ok' then close(j,'cancelled',scope.status);return false end
  if not j.survey then j.tiles=scope.tiles;j.options=scope.options;j.survey=native.survey(j.actor,j.tiles,j.options) end
  local result=j.survey.step()
  if result.status=='waiting' then return false end
  if result.status~='ok' then close(j,'cancelled',result.status);return false end
  j.targets=result.targets;j.index=1;j.total=#j.targets
  if #j.targets==0 then close(j,'done','alreadyClean');return false end
  j.supplies=result.supplies;j.sources=result.water;j.survey=nil;j.stage='fetch';j.fetchIndex=1
  if not j.supplies then close(j,'cancelled','missingSupplies');return false end
  for _,record in pairs(j.supplies) do if claims[record.item] then close(j,'cancelled','supplyBusy');return false end end
  for _,record in pairs(j.supplies) do claims[record.item]=j end
  j.poc=Poc.new(native.cleanPort(j.actor,j.scope,j.options))
  return true
 end
 local function ready(j,phase,record,position)
  j.phase=phase;j.status='ready';j.record=record
  if position and not native.near(j.actor,position) then return {status='walk',operation=j.id,position=native.position(position)} end
  return {status='action',operation=j.id,phase=phase}
 end
 function api.directive(actor,id)
  local j=find(actor,id);if not j then return {status='notOwned'} end
  if j.closed then return api.status(actor,id) end
  if not j.targets then
   if not initialize(j) then return j.closed and api.status(actor,id) or {status='waiting',operation=id} end
  end
  if not valid(j) then close(j,'cancelled','scopeChanged');return api.status(actor,id) end
  if j.action then return {status='waiting',operation=id} end
  local supplies=j.supplies
  if j.stage=='fetch' then
   local order={'bucket','bleach','tool'}
   while j.fetchIndex<=#order do
    local record=supplies[order[j.fetchIndex]]
    if native.carried(actor,record.item) then j.fetchIndex=j.fetchIndex+1
    else
     if not j.options.borrow or not native.sourceValid(actor,record,'withdraw') then close(j,'cancelled','supplyChanged');return api.status(actor,id) end
     return ready(j,'fetch',record,record.square)
    end
   end
   j.stage='clean'
  end
  if j.stage=='clean' then
   if native.hand(actor)~=supplies.tool.item then
    if j.equipped or native.hand(actor)~=j.originalHand then close(j,'cancelled','handsChanged');return api.status(actor,id) end
    return ready(j,'equip',{item=supplies.tool.item})
   end
   for _=1,32 do
    local target=j.targets[j.index]
    if j.child then
     local state=j.poc.status(actor,j.child)
     if state.status=='done' then j.child=nil;j.actions=j.actions+1;j.index=j.index+1;target=j.targets[j.index]
     elseif state.status~='ready' and state.status~='running' then close(j,state.status,state.reason);return api.status(actor,id) end
    end
    if not target then j.stage='return';j.returnIndex=#j.borrowed;break end
    if not native.blood(target) then j.alreadyClean=j.alreadyClean+1;j.index=j.index+1
    elseif not native.targetSafe(actor,j.scope,target) then
     if j.child then close(j,'cancelled','cleaningPermissionChanged');return api.status(actor,id) end
     skip(j,'unsafeFootprint')
    else
     if not j.child then
      local mode=native.bucketMode(supplies.bucket.item)
      local needsFill=mode~='prepared'
      j.water=native.waterSource(actor,j.sources,supplies.bucket.item,j.options,needsFill)
      if not j.water then close(j,'cancelled','waterUnavailable');return api.status(actor,id) end
      local destination=needsFill and j.water:getSquare() or target
      if not native.near(actor,destination) then return {status='walk',operation=id,position=native.position(destination)} end
      local child,why=j.poc.begin(actor,{bucket=supplies.bucket.item,bleach=supplies.bleach.item,tool=supplies.tool.item,
       water=j.water,target=target,mode=mode})
      if not child then close(j,'cancelled',why);return api.status(actor,id) end
      j.child=child
     end
     local state=j.poc.status(actor,j.child)
     if state.status=='done' then j.child=nil;j.actions=j.actions+1;j.index=j.index+1
     elseif state.status~='ready' and state.status~='running' then close(j,state.status,state.reason);return api.status(actor,id)
     else return ready(j,state.phase,nil,state.phase=='clean' and target or j.water:getSquare()) end
    end
   end
   if j.stage=='clean' then return {status='waiting',operation=id} end
  end
  if j.stage=='return' then
   if j.originalHand==supplies.tool.item then j.restoreDone=true end
   if not j.restoreDone and native.hand(actor)==supplies.tool.item then
    if j.originalHand and native.carried(actor,j.originalHand) then return ready(j,'equip',{item=j.originalHand,restore=true}) end
    return ready(j,'unequip',{item=supplies.tool.item,restore=true})
   end
   j.restoreDone=true
   for _=1,3 do
    local record=j.borrowed[j.returnIndex]
    if not record then close(j,j.skipped>0 and 'partial' or 'done',j.skipped>0 and 'targetsSkipped' or 'complete');return api.status(actor,id) end
    if not j.options.returns or not native.carried(actor,record.item) or not native.sourceValid(actor,record,'deposit') then
     j.returnIndex=j.returnIndex-1
    else return ready(j,'return',record,record.square) end
   end
  end
  return {status='waiting',operation=id}
 end
 function api.status(actor,id)
  local j=find(actor,id);if not j then return nil,'notOwned' end
  return {operation=id,id=id,status=j.status,phase=j.phase,reason=j.reason,total=j.total or 0,actions=j.actions,
   alreadyClean=j.alreadyClean,skipped=j.skipped,returned=j.returned,retained=j.retained,unaccounted=j.unaccounted or 0,closed=j.closed==true}
 end
 function api.next(actor,id)
  local j=find(actor,id)
  if not j or not valid(j) or j.action or j.phase=='waiting' then return nil,'notReady' end
  local phase=j.phase;local action
  if phase=='bleach' or phase=='water' or phase=='clean' then action=j.poc.next(actor,j.child)
  else action=native.action(actor,phase,j.record,j.options) end
  if not action then close(j,'cancelled','constructionFailed');return nil,'constructionFailed' end
  j.action=action
  local start,complete,update,transfer=action.serverStart,action.complete,action.update,action.transferFluid
  local started,completing=false,false
  local function check(self)
   return self==j.action and valid(j) and (phase=='bleach' or phase=='water' or phase=='clean' or native.actionValid(actor,phase,j.record,self,j.options))
  end
  function action:serverStart()
   if started or not check(self) then return false end
   started=true;j.status='running'
   if start then return start(self) end;return true
  end
  function action:complete()
   if completing then return false end
   if not started or not check(self) then close(j,'cancelled','stateChanged');return false end
   completing=true
   j.inFlight=true
   local ok,result=pcall(complete,self)
   j.inFlight=false
   completing=false
   if not ok or result~=true then close(j,'uncertain','nativeOutcomeUncertain');return false end
   if phase=='fetch' then
    if not native.carried(actor,j.record.item) then close(j,'uncertain','fetchNotObserved');return false end
    j.borrowed[#j.borrowed+1]=j.record;j.fetchIndex=j.fetchIndex+1
   elseif phase=='return' then
    if native.carried(actor,j.record.item) or not native.returned(j.record) then close(j,'uncertain','returnNotObserved');return false end
    j.record.returned=true;j.returned=j.returned+1;j.returnIndex=j.returnIndex-1
   elseif phase=='clean' then
    local state=j.poc.status(actor,j.child)
    if state.status~='done' then close(j,'uncertain','cleanNotObserved');return false end
    j.child=nil;j.actions=j.actions+1;j.index=j.index+1
   elseif j.record and j.record.restore then j.restoreDone=true
   elseif phase=='equip' then j.equipped=true end
   j.action=nil;j.record=nil;j.phase='waiting';j.status='ready'
   if j.cancelReason then close(j,'cancelled',j.cancelReason) end
   return true
  end
  if update then function action:update() if started and check(self) then return update(self) end;return false end end
  if transfer then function action:transferFluid(n) if started and check(self) then return transfer(self,n) end;return false end end
  function action:serverStop() return api.cancel(actor,id,'nativeStopped') end
  function action:stop() return api.cancel(actor,id,'nativeStopped') end
  function action:forceCancel() return api.cancel(actor,id,'nativeCancelled') end
  return action,phase
 end
 function api.cancel(actor,id,reason) local j=find(actor,id);if not j or j.closed then return false end;return close(j,'cancelled',reason or 'cancelled') end
 function api.cancelRequest(actor,request)
  if not native.server() then return false end
  local seen=requests[actor];local id=seen and seen.map[request]
  if id and jobs[id] then return api.cancel(actor,id,'clientCancelled') end
  remember(actor,request,'cancelled');return true -- cancellation can arrive before its begin packet
 end
 function api.tick()
  if not native.server() then return end
  for actor,j in pairs(owners) do
   if not native.actorValid(actor) or native.now()-j.time>=1800000 then close(j,'cancelled','expiredOrDisconnected')
   elseif j.poc then j.poc.tick() end
  end
 end
 function api.close() for _,j in pairs(owners) do close(j,'cancelled','closed') end end
 return api
end
return B
