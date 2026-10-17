-- Offline scheduler only. Keeps Job/Poc guards on the exact native action;
-- no network ingress, class reconstruction, forced completion or world writes.
local Action=require 'B47ANCEDAutoClean/NativeAction'
local L={}
function L.new(job,port)
 if not port.localAuthority or not port.server() or isClient() or isServer() then return nil,'notSinglePlayer' end
 require 'TimedActions/ISTimedActionQueue'
 local active={};local api={}
 local function current(l)
  return ISTimedActionQueue.getTimedActionQueue(l.actor).queue[1]==l.action
 end
 local function live(l)
  if not l.live or not port.server() or not port.actorValid(l.actor) or not current(l)
   or l.action.character~=l.actor or port.now()-l.time>=120000 then return false end
  local state=job.status(l.actor,l.operation)
  return state and not state.closed and state.phase==l.phase and (state.status=='ready' or state.status=='running')
 end
 local function retire(l)
  l.live=false
  if active[l.actor]==l then active[l.actor]=nil end
 end
 local function cancel(l,reason)
  job.cancel(l.actor,l.operation,reason or 'localCancelled')
  retire(l)
 end
 function api.request(actor,operation,phase)
  if not port.server() or not port.actorValid(actor) or active[actor] or not Action.token(operation) or not Action.phase(phase)
   or #ISTimedActionQueue.getTimedActionQueue(actor).queue~=0 then return false end
  local state=job.status(actor,operation)
  if not state or state.closed or state.status~='ready' or state.phase~=phase then return false end
  local action,resolved=job.next(actor,operation)
  if not action or resolved~=phase then job.cancel(actor,operation,'constructionFailed');return false end
  local l={actor=actor,operation=operation,phase=phase,action=action,time=port.now(),live=true}
  active[actor]=l
  local start,valid,complete,perform,stop,forceCancel=action.start,action.isValid,action.complete,action.perform,action.stop,action.forceCancel
  local update,transfer=action.update,action.transferFluid
  function action:isValid()
   if not live(l) then return false end
   -- Fetch/return are bounded native transfer-helper actions; Base isValid is empty.
   return phase=='fetch' or phase=='return' or valid and valid(self)==true
  end
  function action:start()
   if self~=l.action or l.started or not self:isValid() then cancel(l,'localStartDenied');return end
   l.started=true
   local ok,result=pcall(self.serverStart,self)
   if not ok or result~=true then cancel(l,'guardStartDenied');return end
   if start then
    local started=pcall(start,self)
    if not started then cancel(l,'localStartFailed') end
   end
  end
  function action:complete()
   if self~=l.action or l.completed or not l.started or not live(l) then return false end
   local ok,delta=pcall(self.getJobDelta,self)
   if not ok or type(delta)~='number' or delta~=1 then cancel(l,'nativeClockInvalid');return false end
   l.completed=true -- latch before callback; reentry and repeated native callbacks cannot mutate twice
   local success,result=pcall(complete,self)
   if not success or result~=true then cancel(l,'localCompletionDenied');return false end
   return true
  end
  function action:perform()
   if self~=l.action or l.performed then return end
   l.performed=true
   if not l.completed then cancel(l,'completionNotObserved') end
   -- Native perform handles sounds, item presentation and queue removal only.
   local ok=pcall(perform,self)
   retire(l)
   if not ok then job.cancel(actor,operation,'localPerformFailed') end
  end
  function action:update()
   if self~=l.action or not l.started or l.completed or not live(l) then return false end
   if update then return update(self) end
  end
  if transfer then function action:transferFluid(amount)
   if self~=l.action or not l.started or not live(l) then return false end
   return transfer(self,amount)
  end end
  function action:stop()
   cancel(l,'nativeStopped')
   if not l.stopped then l.stopped=true;if stop then return stop(self) end end
  end
  function action:forceCancel()
   cancel(l,'nativeCancelled')
   if not l.stopped then l.stopped=true;if forceCancel then return forceCancel(self) end end
  end
  local ok=pcall(ISTimedActionQueue.add,action)
  if not ok then cancel(l,'localQueueFailed');return false end
  return true
 end
 function api.busy(actor) return active[actor]~=nil end
 function api.cancel(actor)
  local l=active[actor];if not l then return end
  cancel(l,'localCancelled')
  if current(l) and l.action.action then l.action:forceStop() end
 end
 function api.tick()
  job.tick()
  for actor,l in pairs(active) do if not live(l) then api.cancel(actor) end end
 end
 function api.uninstall()
  for actor in pairs(active) do api.cancel(actor) end
  job.close()
 end
 return api
end
return L
