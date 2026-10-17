-- Transient Auto Clean scopes. Rooms owns permission decisions and building discovery.
local G=require 'B47ANCEDRooms/Geometry'
local S={}
function S.normalize(rows,limit) return G.normalize(rows,limit) end
function S.new(rooms,native)
 local jobs,buildings,claims={},{},{}
 local api=setmetatable({},{__index=rooms})
 local function release(actor,j)
  jobs[actor]=nil
  for key in pairs(j.reserved) do if claims[key]==j then claims[key]=nil end end
  if j.logistics then rooms.endCleaningBuilding(actor,j.logistics) end
 end
 local function settingsEqual(a,b)
  for k,v in pairs(a) do if b[k]~=v then return false end end
  for k,v in pairs(b) do if a[k]~=v then return false end end
  return true
 end
 local function current(actor,key)
  local j=jobs[actor]
  if not native.server() or not native.actorValid(actor) or not j or j.key~=key then return nil,'CleaningUnavailable' end
  if native.now()-j.time>=1800000 then release(actor,j);return nil,'CleaningExpired' end
  if not settingsEqual(j.options,rooms.cleaningOptions()) then return nil,'CleaningSettingsChanged' end
  if j.revision then
   local p=j.geometry.tiles[1];local access=rooms.canAccessAt(actor,p.x,p.y,p.z,'clean')
   if access.state~='allow' or access.revision~=j.revision then return nil,'CleaningScopeChanged' end
  end
  return j
 end
 local function reserve(j,tiles)
  for _,p in ipairs(tiles) do
   local k=G.key(p.x,p.y,p.z)
   if claims[k] and claims[k]~=j then return false end
  end
  for _,p in ipairs(tiles) do local k=G.key(p.x,p.y,p.z);claims[k]=j;j.reserved[k]=true end
  return true
 end
 function api.beginCleaningArea(actor,rows)
  if not native.server() or not native.actorValid(actor) then return {status='CleaningUnavailable'} end
  local options=rooms.cleaningOptions()
  if not options.enabled then return {status='CleaningUnavailable'} end
  local geometry=G.normalize(rows,options.tileLimit)
  if not geometry or geometry.count==0 then return {status='CleaningScopeInvalid'} end
  if jobs[actor] or buildings[actor] then return {status='busy'} end
  local j={key=native.id(),geometry=geometry,options=options,index=1,time=native.now(),reserved={},squares={},members={}}
  local square=actor:getCurrentSquare()
  -- Keep the existing building supply search when starting inside a building.
  -- Its snapshot may extend logistics, never the selected cleaning membership.
  if square and square:getBuilding() then
   local result=rooms.beginCleaningBuilding(actor)
   if result.status~='waiting' then return result end
   j.logistics=result.scope
  end
  jobs[actor]=j
  return {status='waiting',scope=j.key}
 end
 function api.beginCleaningBuilding(actor)
  if jobs[actor] then return {status='busy'} end
  local result=rooms.beginCleaningBuilding(actor)
  if result.status=='waiting' then buildings[actor]={key=result.scope,reserved={}} end
  return result
 end
 function api.readCleaningBuilding(actor,key)
  local j=jobs[actor]
  if not j or j.key~=key then
   local result=rooms.readCleaningBuilding(actor,key)
   local b=buildings[actor]
   if result.status=='ok' and b and b.key==key and not b.done then
    if not reserve(b,result.tiles) then api.endCleaningBuilding(actor,key);return {status='busy'} end
    b.done=true
   end
   return result
  end
  local why;j,why=current(actor,key)
  if not j then return {status=why} end
  if j.failed then return {status=j.failed} end
  local function fail(reason) j.failed=reason;return {status=reason} end
  if not j.done then
   for _=1,64 do
    local p=j.geometry.tiles[j.index]
    if not p then break end
    local square=getCell():getGridSquare(p.x,p.y,p.z)
    if not square or not square:getChunk() then return fail('CleaningUnloaded') end
    local access=rooms.canAccessAt(actor,p.x,p.y,p.z,'clean')
    if access.state~='allow' or type(access.revision)~='number' then return fail('RoomAccessDenied') end
    if j.revision and access.revision~=j.revision then return fail('CleaningScopeChanged') end
    j.revision=access.revision
    if not reserve(j,{p}) then return fail('busy') end
    local k=G.key(p.x,p.y,p.z);j.squares[k]=square;j.members[k]=true;j.index=j.index+1
   end
   if j.index<=j.geometry.count then return {status='waiting'} end
   j.scanTiles={};j.logisticsMembers={}
   for _,p in ipairs(j.geometry.tiles) do j.scanTiles[#j.scanTiles+1]=p;j.logisticsMembers[G.key(p.x,p.y,p.z)]=true end
   if j.logistics then
    local result=rooms.readCleaningBuilding(actor,j.logistics)
    if result.status=='waiting' then return {status='waiting'} end
    if result.status~='ok' then return fail(result.status) end
    for _,p in ipairs(result.tiles) do
     local k=G.key(p.x,p.y,p.z)
     if not j.logisticsMembers[k] then
      if #j.scanTiles>=j.options.tileLimit*2 then return fail('CleaningBuildingTooLarge') end
      j.scanTiles[#j.scanTiles+1]={x=p.x,y=p.y,z=p.z};j.logisticsMembers[k]=true
     end
    end
   end
   j.done=true
  end
  -- Survey is trusted implementation code, but return a fresh value like Rooms.
  local tiles={};for _,p in ipairs(j.scanTiles) do tiles[#tiles+1]={x=p.x,y=p.y,z=p.z} end
  local options={};for k,v in pairs(j.options) do options[k]=v end
  return {status='ok',scope=j.key,tiles=tiles,options=options}
 end
 function api.validateCleaningBuilding(actor,key)
  if not jobs[actor] or jobs[actor].key~=key then return rooms.validateCleaningBuilding(actor,key) end
  local j,why=current(actor,key)
  return {status=not j and why or j.failed or (j.done and 'ok' or 'waiting')}
 end
 function api.cleaningTargetTile(actor,key,x,y,z)
  local j=jobs[actor]
  if not j or j.key~=key then return rooms.containsCleaningBuildingTile(actor,key,x,y,z) end
  return j.members[G.key(x,y,z)]==true
 end
 function api.canCleanBuildingTile(actor,key,x,y,z)
  if not jobs[actor] or jobs[actor].key~=key then return rooms.canCleanBuildingTile(actor,key,x,y,z) end
  local j,why=current(actor,key)
  if not j or not j.done or j.failed or not G.integer(x) or not G.integer(y) or not G.integer(z) then return {state='unknown',reason=why or 'CleaningOutsideScope'} end
  local k=G.key(x,y,z);local square=getCell():getGridSquare(x,y,z)
  if not j.members[k] then return {state='deny',reason='CleaningOutsideScope'} end
  if not square or square~=j.squares[k] or not square:getChunk() then return {state='unknown',reason='CleaningUnloaded'} end
  return rooms.canAccessAt(actor,x,y,z,'clean')
 end
 function api.containsCleaningBuildingTile(actor,key,x,y,z)
  if not jobs[actor] or jobs[actor].key~=key then return rooms.containsCleaningBuildingTile(actor,key,x,y,z) end
  local j=current(actor,key)
  return j and j.done and not j.failed and G.integer(x) and G.integer(y) and G.integer(z)
   and j.logisticsMembers[G.key(x,y,z)]==true or false
 end
 function api.endCleaningBuilding(actor,key)
  local j=jobs[actor]
  if j and j.key==key then release(actor,j);return true end
  local b=buildings[actor]
  if b and b.key==key then
   for k in pairs(b.reserved) do if claims[k]==b then claims[k]=nil end end
   buildings[actor]=nil
  end
  return rooms.endCleaningBuilding(actor,key)
 end
 return api
end
return S
