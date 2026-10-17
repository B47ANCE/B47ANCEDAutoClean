local Scope=require 'B47ANCEDAutoClean/AreaScope'
local W=require 'B47ANCEDAutoClean/BuildingWire'
local Action=require 'B47ANCEDAutoClean/NativeAction'
local Server=require 'B47ANCEDAutoClean/ServerTransport'
local groups=0
local function check(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));groups=groups+1 end
local function rows(x1,y1,x2,y2,z)
 local out={};for y=y1,y2 do out[#out+1]={z or 0,y,x1,x2} end;return out
end
local function selected(f)
 return rows(f.second:getX()-1,f.second:getY()-1,f.second:getX()+1,f.second:getY()+1)
end
local function setup(carried)
 local f=AUTO_CLEAN_BUILDING_FIXTURE(carried);f.job.cancel(f.actor,f.id)
 function f:startArea(selection,request)
  local result=self.job.begin(self.actor,request or getRandomUUID(),selection or selected(self))
  self.id=result.operation;return result
 end
 return f
end
check('area fetches outside selection, cleans only selected target and returns exact supplies',function()
 local f=setup();assert(f:startArea().operation)
 local r=f:run()
 assert(r.status=='done' and r.actions==1 and r.returned==3,r.status)
 assert(f.second.cleans==1 and f.target.cleans==0)
 assert(f.origin:getItemWithID(1)==f.bucket and f.origin:getItemWithID(2)==f.bleach and f.origin:getItemWithID(3)==f.tool)
end)
check('one selected tile cannot authorize neighboring native cleaning footprint',function()
 local f=setup(true);assert(f:startArea(rows(14,10,14,10)).operation)
 local r=f:run();assert(r.status=='partial' and r.actions==0 and r.skipped==1)
 assert(f.target.cleans==0 and f.second.cleans==0)
end)
check('server copies and normalizes client selection before asynchronous work',function()
 local f=setup();local selection=selected(f);assert(f:startArea(selection).operation)
 selection[1][3]=9;selection[2]=nil
 local r=f:run();assert(r.actions==1 and f.target.cleans==0 and f.second.cleans==1)
end)
check('empty, sparse, metatable, non-integer, non-finite and unbounded geometry fail before supplies',function()
 local f=setup()
 for _,bad in ipairs({{},{{0,10,14,13}},{{0,10,0,200}},{{32,10,14,14}},{{0,10,14.5,15}},
  {{0,10,0/0,15}},{{0,10,14,math.huge}},setmetatable({{0,10,14,14}},{}),{[2]={0,10,14,14}}}) do
  local result=f:startArea(bad);assert(not result.operation and result.status=='CleaningScopeInvalid',result.status)
 end
 assert(f.origin:getItemWithID(1)==f.bucket and f.target.cleans==0)
end)
check('denied selected tile rejects entire scope before fetch',function()
 local f=setup();f.second.denied=true;assert(f:startArea().operation)
 local r=f:run();assert(r.closed and r.actions==0 and f.origin:getItemWithID(1)==f.bucket)
end)
check('unloaded selected tile rejects entire scope before fetch',function()
 local f=setup();f.cells['13:9:0']=nil;assert(f:startArea().operation)
 local r=f:run();assert(r.closed and r.actions==0 and f.origin:getItemWithID(1)==f.bucket)
end)
check('replayed area begin never starts a second cleaning job',function()
 local f=setup();local first=f:startArea(nil,'same-area')
 local replay=f.job.begin(f.actor,'same-area',rows(9,9,11,11));assert(replay.operation==first.operation)
 local r=f:run();assert(r.actions==1)
 replay=f.job.begin(f.actor,'same-area',selected(f));assert(replay.closed and replay.operation==first.operation and f.second.cleans==1)
end)
check('permission changes after admission prevent action completion',function()
 local f=setup(true);assert(f:startArea().operation);local d=f:untilAction()
 if d.status=='walk' then f.actor.stand=f.cell:getGridSquare(d.position.x,d.position.y,d.position.z);d=f:untilAction() end
 f.second.denied=true;local r=f:directive();assert(r.closed and r.actions==0)
end)
check('settings changes cancel area job',function()
 local f=setup();assert(f:startArea().operation);f:untilAction()
 SandboxVars.B47ANCEDRooms.CleaningBleachML=11
 local r=f:directive();assert(r.closed and r.actions==0)
end)
check('area lifetime and exact actor binding stay enforced',function()
 local f=setup();local result=f:startArea();local stranger=setmetatable({},{__index=f.actor})
 assert(f.job.directive(stranger,result.operation).status=='notOwned')
 NOW=NOW+1800001;local r=f:directive();assert(r.closed and r.actions==0)
end)
check('overlapping area reservations are exclusive and released on end',function()
 local f=setup(true);local actor=f.actor;local other={}
 local room={cleaningOptions=function() return {enabled=true,tileLimit=4096} end,
  canAccessAt=function() return {state='allow',revision=1} end}
 local native={server=function() return true end,actorValid=function(a) return a==actor or a==other end,
  now=function() return NOW end,id=getRandomUUID}
 other.getCurrentSquare=function() return nil end
 local original=actor.getCurrentSquare;actor.getCurrentSquare=function() return nil end
 local scopes=Scope.new(room,native);local a=scopes.beginCleaningArea(actor,selected(f));local b=scopes.beginCleaningArea(other,selected(f))
 assert(scopes.readCleaningBuilding(actor,a.scope).status=='ok')
 assert(scopes.readCleaningBuilding(other,b.scope).status=='busy')
 scopes.endCleaningBuilding(other,b.scope);scopes.endCleaningBuilding(actor,a.scope)
 b=scopes.beginCleaningArea(other,selected(f));assert(scopes.readCleaningBuilding(other,b.scope).status=='ok')
 scopes.endCleaningBuilding(other,b.scope);actor.getCurrentSquare=original
end)
check('outside a native building a selected area can use carried supplies',function()
 local f=setup(true)
 for _,sq in pairs(f.cells) do sq.getBuilding=function() return nil end end
 -- Retain finite water inside the area for this outside-building case.
 local selection=rows(9,9,15,11)
 assert(f:startArea(selection).operation);local r=f:run()
 assert(r.status=='done' and r.actions==2 and r.returned==0)
end)
check('SP area workflow reuses local guarded queue and does not clean unselected target',function()
 local f=AUTO_CLEAN_SP_FIXTURE();assert(f.ui.start(f.actor,selected(f)))
 f:run();assert(f.second.cleans==1 and f.target.cleans==0 and not f.ui.active[f.actor])
 f.ui.uninstall()
end)
check('SP malformed and foreign actor starts fail without queued actions',function()
 local f=AUTO_CLEAN_SP_FIXTURE(true)
 assert(not f.ui.start(f.actor,{}))
 local stranger=setmetatable({},{__index=f.actor});assert(not f.ui.start(stranger,selected(f)))
 assert(#f:queue().queue==0);f.ui.uninstall()
end)
check('selector opening and cancel send no request; only confirmation submits copied area rows',function()
 local f=AUTO_CLEAN_SP_FIXTURE(true);f.ui.uninstall();SERVER=false;CLIENT=true;_G[Action.name]=nil
 local sent={};sendClientCommand=function(actor,module,command,args) sent[#sent+1]={actor=actor,command=command,args=args} end
 local confirm,cancel,closed
 local previous=package.loaded['B47ANCEDAutoClean/AreaSelector']
 package.loaded['B47ANCEDAutoClean/AreaSelector']={open=function(num,a,b) confirm=a;cancel=b;return {closeEditor=function() closed=true;cancel() end} end}
 local ui=assert(W.client());assert(ui.selectArea(f.actor) and #sent==0 and not ui.active[f.actor])
 assert(not ui.selectArea(f.actor));local late=confirm;ui.cancel(f.actor);late(selected(f));assert(#sent==0 and closed)
 assert(ui.selectArea(f.actor));confirm(selected(f));assert(#sent==1 and sent[1].command=='areaBegin' and sent[1].actor==f.actor)
 assert(sent[1].args.rows and sent[1].args.player==nil and sent[1].args.scope==nil)
 ui.uninstall();package.loaded['B47ANCEDAutoClean/AreaSelector']=previous
end)
check('server area ingress rejects supplied actors, grant fields, extra operation and malformed rows',function()
 local f=setup(true);f.job.cancel(f.actor,f.id);_G[Action.name]=nil
 local output={};sendServerCommand=function(actor,module,command,args) output[#output+1]=args end
 local installed=assert(W.server())
 local function fire(actor,args) for fn in pairs(Events.OnClientCommand.handlers) do fn(Server.module,'areaBegin',actor,args) end end
 for _,field in ipairs({'player','actor','scope','grant','operation'}) do
  local args={protocol=1,request=getRandomUUID(),rows=selected(f)};args[field]='forged';fire(f.actor,args)
 end
 assert(#output==0)
 fire(f.actor,{protocol=1,request=getRandomUUID(),rows={}});assert(#output==1 and not output[1].operation)
 NOW=NOW+1001
 fire(f.actor,{protocol=1,request=getRandomUUID(),rows=selected(f)})
 assert(output[#output].operation and output[#output].status=='waiting')
 installed.uninstall()
end)
print('PASS '..groups..' Clean Area authority, supply, transport and SP scenarios OFFLINE')
return groups
