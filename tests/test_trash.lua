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
 function o.sprite:getProperties() return {has=function(_,key) return key=='CustomName' and self.customName~=nil end,get=function() return self.customName end} end
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
 function f.actor:getMoodles() return {getMoodleLevel=function() return 0 end} end
 function f.actor:getBodyDamage() return {getBodyPart=function() return {getPain=function() return 0 end} end} end
 function f.actor:getTimedActionTimeModifier() return 1 end
 function f.actor:getSpriteDef() return {getFrame=function() return 0 end} end
 function f.actor:setMetabolicTarget() end
 ISInventoryPage={};CharacterActionAnims={DigShovel='DigShovel'};Metabolics.LightWork=5
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
    if d.phase~='trash' then assert(self:performPhase(d.phase))
    else
    assert(self.transport.command(Server.module,'next',self.actor,{protocol=1,operation=self.id,phase='trash',request=getRandomUUID()}))
    local offer=self.messages[#self.messages].args
    local a=self.transport.class:new(self.actor,self.id,'trash',offer.grant);assert(a)
    a.netAction={getProgress=function() return a.progress or 0 end};assert(a:serverStart())
    local challenge=self.messages[#self.messages].args.challenge
    return a,offer,challenge
    end
   elseif d.closed then error('closed '..tostring(d.reason)) end
  end
  error('no trash action')
 end
 function f:confirm(a,offer,challenge)
  assert(self.transport.command(Server.module,'confirm',self.actor,{protocol=1,operation=self.id,phase='trash',grant=offer.grant,challenge=challenge}))
 end
 return f
end
local function broom(f,carried,kind)
 local b={};for k,v in pairs(f.tool) do b[k]=v end
 b.id=4;b.fullType=kind or 'Base.Broom';b.kind='HandWeapon';b.fc=nil;b.broken=false;b.favorite=false
 function b:getSwingAnim() return 'Bat' end
 function b:isTwoHandWeapon() return true end
 function b:getDigType() return nil end
 function b:getStaticModel() return 'Broom' end
 function b:getCondition() return self.broken and 0 or 3 end
 b.container=carried and f.actor.inv or f.origin;b.container.items[b.id]=b
 return b
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
test('trash enable defaults and obsolete custom duration values are ignored',function()
 local f=fixture();assert(Options.read().trashEnabled and Options.read().trashSeconds==nil)
 for _,value in ipairs({0,11,1.5,'3',math.huge,0/0}) do
  SandboxVars.B47ANCEDAutoClean={TrashPickupSeconds=value};assert(Options.read().trashSeconds==nil)
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
test('elapsed vanilla timing is closure retained and immune to action fields',function()
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
  elseif change=='settings' then SandboxVars.B47ANCEDAutoClean={RemoveTrashObjects=false}
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
  position={x=10,y=10,z=0},index=f.trash:getObjectIndex(),sprite='trash_01_0'}})
 assert(queued and queued.trashObject==f.trash and queued.maxTime==100)
 assert(not queued:complete() and f.trash.sq==f.target and not f.trashCalls)
 ui.uninstall();ISTimedActionQueue.add=original
end)
test('carried broom uses vanilla clearing duration and restores original hands',function()
 local f=fixture();local b=broom(f,true);f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
 assert(f.actor:getPrimaryHandItem()==b and a.trashBroom==b and a:getDuration()==ISClearAshes.getDuration(a))
 assert(a.adjustMaxTime==ISBaseTimedAction.adjustMaxTime)
 NOW=NOW+a:adjustMaxTime(a:getDuration())*20;a.progress=1;assert(a:complete())
 local r=f:run();assert(r.status=='done' and r.trashRemoved==1 and r.returned==0 and f.actor:getPrimaryHandItem()==nil and b.container==f.actor.inv)
end)
test('configured broom is fetched equipped swept and returned without stain supplies',function()
 local f=fixture();local b=broom(f,false);f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
 assert(a.trashBroom==b and a:getDuration()==60 and b.container==f.actor.inv)
 NOW=NOW+1200;a.progress=1;assert(a:complete());local r=f:run()
 assert(r.status=='done' and r.returned==1 and r.retained==0 and b.container==f.origin and f.actor:getPrimaryHandItem()==nil)
end)
test('unconfigured denied favorite broken and unborrowable brooms fall back to vanilla pickup',function()
 for _,case in ipairs({'unconfigured','denied','favorite','broken','borrowDisabled','capacity'}) do
  local f=fixture();local b=broom(f,false)
  if case=='unconfigured' then f.crate.unconfigured=true
  elseif case=='denied' then f.origin.denied=true
  elseif case=='favorite' then b.favorite=true
  elseif case=='broken' then b.broken=true
  elseif case=='borrowDisabled' then SandboxVars.B47ANCEDRooms.CleaningBorrowSupplies=false
  else f.actor.capacity=0 end
  f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
  assert(a.trashBroom==nil and a:getDuration()==ISPickUpGroundCoverItem.getDuration(a),case)
  NOW=NOW+a:adjustMaxTime(a:getDuration())*20;a.progress=1;assert(a:complete())
  local r=f:run();assert(r.trashRemoved==1 and r.returned==0 and b.container==f.origin,case)
 end
end)
test('one broom can serve trash and stains without duplicate borrowing or return',function()
 local f=fixture(true);f.tool.fullType='Base.Broom';function f.tool:getDigType() return nil end
 f:begin();local r=f:run();assert(r.status=='done' and r.actions==2 and r.trashRemoved==1 and r.returned==3 and f.adds==6 and f.removes==6)
end)
test('separate broom and stain tool are both returned with original hands restored',function()
 local f=fixture(true);local b=broom(f,false);f:begin();local r=f:run()
 assert(r.status=='done' and r.actions==2 and r.trashRemoved==1 and r.returned==4 and b.container==f.origin and f.actor:getPrimaryHandItem()==nil)
end)
test('broom is returned after a mixed job with missing stain supplies',function()
 local f=fixture(true);f.origin.items={};local b=broom(f,false);f:begin();local r=f:run()
 assert(r.status=='partial' and r.reason=='missingSupplies' and r.trashRemoved==1 and r.skipped==2 and r.returned==1 and b.container==f.origin)
end)
test('broom loss breakage favorite change and unexpected hand change block pending removal',function()
 for _,change in ipairs({'lost','broken','favorite','hands'}) do
  local f=fixture();local b=broom(f,true);f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
  if change=='lost' then f.actor.inv.items[b.id]=nil
  elseif change=='broken' then b.broken=true
  elseif change=='favorite' then b.favorite=true
  else f.actor.tool=f.tool end
  NOW=NOW+1200;a.progress=1;assert(not a:complete() and not f.trashCalls,change)
 end
end)
test('native pickup moodle modifiers change authority duration without a custom timer',function()
 for _,elapsed in ipairs({3000,4000}) do
  local f=fixture();function f.actor:getMoodles() return {getMoodleLevel=function(_,kind) return kind==MoodleType.UNHAPPY and 4 or 0 end} end
  f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
  assert(a:getDuration()==100 and a:adjustMaxTime(a:getDuration())==200)
  NOW=NOW+elapsed;a.progress=1;assert(a:complete()==(elapsed==4000));assert((f.trashCalls or 0)==(elapsed==4000 and 1 or 0))
 end
 local f=fixture();function f.actor:getBodyDamage() return {getBodyPart=function() return {getPain=function() return 7 end} end} end
 f:begin();local a,o,c=f:grant();f:confirm(a,o,c)
 local nativeMillis=math.floor(a:adjustMaxTime(a:getDuration())*20)
 NOW=NOW+nativeMillis;a.progress=1;assert(a:complete(),'native whole-millisecond completion')
end)
test('vanilla instant pickup remains native and still needs confirmed completed action',function()
 local f=fixture();function f.actor:isTimedActionInstant() return true end
 f:begin();local a,o,c=f:grant();f:confirm(a,o,c);assert(a:getDuration()==1)
 NOW=NOW+20;a.progress=1;assert(a:complete() and f.trashCalls==1)
end)
test('native weight inventory and dexterity pickup timing is retained without granting items',function()
 local f=fixture();f.trash.sprite.customName='PaperTrash'
 ScriptManager={instance={getItem=function(_,name) return name=='PaperTrash' and {} or nil end}}
 getItemActualWeight=function() return 0.5 end
 function f.actor.inv:getCapacityWeight() return 10 end;function f.actor.inv:getMaxWeight() return 20 end
 getCore=function() return {getGameMode=function() return 'Survival' end} end
 CharacterTrait={DEXTROUS='dex',ALL_THUMBS='thumbs'}
 function f.actor:hasTrait(trait) return trait=='dex' end;function f.actor:isWearingAwkwardGloves() return false end
 f:begin();local a,o,c=f:grant();f:confirm(a,o,c);assert(a:getDuration()==15)
 NOW=NOW+300;a.progress=1;assert(a:complete() and f.trashCalls==1 and not f.adds)
end)
test('single-player broom uses installed sweep start/update and restores original hand',function()
 local f=fixture(false,true);local b=broom(f,true);f:begin();local id=f.id;local a=f:untilPhase('trash')
 assert(a.trashBroom==b and a:getDuration()==60)
 f:run();local r=f.ui.jobs.status(f.actor,id)
 assert(r.status=='done' and r.trashRemoved==1 and f.actor:getPrimaryHandItem()==nil and b.container==f.actor.inv)
 f.ui.uninstall()
end)
test('twig broom follows vanilla clearing presentation and preserves an occupied original hand',function()
 local f=fixture(false,true);local b=broom(f,true,'Base.Broom_Twig')
 f.origin.items[f.tool.id]=nil;f.actor.inv:AddItem(f.tool);f.actor.tool=f.tool
 f:begin();local id=f.id;local a=f:untilPhase('trash');assert(a.trashBroom==b and a:getDuration()==60)
 f:run();assert(f.ui.jobs.status(f.actor,id).status=='done' and f.actor:getPrimaryHandItem()==f.tool and b.container==f.actor.inv)
 f.ui.uninstall()
end)
test('single-player native completion respects game-speed acceleration without a wall timer',function()
 local f=fixture(false,true);f:begin();local id=f.id;local a=f:untilPhase('trash')
 -- Simulated native game-time advance at accelerated speed, with little wall time.
 a.action.delta=1;assert(a:complete() and f.trashCalls==1);a:perform()
 f:run();assert(f.ui.jobs.status(f.actor,id).status=='done');f.ui.uninstall()
end)
test('client broom presentation waits for exact equipped-item replication',function()
 local f=fixture(false,true);local b=broom(f,true);f.ui.uninstall();SERVER=false;CLIENT=true
 local Action=require 'B47ANCEDAutoClean/NativeAction';_G[Action.name]=nil
 local sent={};sendClientCommand=function(actor,module,command,args) sent[#sent+1]={command=command,args=args} end
 local original=ISTimedActionQueue.add;local queued
 ISTimedActionQueue.add=function(a) queued=a end
 local ui=assert(require('B47ANCEDAutoClean/BuildingWire').client())
 local function message(command,args) for fn in pairs(Events.OnServerCommand.handlers) do fn(Server.module,command,args) end end
 assert(ui.start(f.actor));local request=sent[#sent].args.request
 message('buildingState',{protocol=1,request=request,operation='broom-client',status='action',phase='trash'})
 request=sent[#sent].args.request
 message('offer',{protocol=1,request=request,operation='broom-client',phase='trash',grant='broom-grant',view={
  position={x=10,y=10,z=0},index=f.trash:getObjectIndex(),sprite='trash_01_0',broom=b.id}})
 assert(not queued);f.actor.tool=b
 for fn in pairs(Events.OnTick.handlers) do fn() end
 assert(queued and queued.trashBroom==b and queued:getDuration()==60 and not queued:complete() and not f.trashCalls)
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
