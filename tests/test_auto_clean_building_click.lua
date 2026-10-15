-- Simulated separate server/client roles and packet queues; no game is running.
local W=require 'research/auto-clean/BuildingWire'
local A=require 'research/auto-clean/NativeAction'
local Server=require 'research/auto-clean/ServerTransport'
local f=AUTO_CLEAN_BUILDING_FIXTURE();f.job.cancel(f.actor,f.id)
local function events()
 return setmetatable({},{__index=function(t,k)
  local e={handlers={}};function e.Add(fn) e.handlers[fn]=true end;function e.Remove(fn) e.handlers[fn]=nil end
  rawset(t,k,e);return e
 end})
end
local se,ce=events(),events()
local server,client,clientClass
local toServer,toClient,requests={},{},{}
local queue={queue={}}
function queue:onCompleted(a) assert(self.queue[1]==a);table.remove(self.queue,1) end
ISTimedActionQueue={getTimedActionQueue=function() return queue end}
ISInventoryPage={};ISLogSystem={logAction=function() end}
getPlayerHotbar=function() return nil end
getPlayerInventory=function() return {refreshBackpacks=function() end} end
function f.actor:setIsFarming() end
function f.actor:reportEvent() end
function f.actor:playSound() return 1 end
function f.actor:getEmitter() return {isPlaying=function() return false end} end
function f.actor:faceLocation() end
function f.actor:shouldBeTurning() return false end
function f.actor:setHaloNote(message) self.summary=message end
function f.actor:setPath2() end
function f.actor:getPathFindBehavior2() return {pathToLocation=function() end,cancel=function() end} end
function f.actor:isSecondaryHandItem(item) return self.secondary==item end
function f.water:getProperties() return nil end
for _,i in ipairs({f.bucket,f.bleach,f.tool}) do
 function i:setJobType() end
 function i:getItemHeat() return 1 end
 function i:getFillFromTapSound() return nil end
 function i:getPourType() return 'Bucket' end
 function i:getStaticModel() return 'Bucket' end
 function i:getUnequipSound() return nil end
end
for _,s in pairs(f.cells) do
 function s:haveBloodWall() return false end
 function s:haveGrimeWall() return false end
 function s:haveBloodFloor() return self.blood end
 function s:haveGrimeFloor() return self.grime end
end
AdjacentFreeTileFinder={Find=function(s) return s end}
sendClientCommand=function(actor,module,command,args) toServer[#toServer+1]={actor=actor,module=module,command=command,args=args} end
sendServerCommand=function(actor,module,command,args) assert(actor==f.actor);toClient[#toClient+1]={module=module,command=command,args=args} end
local function role(serverSide)
 SERVER=serverSide;CLIENT=not serverSide;Events=serverSide and se or ce
 _G[A.name]=serverSide and server and server.class or clientClass
end
local function fire(e,...) for fn in pairs(e.handlers) do fn(...) end end
ISTimedActionQueue.add=function(a)
 assert(#queue.queue==0);queue.queue[1]=a
 a.action=setmetatable({},{__index=function(_,k)
  if k=='forceStop' then return function() a:stop();queue.queue={} end end
  return function() end
 end})
 a:start()
 if a.Type~=ISWalkToTimedAction.Type then requests[#requests+1]={client=a} end
end
role(true);server=assert(W.server())
role(false);_G[A.name]=nil;client=assert(W.client());clientClass=_G[A.name]
getSpecificPlayer=function() return f.actor end
local options={}
local context={addOption=function(_,label,target,fn) options[#options+1]={label=label,click=fn};return {} end}
fire(ce.OnFillWorldObjectContextMenu,0,context,{},false)
assert(#options==1 and options[1].label=='UI_B47Rooms_CleanBuilding')
options[1].click() -- the only user action in this test
options={};fire(ce.OnFillWorldObjectContextMenu,0,context,{},false)
assert(#options==1 and options[1].label=='UI_B47Rooms_CancelCleanBuilding')
local beginCount,completions=0,0
for _=1,300 do
 role(true)
 local outgoing=toServer;toServer={}
 for _,m in ipairs(outgoing) do
  if m.command=='buildingBegin' then beginCount=beginCount+1 end
  -- Simulated native event supplies the actual connection's player, never args.player.
  fire(se.OnClientCommand,m.module,m.command,m.actor,m.args)
 end
 for _,r in ipairs(requests) do
  if not r.server then
   local c=r.client
   r.server=server.class:new(f.actor,c.operation,c.phase,c.grant);assert(r.server)
   r.progress=0;r.server.netAction={getProgress=function() return r.progress end}
   assert(r.server:serverStart())
  end
 end
 role(false)
 outgoing=toClient;toClient={}
 for _,m in ipairs(outgoing) do fire(ce.OnServerCommand,m.module,m.command,m.args) end
 -- Confirmations are delivered before native deadline completion.
 role(true);outgoing=toServer;toServer={}
 for _,m in ipairs(outgoing) do fire(se.OnClientCommand,m.module,m.command,m.actor,m.args) end
 for _,r in ipairs(requests) do
  if r.server and not r.completed then
   r.progress=1;assert(r.server:complete(),r.client.phase);r.completed=true;completions=completions+1
   NOW=NOW+math.max(1000,r.server:getDuration()*20)
  end
 end
 role(false);outgoing=toClient;toClient={}
 for _,m in ipairs(outgoing) do fire(ce.OnServerCommand,m.module,m.command,m.args) end
 local current=queue.queue[1]
 if current then
  if current.Type==ISWalkToTimedAction.Type then
   -- Test double for the native pathfinder arriving; production never teleports.
   f.actor.stand=current.location;current:perform()
  else
   for _,r in ipairs(requests) do if r.client==current and r.completed then current:perform();break end end
  end
 end
 NOW=NOW+300
 fire(ce.OnTick)
 if not client.active[f.actor] then break end
end
assert(not client.active[f.actor] and beginCount==1 and completions>=9)
assert(not f.target.blood and not f.second.blood and f.target.cleans==1 and f.second.cleans==1)
assert(f.origin:getItemWithID(1)==f.bucket and f.origin:getItemWithID(2)==f.bleach and f.origin:getItemWithID(3)==f.tool)
assert(f.actor.summary and f.adds==6 and f.removes==6)
role(false);client.uninstall();role(true);server.uninstall()
Events=nil;_G[A.name]=nil
print('PASS OFFLINE one Clean Building menu click: actual installers, command handlers, native Lua constructors/callbacks, automatic fetch/walk/mix/clean/return; simulated engine/network')
return 1
