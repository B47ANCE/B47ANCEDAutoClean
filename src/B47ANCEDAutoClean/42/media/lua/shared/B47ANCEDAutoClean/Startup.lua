-- Auto-loaded shared entry point. Factories register no ingress before this hook.
require 'B47ANCEDAutoClean/Identity'
B47ANCEDAutoClean=B47ANCEDAutoClean or {}
local Q=B47ANCEDAutoClean
if Q.Startup then return Q.Startup end -- autoload/require and repeated events
local S={status='waiting'}
Q.Startup=S
function S.start()
 if S.instance then return true end
 local role=isClient() and not isServer() and 'client' or isServer() and not isClient() and 'server'
  or not isClient() and not isServer() and 'singlePlayer'
 if not role then S.status='ambiguousRole';return false end
 local loaded,supplies=pcall(require,'B47ANCEDQuartermaster/SupplyAPI')
 if not loaded or type(supplies)~='table' or supplies.version~=1 or supplies.ready~=true
  or type(supplies.capabilities)~='function' then
  S.status='QuartermasterSupplyUnavailable';return false
 end
 local described,caps=pcall(supplies.capabilities)
 if not described or type(caps)~='table' or caps.configuredStorage~=1 or caps.nativeTransfer~=1 then
  S.status='QuartermasterSupplyUnavailable';return false
 end
 for _,method in ipairs({'prepare','actorAvailable','configuredStorage','storageItems','storageAllowed','transferAction'}) do
  if type(supplies[method])~='function' then S.status='QuartermasterSupplyUnavailable';return false end
 end
 local old=B47ANCEDQuartermaster and B47ANCEDQuartermaster.AutoClean
 if old and old.instance then S.status='EmbeddedCleaningConflict';return false end
 local prepared,allowed,reason=pcall(supplies.prepare)
 if not prepared then S.status='QuartermasterSupplyUnavailable';return false end
 if not allowed then S.status=reason;return false end
 local ok,instance,why=pcall(function() return require('B47ANCEDAutoClean/BuildingWire')[role]() end)
 if not ok then
  S.status='installationFailed'
  print('[B47ANCEDAutoClean] Clean Building installation failed: '..tostring(instance))
  return false
 end
 S.instance=instance;S.status=instance and role or why
 print('[B47ANCEDAutoClean] Clean Building: '..tostring(S.status))
 return instance~=nil
end
-- Verified vanilla hooks: shared Util/CustomTileProps.lua uses both events.
Events.OnGameStart.Add(S.start)
Events.OnServerStarted.Add(S.start)
return S
