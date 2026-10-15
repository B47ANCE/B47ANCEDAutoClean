local Building=require 'research/auto-clean/BuildingJob'
local Native=require 'research/auto-clean/BuildingNative'
local Server=require 'research/auto-clean/ServerTransport'
local cases=0
local function test(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));cases=cases+1 end
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
local API
local function fixture(carried)
 local f=AUTO_CLEAN_FIXTURE();local data={}
 ModData={get=function(k) return data[k] end,getOrCreate=function(k) data[k]=data[k] or {};return data[k] end}
 SandboxVars={B47ANCEDRooms={Enabled=true}}
 SafeHouse.getSafehouseList=function() return list({}) end
 SafeHouse.isSafehouseAllowLoot=function(sq) return not sq.denied end
 SafeHouse.isSafehouseAllowInteract=function(sq) return not sq.denied end
 getTimestamp=function() return math.floor(NOW/1000) end
 triggerEvent=function() end
 getText=function(k) return k end
 function f.actor:getUsername() return 'building-tester' end
 function f.actor:getPlayerNum() return 0 end
 function f.actor:getAccessLevel() return 'None' end
 function f.actor:getSecondaryHandItem() return self.secondary end
 function f.actor:setPrimaryHandItem(item) self.tool=item end
 function f.actor:setSecondaryHandItem(item) self.secondary=item end
 function f.actor:getClothingItem_Back() return nil end
 function f.actor:removeWornItem() end
 function f.actor:removeAttachedItem() end
 function f.actor:removeFromHands(item) if self.tool==item then self.tool=nil end;return false end
 function f.actor:isEquipped(item) return self.tool==item end
 function f.actor:getWornItems() return {contains=function() return false end} end
 sendEquip=function() f.equipSync=(f.equipSync or 0)+1 end
 local function container(items)
  local c={items=items or {}}
  function c:getItems() local a={};for _,v in pairs(self.items) do a[#a+1]=v end;table.sort(a,function(x,y) return x:getID()<y:getID() end);return list(a) end
  function c:getItemWithID(id) return self.items[id] end
  function c:getItemWithIDRecursiv(id) return self.items[id] end
  function c:DoRemoveItem(item) self.items[item:getID()]=nil;item.container=nil end
  function c:AddItem(item) self.items[item:getID()]=item;item.container=self;return item end
  function c:getType() return 'crate' end
  function c:getContainingItem() return nil end
  function c:getParent() return self.parent end
  function c:isRemoveItemAllowed() return not self.denied end
  function c:isItemAllowed() return not self.denied end
  function c:hasRoomFor() return not self.full end
  function c:setDrawDirty() end
  return c
 end
 local root=container(f.actor.inv.items)
 for k,v in pairs(root) do if f.actor.inv[k]==nil then f.actor.inv[k]=v end end
 -- Preserve original recursive predicate methods used by the installed cleaning action.
 local def={getIDString=function() return 'native-building-test-room' end,getName=function() return 'Test room' end,
  getX=function() return 9 end,getY=function() return 9 end,getX2=function() return 16 end,getY2=function() return 12 end,getZ=function() return 0 end}
 local buildingDef={getRooms=function() return list({def}) end}
 local building={getDef=function() return buildingDef end}
 for x=9,15 do for y=9,11 do
  local k=x..':'..y..':0';local sq=f.cells[k]
  if not sq then sq={x=x,y=y,z=0,chunk=f.target.chunk};f.cells[k]=sq end
  for name,value in pairs(f.target) do if type(value)=='function' and sq[name]==nil then sq[name]=value end end
  sq.blood=sq==f.target;sq.grime=sq==f.target;sq.cleans=0;sq.objects={}
  function sq:getRoomDef() return def end
  function sq:getBuilding() return building end
  function sq:getObjects() return list(self.objects) end
 end end
 f.second=f.cells['14:10:0'];f.second.blood=true;f.second.grime=true
 f.water.sq.objects={f.water}
 function f.water:getContainerCount() return 0 end
 function f.water:getContainerByIndex() return nil end
 local origin=container();local crate={sq=f.cells['9:10:0'],container=origin}
 function crate:getSquare() return self.sq end
 function crate:getObjectIndex() return self.removed and -1 or 0 end
 function crate:getContainerCount() return 1 end
 function crate:getContainerByIndex(i) return i==0 and self.container or nil end
 function crate:getFluidContainer() return nil end
 origin.parent=crate;crate.sq.objects={crate};f.origin=origin;f.crate=crate
 for _,item in ipairs({f.bucket,f.bleach,f.tool}) do
  function item:getContainer() return self.container end
  function item:getAttachedSlot() return -1 end
  function item:getActualWeight() return 0.1 end
  function item:getType() return self.fullType:match('%.(.+)$') end
  function item:IsClothing() return false end
  function item:IsInventoryContainer() return false end
  function item:isForceDropHeavyItem() return false end
  function item:isRequiresEquippedBothHands() return false end
  function item:isTwoHandWeapon() return false end
  function item:canBeActivated() return false end
  function item:getCurrentUsesFloat() return 1 end
  function item:getEquipSound() return nil end
  function item:getName() return self:getType() end
  function item:getClothingItem() return nil end
  if carried then item.container=f.actor.inv
  else f.actor.inv.items[item.id]=nil;origin:AddItem(item) end
 end
 if not carried then f.actor.tool=nil end
 sendRemoveItemFromContainer=function(c,item) f.removes=(f.removes or 0)+1 end
 sendAddItemToContainer=function(c,item) f.adds=(f.adds or 0)+1 end
 B47ANCEDQuartermaster={Targets={valid=function(r) return r.obj==crate and r.container==crate.container and not crate.removed end},
  Store={load=function() if not crate.unconfigured then return {cats={clean=true},items={}} end end},Presets={resolve=function(config) return config end}}
 API=API or require 'B47ANCEDRooms/API';f.api=API;f.data=data
 f.native=Native.new(API);f.job=Building.new(API,f.native)
 f.messages={}
 f.transport=Server.new(f.job,f.native,{describe=function(a,phase) return f.native.describe(a,phase) or {native=true} end,
  send=function(actor,command,args) f.messages[#f.messages+1]={actor=actor,command=command,args=args} end})
 local begin=f.job.begin(f.actor,'one-click');assert(begin.operation,begin.status);f.id=begin.operation
 function f:directive() return self.job.directive(self.actor,self.id) end
 function f:performPhase(phase)
  NOW=NOW+1000 -- simulated native action time, not a zero-time packet burst
  local request={protocol=1,operation=self.id,phase=phase,request=getRandomUUID()}
  assert(self.transport.command(Server.module,'next',self.actor,request))
  local offer=self.messages[#self.messages].args
  local a=self.transport.class:new(self.actor,self.id,phase,offer.grant);assert(a)
  a.netAction={getProgress=function() return a.progress or 0 end};assert(a:serverStart())
  local challenge=self.messages[#self.messages].args.challenge
  assert(self.transport.command(Server.module,'confirm',self.actor,{protocol=1,operation=self.id,phase=phase,grant=offer.grant,challenge=challenge}))
  a.progress=1;local result=a:complete();self.lastAction=a;return result
 end
 function f:run(limit)
  for _=1,limit or 2000 do
   local d=self:directive()
   if d.closed then return d end
   if d.status=='walk' then
    self.walks=(self.walks or 0)+1
    self.actor.stand=self.cell:getGridSquare(d.position.x,d.position.y,d.position.z)
   elseif d.status=='action' then assert(self:performPhase(d.phase),d.phase) end
   NOW=NOW+10
  end
  error('job did not finish')
 end
 function f:untilAction()
  for _=1,1000 do local d=self:directive();if d.status=='action' or d.closed or d.status=='walk' then return d end end
  error('no instruction')
 end
 return f
end
test('one building request fetches exact supplies, mixes once, cleans two distant targets and returns them',function()
 local f=fixture();local r=f:run()
 assert(r.status=='done' and r.actions==2 and r.skipped==0 and r.returned==3 and r.retained==0)
 assert(f.walks>=1 and f.target.cleans==1 and f.second.cleans==1)
 assert(f.origin:getItemWithID(1)==f.bucket and f.origin:getItemWithID(2)==f.bleach and f.origin:getItemWithID(3)==f.tool)
 assert(math.abs(f.bleach.fc:getAmount()-0.99)<0.00002 and f.bucket.fc:getAmount()<10)
 assert(f.adds==6 and f.removes==6 and f.actor:getPrimaryHandItem()==nil)
 assert(not f.lastAction:complete());AUTO_CLEAN_BUILDING_RESULT=r
end)
test('mixing can happen at water before walking to a distant dirty target',function()
 local f=fixture();f.target.blood=false;f.target.grime=false
 local r=f:run();assert(r.status=='done' and r.actions==1 and f.second.cleans==1)
end)
test('carried supplies are reused and never returned to unrelated storage',function()
 local f=fixture(true);local r=f:run()
 assert(r.status=='done' and r.returned==0 and r.actions==2 and f.actor:getPrimaryHandItem()==f.tool)
 assert(not f.adds and not f.removes)
end)
test('missing supplies and insufficient carry space cause no inventory mutation',function()
 local f=fixture();f.origin.items[3]=nil;local r=f:run();assert(r.status=='cancelled' and not f.adds)
 f=fixture();f.actor.capacity=0;r=f:run();assert(r.status=='cancelled' and not f.adds)
end)
test('unconfigured and denied storage are never borrowed',function()
 local f=fixture();f.crate.unconfigured=true;assert(f:run().status=='cancelled' and not f.adds)
 f=fixture();f.origin.denied=true;assert(f:run().status=='cancelled' and not f.adds)
end)
test('unsafe native footprint yields an honest partial result',function()
 local f=fixture();local base=f.api.canCleanBuildingTile
 f.api.canCleanBuildingTile=function(actor,scope,x,y,z) if x==15 then return {state='deny'} end;return base(actor,scope,x,y,z) end
 local r=f:run();f.api.canCleanBuildingTile=base
 assert(r.status=='partial' and r.actions==1 and r.skipped==1 and f.second.blood and r.returned==3)
end)
test('replaced supply container after grant prevents native transfer',function()
 local f=fixture();local d=f:untilAction()
 if d.status=='walk' then f.actor.stand=f.crate.sq;d=f:untilAction() end
 assert(d.phase=='fetch')
 local a=f.job.next(f.actor,f.id);assert(a);assert(a:serverStart())
 f.crate.container={};assert(not a:complete());assert(not f.adds and f.origin:getItemWithID(1)==f.bucket)
 f.job.cancel(f.actor,f.id)
end)
test('scope revision invalidation stops pending work without borrowing',function()
 local f=fixture();f:untilAction()
 local lib=f.api and B47ANCEDRooms.Registry.library()
 -- A persisted current-format room root with a new revision invalidates this lease.
 f.data.B47ANCEDRooms.customRooms={schema=2,revision=1,serial=0,world='00000000-0000-0000-0000-000000000000',records={}}
 assert(f:directive().closed and not f.adds)
end)
test('return failure retains supplies and never substitutes a destination',function()
 local f=fixture();local base=f.native.sourceValid
 f.native.sourceValid=function(actor,r,action) if action=='deposit' then return false end;return base(actor,r,action) end
 local r=f:run();assert(r.status=='done' and r.returned==0 and r.retained==3 and f.actor.inv:getItemWithID(1)==f.bucket)
end)
test('server arrival is required and authenticated foreign actor cannot advance a job',function()
 local f=fixture();local d=f:untilAction()
 if d.status=='action' then f.actor.stand=f.second;d=f:directive() end
 assert(d.status=='walk');assert(not f.job.next({},f.id));assert(f.job.status({},f.id)==nil)
 -- Direct next without observed arrival is rejected at the action's guard.
 local a=f.job.next(f.actor,f.id)
 if a then assert(not a:serverStart() and not a:complete()) end
 assert(not f.adds);f.job.cancel(f.actor,f.id)
end)
test('begin replay and cancellation cannot create a second job or refund partial work',function()
 local f=fixture();assert(f.job.begin(f.actor,'one-click').operation==f.id)
 local d=f:untilAction();if d.status=='walk' then f.actor.stand=f.crate.sq;d=f:untilAction() end
 assert(f:performPhase('fetch'));assert(f.actor.inv:getItemWithID(1)==f.bucket)
 f.job.cancel(f.actor,f.id);assert(f.job.status(f.actor,f.id).retained==1)
 local replay=f.job.begin(f.actor,'one-click');assert(replay.operation==f.id and replay.status=='cancelled')
 assert(f.actor.inv:getItemWithID(1)==f.bucket and f.origin:getItemWithID(2)==f.bleach)
end)
test('no dirty targets returns done without acquiring supplies',function()
 local f=fixture();f.target.blood=false;f.second.blood=false;f.origin.items={}
 local r=f:run();assert(r.status=='done' and r.actions==0 and not f.adds)
end)
test('cancellation before begin is a tombstone and cannot start a late job',function()
 local f=fixture();f.job.cancel(f.actor,f.id)
 assert(f.job.cancelRequest(f.actor,'cancel-before-start'))
 local late=f.job.begin(f.actor,'cancel-before-start');assert(late.closed and late.status=='cancelled' and not late.operation)
 assert(not f.adds)
end)
test('native fetch failure after transfer records the retained item without retry',function()
 local f=fixture();local d=f:untilAction();if d.status=='walk' then f.actor.stand=f.crate.sq;d=f:untilAction() end
 local a=f.job.next(f.actor,f.id);assert(a and a:serverStart())
 local transfer=ISTransferAction.transferItem
 ISTransferAction.transferItem=function(...) local item=transfer(...);error('after native transfer') end
 assert(not a:complete());ISTransferAction.transferItem=transfer
 local r=f.job.status(f.actor,f.id)
 assert(r.status=='uncertain' and r.retained==1 and r.unaccounted==0 and f.actor.inv:getItemWithID(1)==f.bucket)
 assert(not a:complete() and f.origin:getItemWithID(2)==f.bleach)
end)
test('native cleaning permission is rechecked at completion',function()
 local f=fixture();local a
 for _=1,1000 do
  local d=f:directive()
  if d.status=='walk' then f.actor.stand=f.cell:getGridSquare(d.position.x,d.position.y,d.position.z)
  elseif d.status=='action' then
   if d.phase=='clean' then a=f.job.next(f.actor,f.id);assert(a and a:serverStart());break end
   assert(f:performPhase(d.phase))
  end
 end
 assert(a);local total=f.bucket.fc:getAmount()
 SafeHouse.isSafehouseAllowInteract=function() return false end
 assert(not a:complete() and f.target.blood and f.bucket.fc:getAmount()==total)
end)
test('top-up reaches the configured dose before native filling and conserves residual solution',function()
 local f=fixture();local changed=false
 for _=1,2000 do
  local d=f:directive()
  if d.closed then assert(d.actions==2 and d.status=='done',tostring(d.reason)..' actions='..tostring(d.actions));break end
  if d.status=='walk' then f.actor.stand=f.cell:getGridSquare(d.position.x,d.position.y,d.position.z)
  elseif d.status=='action' then
   assert(f:performPhase(d.phase))
   if d.phase=='clean' and not changed then
    -- Simulated external use between guarded operations, with a measured residual.
    f.bucket.fc.bleach=F32(0.0002);f.bucket.fc.water=F32(0.1);f.water.fc.water=F32(20);changed=true
   end
  end
 end
 assert(changed and math.abs(f.bleach.fc:getAmount()-0.9802)<0.00002 and not f.second.blood)
end)
test('client constructor waits for delayed native inventory replication',function()
 local Client=require 'research/auto-clean/ClientTransport'
 local f=fixture(true);f.job.cancel(f.actor,f.id)
 local ready=false;local queued=0;local sent={}
 local c=Client.new({idle=function() return true end,id=getRandomUUID,now=getTimestampMs,
  send=function(actor,command,args) sent[#sent+1]={command=command,args=args} end,
  resolve=function(actor) if ready then return ISBaseTimedAction:new(actor) end end,
  queue=function() queued=queued+1 end})
 assert(c.request(f.actor,'replication-op','fetch'));local request=sent[1].args.request
 assert(c.message('offer',{protocol=1,operation='replication-op',phase='fetch',request=request,grant='replication-grant',view={}}))
 assert(queued==0 and c.busy(f.actor));ready=true;c.tick();assert(queued==1)
 c.cancel(f.actor);assert(not c.busy(f.actor) and sent[#sent].command=='cancel')
end)
test('native two-handed cleaning equipment is fetched, equipped, cleaned and returned',function()
 local f=fixture();function f.tool:isRequiresEquippedBothHands() return true end
 local r=f:run();assert(r.status=='done' and r.actions==2 and r.returned==3)
 assert(f.actor:getPrimaryHandItem()==nil and f.actor:getSecondaryHandItem()==nil)
end)
test('reentrant cancellation waits for the actual transfer outcome and records it once',function()
 local f=fixture();local d=f:untilAction();if d.status=='walk' then f.actor.stand=f.crate.sq;d=f:untilAction() end
 local a=f.job.next(f.actor,f.id);assert(a and a:serverStart())
 local transfer=ISTransferAction.transferItem
 ISTransferAction.transferItem=function(...) local item=transfer(...);f.job.cancel(f.actor,f.id,'cancelDuringTransfer');return item end
 assert(a:complete());ISTransferAction.transferItem=transfer
 local r=f.job.status(f.actor,f.id);assert(r.status=='cancelled' and r.retained==1 and r.unaccounted==0)
 assert(not a:complete() and f.actor.inv:getItemWithID(1)==f.bucket and f.removes==1)
end)
AUTO_CLEAN_BUILDING_FIXTURE=fixture
print('PASS OFFLINE Clean Building: '..cases..' integration scenarios; actual Rooms API/native Lua, simulated engine/transport/walking')
return cases
