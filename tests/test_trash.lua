-- Actual production jobs/transport/native Lua queue, simulated world/clock only.
local Trash=require 'B47ANCEDAutoClean/Trash'
local Options=require 'B47ANCEDAutoClean/Options'
local Server=require 'B47ANCEDAutoClean/ServerTransport'
local cases=0
local function test(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));cases=cases+1 end
local function object(f,square,name)
 local o={kind='IsoObject',sq=square,data={},sprite={name=name or 'trash_01_0'}}
 function o.sprite:getName() return self.name end
 function o.sprite:getSpriteGrid() return self.grid end
 function o:getObjectName() return self.objectName or 'IsoObject' end
 function o:getSquare() return self.sq end
 function o:getSprite() return self.sprite end
 function o:getModData() return self.data end
 function o:getContainerCount() return self.containers or 0 end
 function o:getFluidContainer() return nil end
 function o:getObjectIndex() for i,v in ipairs(square.objects) do if v==self then return i-1 end end;return -1 end
 square.objects[#square.objects+1]=o
 function square:transmitRemoveItemFromSquare(item,multi)
  assert(multi==false,'must disable multi-tile expansion')
  for i,v in ipairs(self.objects) do if v==item then
   table.remove(self.objects,i);v.sq=nil;f.trashCalls=(f.trashCalls or 0)+1
   if f.removalCallback then f.removalCallback() end
   return i-1
  end end
  return -1
 end
 return o
end
local function fixture(mixed,sp)
 local f=sp and AUTO_CLEAN_SP_FIXTURE() or AUTO_CLEAN_BUILDING_FIXTURE()
 if not sp then f.job.cancel(f.actor,f.id) end
 if not mixed then f.target.blood=false;f.second.blood=false;f.origin.items={} end
 function f.actor:faceThisObject() end
 function f.actor:SetVariable() end
 f.trash=object(f,f.target)
 function f:begin(rows)
  if sp then assert(self.ui.start(self.actor,rows));self.id=self.ui.active[self.actor].operation
  else local r=self.job.begin(self.actor,getRandomUUID(),rows);assert(r.operation,r.status);self.id=r.operation end
 end
 function f:grant()
  for _=1,1000 do
   local d=self:directive()
   if d.status=='walk' then self.actor.stand=self.cell:getGridSquare(d.position.x,d.position.y,d.position.z)
   elseif d.status=='action' then
    assert(d.phase=='trash')
    assert(self.transport.command(Server.module,'next',self.actor,{protocol=1,operation=self.id,phase='trash',request=getRandomUUID()}))
    local offer=self.messages[#self.messages].args
    local a=self.transport.class:new(self.actor,self.id,'trash',offer.grant);assert(a)
    a.netAction={getProgress=function() return a.progress or 0 end};assert(a:serverStart())
    local challenge=self.messages[#self.messages].args.challenge
    return a,offer,challenge
   elseif d.closed then error('closed '..tostring(d.reason)) end
  end
  error('no trash action')
 end
 function f:confirm(a,offer,challenge)
  assert(self.transport.command(Server.module,'confirm',self.actor,{protocol=1,operation=self.id,phase='trash',grant=offer.grant,challenge=challenge}))
 end
 return f
end
test('77 exact vanilla trash sprites; excluded gaps and unknown prefixes',function()
 local f=fixture();local names={}
 for i=0,25 do names[#names+1]='d_trash_'..i end
 for i=0,12 do names[#names+1]='trash_01_'..i end
 for i=16,53 do names[#names+1]='trash_01_'..i end
 assert(#names==77)
 for _,name in ipairs(names) do f.trash.sprite.name=name;assert(Trash.capture(f.trash,f.target),name) end
 for _,name in ipairs({'trash_01_13','trash_01_14','trash_01_15','trash_01_54','d_trash_26','trash_custom_0','floors_0'}) do
  f.trash.sprite.name=name;assert(not Trash.capture(f.trash,f.target),name)
 end
end)
test('world inventory items containers named props grids and custom mod data excluded',function()
 for _,kind in ipairs({'world','container','named','grid','modData','missing','otherClass'}) do
  local f=fixture();local o=f.trash
  if kind=='world' then o.kind='IsoWorldInventoryObject'
  elseif kind=='container' then o.containers=1
  elseif kind=='named' then o.objectName='Door'
  elseif kind=='grid' then o.sprite.grid={}
  elseif kind=='modData' then o.data.owner='someone'
  elseif kind=='missing' then o.sq=nil
  else o.kind='IsoThumpable' end
  assert(not Trash.capture(o,f.target),kind)
 end
end)
test('trash-only building needs no supplies water or inventory mutations',function()
 local f=fixture();f.water.sq.objects={};local dropped=object(f,f.target);dropped.kind='IsoWorldInventoryObject'
 f:begin();local r=f:run()
 assert(r.status=='done' and r.trashRemoved==1 and r.actions==0 and r.returned==0)
 assert(f.trashCalls==1 and dropped.sq==f.target and not f.adds and not f.removes)
end)
test('multiple objects on one square are removed singly as indexes shift',function()
 local f=fixture();object(f,f.target,'d_trash_25');object(f,f.target,'trash_01_53')
 f:begin();local r=f:run();assert(r.trashRemoved==3 and f.trashCalls==3 and r.status=='done')
end)
test('mixed job cleans trash then stains and returns exact supplies',function()
 local f=fixture(true);f:begin();local r=f:run()
 assert(r.status=='done' and r.trashRemoved==1 and r.actions==2 and r.returned==3 and f.trashCalls==1)
end)
test('mixed missing stain supplies still removes trash and reports partial',function()
 local f=fixture(true);f.origin.items={};f:begin();local r=f:run()
 assert(r.status=='partial' and r.reason=='missingSupplies' and r.trashRemoved==1 and r.skipped==2)
 assert(f.target.blood and f.second.blood and not f.adds and not f.removes)
end)
test('sandbox disable preserves stain cleaning and leaves trash in place',function()
 local f=fixture(true);SandboxVars.B47ANCEDAutoClean={RemoveTrashObjects=false}
 f:begin();local r=f:run();assert(r.actions==2 and r.trashRemoved==0 and f.trash.sq==f.target and not f.trashCalls)
end)
test('settings defaults bounds malformed values and maximum duration',function()
 local f=fixture();assert(Options.read().trashEnabled and Options.read().trashSeconds==2)
 for _,value in ipairs({0,11,1.5,'3',math.huge,0/0}) do
  SandboxVars.B47ANCEDAutoClean={TrashPickupSeconds=value};assert(Options.read().trashSeconds==2)
 end
 SandboxVars.B47ANCEDAutoClean={RemoveTrashObjects='true'};assert(not Options.read().trashEnabled)
 SandboxVars.B47ANCEDAutoClean={TrashPickupSeconds=10};f:begin();local r=f:run();assert(r.trashRemoved==1)
end)
test('selected tiles exclude building logistics and adjacent floor objects',function()
 local f=fixture();local outside=object(f,f.second)
 f:begin({{0,10,10,10}});local r=f:run()
 assert(r.trashRemoved==1 and outside.sq==f.second and f.trashCalls==1)
end)
test('permission denied tile is skipped without removal',function()
 local f=fixture();f.target.denied=true;f:begin();local r=f:run()
 assert(r.trashRemoved==0 and not f.trashCalls)
end)
test('early completion and progress below one never remove objects',function()
 for _,early in ipairs({true,false}) do
  local f=fixture();f:begin();local a,offer,challenge=f:grant();f:confirm(a,offer,challenge)
  if early then a.progress=1 else NOW=NOW+2000;a.progress=0.9 end
  assert(not a:complete() and f.trash.sq==f.target and not f.trashCalls)
 end
end)
test('elapsed configured timing is closure retained and immune to action fields',function()
 local f=fixture();f:begin();local a,offer,challenge=f:grant();f:confirm(a,offer,challenge)
 a.maxTime=0;NOW=NOW+1999;a.progress=1;assert(not a:complete() and not f.trashCalls)
end)
test('confirmation and foreign constructor binding survive trash reconstruction',function()
 local f=fixture();f:begin();local a,offer,challenge=f:grant()
 assert(not f.transport.class:new({},f.id,'trash',offer.grant))
 assert(not f.transport.class:new(f.actor,f.id,'trash',offer.grant),'one reconstruction')
 NOW=NOW+2000;a.progress=1;assert(not a:complete() and not f.trashCalls,'unconfirmed native action')
end)
test('confirmed action retains guard and completes once',function()
 local f=fixture();f:begin();local a,offer,challenge=f:grant();f:confirm(a,offer,challenge)
 NOW=NOW+2000;a.progress=1;assert(a:complete());assert(not a:complete())
 local r=f:run();assert(r.trashRemoved==1 and f.trashCalls==1)
end)
test('object replacement movement sprite change and mod data change fail closed',function()
 for _,change in ipairs({'replace','move','sprite','data'}) do
  local f=fixture();f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
  if change=='replace' then f.target.objects={};object(f,f.target)
  elseif change=='move' then f.trash.sq=f.second
  elseif change=='sprite' then f.trash.sprite.name='trash_01_1'
  else f.trash.data.protected=true end
  NOW=NOW+2000;a.progress=1;assert(not a:complete() and not f.trashCalls,change)
 end
end)
test('permissions settings cancel disconnect and expiry are rechecked on completion',function()
 for _,change in ipairs({'permission','settings','cancel','disconnect','expiry','foreignActor'}) do
  local f=fixture();f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
  if change=='permission' then f.target.denied=true
  elseif change=='settings' then SandboxVars.B47ANCEDAutoClean={TrashPickupSeconds=3}
  elseif change=='cancel' then f.job.cancel(f.actor,f.id)
  elseif change=='disconnect' then f.actor.dead=true
  elseif change=='expiry' then NOW=NOW+120001
  else a.character={} end
  NOW=NOW+2000;a.progress=1;assert(not a:complete() and not f.trashCalls,change)
 end
end)
test('reentrant completion and cancellation do not duplicate or refund removal',function()
 local f=fixture();f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
 f.removalCallback=function() assert(not a:complete());f.job.cancel(f.actor,f.id,'cancelDuringRemoval') end
 NOW=NOW+2000;a.progress=1;assert(a:complete());assert(not a:complete())
 local r=f.job.status(f.actor,f.id);assert(r.status=='cancelled' and r.trashRemoved==1 and f.trashCalls==1)
end)
test('native error after removal is uncertain and never retried',function()
 local f=fixture();f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
 f.removalCallback=function() error('native callback failed after removal') end
 NOW=NOW+2000;a.progress=1;assert(not a:complete() and not a:complete())
 assert(f.trashCalls==1 and f.job.status(f.actor,f.id).status=='uncertain')
end)
test('actual client wire resolves object presentation with no item ID or removal callback',function()
 local f=fixture(false,true);f.ui.uninstall();SERVER=false;CLIENT=true
 local Action=require 'B47ANCEDAutoClean/NativeAction';_G[Action.name]=nil
 local sent={};sendClientCommand=function(actor,module,command,args) sent[#sent+1]={command=command,args=args} end
 local original=ISTimedActionQueue.add;local queued
 ISTimedActionQueue.add=function(a) queued=a end -- simulate native MP enqueue only
 local ui=assert(require('B47ANCEDAutoClean/BuildingWire').client())
 local function message(command,args) for fn in pairs(Events.OnServerCommand.handlers) do fn(Server.module,command,args) end end
 assert(ui.start(f.actor));local request=sent[#sent].args.request
 message('buildingState',{protocol=1,request=request,operation='trash-client',status='action',phase='trash'})
 assert(sent[#sent].command=='next');request=sent[#sent].args.request
 message('offer',{protocol=1,request=request,operation='trash-client',phase='trash',grant='trash-grant',view={
  position={x=10,y=10,z=0},index=f.trash:getObjectIndex(),sprite='trash_01_0',ticks=100}})
 assert(queued and queued.trashObject==f.trash and queued.maxTime==100)
 assert(not queued:complete() and f.trash.sq==f.target and not f.trashCalls)
 ui.uninstall();ISTimedActionQueue.add=original
end)
test('single-player native queue cleans objects without networking',function()
 local f=fixture(false,true);f:begin();local id=f.id;f:run()
 local r=f.ui.jobs.status(f.actor,id);assert(r.status=='done' and r.trashRemoved==1 and f.trashCalls==1 and f.actor.summary)
 f.ui.uninstall()
end)
test('single-player exact local actor binding survives trash queue reconstruction',function()
 local f=fixture(false,true);f:begin();local a=f:untilPhase('trash')
 getSpecificPlayer=function() return {} end
 NOW=NOW+2000;a.action.delta=1;assert(not a:complete() and not f.trashCalls)
 f.ui.uninstall()
end)
print('PASS '..cases..' ground trash object scenarios OFFLINE; real jobs/transport/native Lua queue, simulated engine/world/clock')
return cases
