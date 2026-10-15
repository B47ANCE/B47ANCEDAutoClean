-- Actual installed Lua action classes/base/queue; native engine/pathfinder are doubles.
local W=require 'B47ANCEDAutoClean/BuildingWire'
local Native=require 'B47ANCEDAutoClean/BuildingNative'
local Port=require 'B47ANCEDAutoClean/NativePort'
local Job=require 'B47ANCEDAutoClean/BuildingJob'
local Local=require 'B47ANCEDAutoClean/LocalQueue'
local cases=0
local function check(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));cases=cases+1 end
local function events()
 return setmetatable({},{__index=function(t,k)
  local e={handlers={}};function e.Add(fn) e.handlers[fn]=true end;function e.Remove(fn) e.handlers[fn]=nil end
  rawset(t,k,e);return e
 end})
end
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
Events=events()
for _,name in ipairs({'ClimbThroughWindowState','ClimbOverFenceState','ClimbOverWallState','ClimbSheetRopeState','ClimbDownSheetRopeState','CloseWindowState','OpenWindowState'}) do
 _G[name]={instance=function() return name end}
end
dofile(GAME_ROOT..'/media/lua/shared/TimedActions/ISBaseTimedAction.lua')
dofile(GAME_ROOT..'/media/lua/client/TimedActions/ISTimedActionQueue.lua')
for _,name in ipairs({'shared/Fluids/ISFluidTransferAction','shared/TimedActions/ISTakeWaterAction','shared/TimedActions/ISCleanBlood',
 'shared/TimedActions/ISEquipWeaponAction','shared/TimedActions/ISUnequipAction','client/TimedActions/WalkToTimedAction'}) do
 dofile(GAME_ROOT..'/media/lua/'..name..'.lua')
end
MoodleType={UNHAPPY=1,DRUNK=2};BodyPartType={Hand_L=0,ForeArm_R=0,ToIndex=function() return 0 end,FromIndex=function() return 0 end}
getGameSpeed=function() return 1 end
getCore=function() return {getOptionTimedActionGameSpeedReset=function() return false end} end
LuaTimedActionNew={new=function(lua,actor)
 local a={lua=lua,delta=0}
 setmetatable(a,{__index=function(_,k)
  if k=='getJobDelta' then return function() return a.delta end end
  if k=='forceStop' then return function() lua:stop() end end
  if k=='isStarted' then return function() return a.started end end
  return function() end
 end})
 return a
end}
local originalAdd=ISTimedActionQueue.add
local function setup(carried)
 local f=AUTO_CLEAN_BUILDING_FIXTURE(carried);f.job.cancel(f.actor,f.id)
 SERVER=false;CLIENT=false;Events=events();ISTimedActionQueue.queues={}
 getSpecificPlayer=function(n) return n==0 and f.actor or nil end
 sendClientCommand=function() error('SP sent client command') end
 sendServerCommand=function() error('SP sent server command') end
 getOnlinePlayers=function() error('SP consulted connected network players') end
 sendAddItemToContainer=function() error('SP used multiplayer destination sync') end
 function f.actor:setIsFarming() end
 function f.actor:setTimedActionToRetrigger() end
 function f.actor:getTimedActionToRetrigger() return nil end
 function f.actor:getMoodles() return {getMoodleLevel=function() return 0 end} end
 function f.actor:getBodyDamage() return {getBodyPart=function() return {getPain=function() return 0 end} end} end
 function f.actor:getTimedActionTimeModifier() return 1 end
 function f.actor:StartAction(a) a.started=true;a.lua:start() end
 function f.actor:reportEvent() end
 function f.actor:playSound() return 1 end
 function f.actor:getEmitter() return {isPlaying=function() return false end} end
 function f.actor:faceLocation() end
 function f.actor:shouldBeTurning() return false end
 function f.actor:setHaloNote(message) self.summary=message end
 function f.actor:setPath2() end
 function f.actor:getPathFindBehavior2() return {pathToLocation=function() end,cancel=function() end} end
 function f.actor:isSecondaryHandItem(item) return self.secondary==item end
 function f.actor:getVehicle() return nil end
 function f.actor:hasFullInventory() return false end
 for _,i in ipairs({f.bucket,f.bleach,f.tool}) do
  function i:setJobType() end
  function i:getItemHeat() return 1 end
  function i:getFillFromTapSound() return nil end
  function i:getPourType() return 'Bucket' end
  function i:getStaticModel() return 'Bucket' end
  function i:getUnequipSound() return nil end
 end
 function f.water:getProperties() return nil end
 for _,sq in pairs(f.cells) do
  function sq:haveBloodWall() return false end;function sq:haveGrimeWall() return false end
  function sq:haveBloodFloor() return self.blood end;function sq:haveGrimeFloor() return self.grime end
 end
 ISTimedActionQueue.add=function(a) local ok,result=pcall(originalAdd,a);if not ok then f.queueError=result;error(result) end;return result end
 f.ui=assert(W.singlePlayer())
 function f:queue() return ISTimedActionQueue.getTimedActionQueue(self.actor) end
 function f:tick()
  NOW=NOW+300
  for fn in pairs(Events.OnTick.handlers) do fn() end
 end
 function f:advance(a)
  if a.Type==ISWalkToTimedAction.Type then self.actor.stand=a.location;a:perform();return end
  assert(a:isValid(),a.Type)
  a.action.delta=0.5;a:update() -- incremental native mutation stays inside Poc/Job
  a.action.delta=1
  assert(a:complete(),a.Type)
  assert(not a:complete(),'duplicate completion')
  a:perform();a:perform() -- queue removal is idempotent too
 end
 function f:run()
  for _=1,500 do
   local a=self:queue().queue[1];if a then self:advance(a) end
   self:tick()
   if not self.ui.active[self.actor] then return end
  end
  error('local job stalled')
 end
 function f:untilPhase(phase)
  for _=1,500 do
   local a=self:queue().queue[1]
   if a and a.Type~=ISWalkToTimedAction.Type and self.ui.jobs.status(self.actor,self.ui.active[self.actor].operation).phase==phase then return a end
   if a then self:advance(a) end
   self:tick()
  end
  error('no phase '..phase)
 end
 return f
end
check('one menu click fetches walks equips mixes cleans and returns using actual native queue',function()
 local f=setup();local options={}
 local context={addOption=function(_,label,_,fn) options[#options+1]={label=label,click=fn} end}
 for fn in pairs(Events.OnFillWorldObjectContextMenu.handlers) do fn(0,context,{},false) end
 assert(#options==1 and options[1].label=='UI_B47Rooms_CleanBuilding');options[1].click()
 assert(not f.ui.start(f.actor),'duplicate begin')
 local op=f.ui.active[f.actor].operation;f:run()
 local r=f.ui.jobs.status(f.actor,op)
 assert(r.status=='done' and r.actions==2 and r.returned==3 and r.retained==0, tostring(r.status)..':'..tostring(r.reason)..':'..r.actions..':'..r.returned..':'..tostring(f.queueError))
 assert(f.target.cleans==1 and f.second.cleans==1 and f.actor.summary)
 assert(f.origin:getItemWithID(1)==f.bucket and f.origin:getItemWithID(2)==f.bleach and f.origin:getItemWithID(3)==f.tool)
 assert(math.abs(f.bleach.fc:getAmount()-0.99)<0.00002 and not f.adds and not f.removes)
 f.ui.uninstall()
end)
check('bleach is transferred before water and full guards observe incremental native updates',function()
 local f=setup(true);assert(f.ui.start(f.actor))
 local a=f:untilPhase('bleach');a.action.delta=0.5;a:update()
 assert(f.bucket.fc.bleach>0 and f.bucket.fc.bleach<0.01 and f.bucket.fc.water==0)
 a.action.delta=1;assert(a:complete());a:perform()
 a=f:untilPhase('water');assert(math.abs(f.bucket.fc.bleach-0.01)<0.00002 and f.bucket.fc.water==0)
 f:advance(a);assert(math.abs(f.bucket.fc:getAmount()-10)<0.00002)
 f:run();assert(f.target.cleans==1 and f.second.cleans==1);f.ui.uninstall()
end)
for _,kind in ipairs({'cancel','stop','death','identity','role','scope','clock','resource','source','tool','footprint','timeout'}) do
 check('pending local cleaning fails closed on '..kind,function()
  local f=setup(true);assert(f.ui.start(f.actor));local a=f:untilPhase('clean');local before=f.bucket.fc:getAmount()
  if kind=='cancel' then f.ui.cancel(f.actor)
  elseif kind=='stop' then a:stop()
  elseif kind=='death' then f.actor.dead=true
  elseif kind=='identity' then getSpecificPlayer=function() return {} end
  elseif kind=='role' then CLIENT=true
  elseif kind=='scope' then SandboxVars.B47ANCEDRooms.CleanBuildingEnabled=false
  elseif kind=='clock' then a.action.delta=0.5
  elseif kind=='resource' then f.bucket.fc.water=1
  elseif kind=='source' then f.water.removed=true
  elseif kind=='tool' then f.tool.favorite=true
  elseif kind=='footprint' then f.cells['9:9:0']=nil
  elseif kind=='timeout' then NOW=NOW+120001 end
  if kind~='clock' then a.action.delta=1 end
  assert(not a:complete());assert(f.target.cleans==0 and f.second.cleans==0)
  if kind~='resource' then assert(f.bucket.fc:getAmount()==before) end
  CLIENT=false;getSpecificPlayer=function() return f.actor end
  f.ui.uninstall()
 end)
end
check('denied storage and unsafe footprint retain the existing outcomes',function()
 local f=setup();f.origin.denied=true;assert(f.ui.start(f.actor));local op=f.ui.active[f.actor].operation;f:run()
 assert(f.ui.jobs.status(f.actor,op).status=='cancelled' and f.origin:getItemWithID(1)==f.bucket);f.ui.uninstall()
 f=setup(true);f.cells['9:9:0']=nil;assert(f.ui.start(f.actor));f:run();assert(f.target.cleans==0);f.ui.uninstall()
end)
check('prepared solution is reused without dosing or filling again',function()
 local f=setup(true);f.bucket.fc.bleach=F32(0.01);f.bucket.fc.water=F32(9.99)
 assert(f.ui.start(f.actor));f:run()
 assert(f.target.cleans==1 and f.second.cleans==1 and f.bleach.fc:getAmount()==1 and f.water.fc:getAmount()==12)
 f.ui.uninstall()
end)
check('return permission changes retain borrowed items and do not substitute storage',function()
 local f=setup();assert(f.ui.start(f.actor));f:untilPhase('clean');f.origin.denied=true
 local op=f.ui.active[f.actor].operation;f:run();local r=f.ui.jobs.status(f.actor,op)
 assert(r.status=='done' and r.returned==0 and r.retained==3 and f.actor.inv:getItemWithID(1)==f.bucket)
 f.ui.uninstall()
end)
check('a replaced queue entry is neither completed nor removed by cancellation',function()
 local f=setup(true);assert(f.ui.start(f.actor));local a=f:untilPhase('clean')
 local unrelated={};f:queue().queue[1]=unrelated;f:tick()
 a.action.delta=1;assert(not a:complete() and f.target.cleans==0 and f:queue().queue[1]==unrelated)
 f.ui.uninstall();assert(f:queue().queue[1]==unrelated)
end)
check('local installation and local actors cannot be used by multiplayer clients or combined roles',function()
 local f=setup(true);local p=Port.new({singlePlayer=true});assert(p.actorValid(f.actor))
 assert(not p.actorValid({isDead=function() return false end,getPlayerNum=function() return 0 end}))
 CLIENT=true;assert(not W.singlePlayer() and not p.server() and not p.actorValid(f.actor))
 SERVER=true;assert(not W.singlePlayer() and not p.server());SERVER=true;CLIENT=false;assert(not W.singlePlayer() and not p.server())
 SERVER=false;f.ui.uninstall()
end)
Events=nil
print('PASS '..cases..' SP scenarios OFFLINE: actual native Lua base/queue/actions and Rooms, simulated engine/pathfinding')
return cases
