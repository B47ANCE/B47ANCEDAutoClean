-- Production entry point, real installers; engine events/transport are simulated.
local Action=require 'B47ANCEDAutoClean/NativeAction'
local Compatibility=require 'B47ANCEDQuartermaster/Compatibility'
local startup='B47ANCEDAutoClean/Startup'
local rooms='B47ANCEDRooms/API'
local service=require(rooms)
local cases=0
local function events()
 return setmetatable({},{__index=function(t,k)
  local e={handlers={}}
  function e.Add(fn) e.handlers[fn]=true end
  function e.Remove(fn) e.handlers[fn]=nil end
  rawset(t,k,e);return e
 end})
end
local function count(e) local n=0;for _ in pairs(e.handlers) do n=n+1 end;return n end
local function fire(e) for fn in pairs(e.handlers) do fn() end end
local function fresh(server,client)
 SERVER=server;CLIENT=client;Events=events();_G[Action.name]=nil
 B47ANCEDAutoClean=B47ANCEDAutoClean or {};B47ANCEDAutoClean.Startup=nil;package.loaded[startup]=nil
 getActivatedMods=function() return {size=function() return 2 end,get=function(_,i) return i==0 and 'B47ANCEDQuartermaster' or 'B47ANCEDRooms' end} end
 Compatibility.invalidate()
 return require(startup)
end
local function check(name,fn)
 local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));cases=cases+1
end
-- Authority's existing server readers are simulated by the fixture; all cleaning
-- modules, native Lua action classes and Rooms API remain production code.
package.loaded['B47ANCEDQuartermaster/Authority']=true
check('autoload is inert until lifecycle event',function()
 local s=fresh(true,false)
 assert(s.status=='waiting' and not s.instance and not _G[Action.name])
 assert(count(Events.OnClientCommand)==0 and count(Events.OnTick)==0)
 assert(count(Events.OnGameStart)==1 and count(Events.OnServerStarted)==1)
end)
check('single player installs local authority once without network ingress',function()
 local s=fresh(false,false);fire(Events.OnGameStart)
 assert(s.status=='singlePlayer' and s.instance and not _G[Action.name])
 assert(count(Events.OnFillWorldObjectContextMenu)==1 and count(Events.OnTick)==1)
 assert(count(Events.OnServerCommand)==0 and count(Events.OnClientCommand)==0)
 local instance=s.instance;fire(Events.OnGameStart);assert(s.instance==instance)
 s.instance.uninstall();assert(count(Events.OnTick)==0 and count(Events.OnFillWorldObjectContextMenu)==0)
end)
check('ambiguous combined role fails closed',function()
 local s=fresh(true,true);assert(not s.start() and not s.instance)
end)
check('missing cleaning capability registers no ingress or menu',function()
 package.loaded[rooms]={capabilities=function() return {} end}
 for _,server in ipairs({true,false}) do
  local s=fresh(server,not server);assert(not s.start() and s.status=='RoomsCleaningUnavailable')
  assert(not _G[Action.name] and count(Events.OnTick)==0 and count(Events.OnFillWorldObjectContextMenu)==0)
 end
 package.loaded[rooms]=service
end)
check('incompatible active sorting mod blocks activation',function()
 local s=fresh(true,false)
 getActivatedMods=function() return {size=function() return 1 end,get=function() return 'Quartermaster' end} end
 Compatibility.invalidate();assert(not s.start() and s.status=='IncompatibleMod' and not _G[Action.name])
end)
check('unknown active mods block activation',function()
 local s=fresh(true,false);getActivatedMods=nil;Compatibility.invalidate()
 assert(not s.start() and s.status=='CompatibilityUnknown' and not _G[Action.name])
end)
check('server lifecycle installs guarded production transport once',function()
 local f=AUTO_CLEAN_BUILDING_FIXTURE();f.job.cancel(f.actor,f.id)
 local s=fresh(true,false);fire(Events.OnServerStarted)
 assert(s.status=='server' and s.instance and _G[Action.name]==s.instance.class)
 assert(count(Events.OnClientCommand)==2 and count(Events.OnTick)==1 and count(Events.OnFillWorldObjectContextMenu)==0)
 local instance=s.instance;fire(Events.OnServerStarted);fire(Events.OnGameStart)
 assert(s.instance==instance and count(Events.OnClientCommand)==2 and count(Events.OnTick)==1)
 package.loaded[startup]=nil;assert(require(startup)==s and count(Events.OnGameStart)==1)
 assert(not s.instance.class:new(f.actor,'forged','clean','forged'))
 s.instance.uninstall();assert(not _G[Action.name] and count(Events.OnClientCommand)==0 and count(Events.OnTick)==0)
end)
check('client lifecycle installs menu and presentation once',function()
 local s=fresh(false,true);fire(Events.OnGameStart)
 assert(s.status=='client' and s.instance and _G[Action.name])
 assert(count(Events.OnServerCommand)==2 and count(Events.OnTick)==2 and count(Events.OnFillWorldObjectContextMenu)==1)
 local instance=s.instance;fire(Events.OnGameStart);fire(Events.OnServerStarted)
 assert(s.instance==instance and count(Events.OnFillWorldObjectContextMenu)==1)
 s.instance.uninstall();assert(not _G[Action.name] and count(Events.OnServerCommand)==0 and count(Events.OnTick)==0)
 assert(count(Events.OnFillWorldObjectContextMenu)==0)
end)
check('occupied action class cannot be replaced',function()
 local s=fresh(false,true);local existing={};_G[Action.name]=existing
 assert(not s.start() and s.status=='classAlreadyRegistered' and _G[Action.name]==existing)
 assert(count(Events.OnServerCommand)==0 and count(Events.OnTick)==0)
end)
check('missing or incompatible supply provider never registers menu, class or commands',function()
 local key='B47ANCEDQuartermaster/SupplyAPI';local original=package.loaded[key]
 for _,replacement in ipairs({{}, {version=99,ready=true}, {version=1,ready=true,capabilities=function() return nil end},
  {version=1,ready=true,capabilities=function() return {configuredStorage=1,nativeTransfer=1} end}}) do
  package.loaded[key]=replacement
  for _,role in ipairs({{false,false},{true,false},{false,true}}) do
   local s=fresh(role[1],role[2]);assert(not s.start() and s.status=='QuartermasterSupplyUnavailable')
   assert(count(Events.OnFillWorldObjectContextMenu)==0 and count(Events.OnTick)==0 and not _G[Action.name])
  end
 end
 package.loaded[key]=original
end)
check('embedded old cleaning installation cannot coexist with the separate mod',function()
 local s=fresh(false,false);B47ANCEDQuartermaster.AutoClean={instance={}}
 assert(not s.start() and s.status=='EmbeddedCleaningConflict' and count(Events.OnTick)==0)
 B47ANCEDQuartermaster.AutoClean=nil
end)
Events=nil;_G[Action.name]=nil;package.loaded[rooms]=service
print('PASS production lifecycle, idempotence, dependency, role and class-collision guards OFFLINE')
return cases
