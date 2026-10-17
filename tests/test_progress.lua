-- Actual vanilla ISProgressBar and production HUD/wire; engine drawing is simulated.
local groups=0
local function test(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));groups=groups+1 end
local Element=ISBaseObject:derive('HudEngineElement')
function Element:new(x,y,w,h) return setmetatable({x=x,y=y,width=w,height=h,draws={}},self) end
function Element:initialise() end
function Element:setWantMouseEvents(value) self.mouseEvents=value end
function Element:setWantKeyEvents(value) self.keyEvents=value end
function Element:setCapture(value) self.capture=value end
function Element:setFollowGameWorld(value) self.follow=value end
function Element:setRenderThisPlayerOnly(value) self.playerOnly=value end
function Element:addToUIManager() self.added=true end
function Element:removeFromUIManager() self.removed=true;self.removals=(self.removals or 0)+1 end
function Element:setX(value) self.x=value end
function Element:setY(value) self.y=value end
function Element:setWidth(value) self.width=value end
function Element:setHeight(value) self.height=value end
function Element:setStencilRect(...) self.stencil={...} end
function Element:clearStencilRect() self.stencil=nil;self.clipped=true end
function Element:drawRectStatic(...) self.draws[#self.draws+1]={...} end
function Element:drawRectBorderStatic() end
function Element:drawText(...) self.lastText={...} end
ISUIElement=Element;package.loaded['ISUI/ISUIElement']=true
package.preload['B47ANCEDAutoClean/Progress']=nil;package.loaded['B47ANCEDAutoClean/Progress']=nil
UIFont={Small='small'};PZMath={clamp_01=function(n) return math.max(0,math.min(1,n)) end}
getTexture=function() return {} end
local fontHeight=14
getTextManager=function() return {MeasureStringX=function(_,font,s) return #s*fontHeight/2 end,
 getFontFromEnum=function() return {getLineHeight=function() return fontHeight end} end} end
dofile(GAME_ROOT..'/media/lua/client/ISUI/ISProgressBar.lua');package.loaded['ISUI/ISProgressBar']=true
local Progress=require 'B47ANCEDAutoClean/Progress'
local screens={[0]={left=0,top=0,width=1280,height=720},[1]={left=1280,top=0,width=640,height=720}}
getPlayerScreenLeft=function(n) return screens[n].left end;getPlayerScreenTop=function(n) return screens[n].top end
getPlayerScreenWidth=function(n) return screens[n].width end;getPlayerScreenHeight=function(n) return screens[n].height end
isoToScreenX=function(n,x,y,z) return screens[n].left+400+(x-10)*16 end
isoToScreenY=function(n,x,y,z) return screens[n].top+360+(x+y-20)*8-z*32 end
UIManager={getProgressBar=function() error('native current-action bar must remain untouched') end}
local function text(key,...)
 local value=PROGRESS_TRANSLATIONS[key] or key
 for i,arg in ipairs({...}) do value=value:gsub('%%'..i,function() return tostring(arg) end) end
 return value
end
local zoom=1
local function fixture()
 local f=AUTO_CLEAN_SP_FIXTURE();getText=text;fontHeight=14;zoom=1
 getCore=function() return {getZoom=function() return zoom end,getOptionTimedActionGameSpeedReset=function() return false end} end
 function f.actor:getX() return self.stand:getX() end
 function f.actor:getY() return self.stand:getY() end
 function f.actor:getZ() return self.stand:getZ() end
 return f
end
local function state(total,completed,skipped,stage,phase)
 return {known=true,total=total,completed=completed,skipped=skipped or 0,stage=stage or 'clean',phase=phase or 'waiting'}
end
test('confirmed start shows a separate native-styled bar without input capture',function()
 local f=fixture();assert(f.ui.start(f.actor));local b=f.ui.progress.bars[f.actor]
 assert(b and b.added and b.progress==0 and b.text==text('UI_B47AutoClean_ProgressSurvey'))
 assert(b.capture==false and b.mouseEvents==false and b.keyEvents==false and b.follow and b.playerOnly==0)
 assert(b.setProgress==ISProgressBar.setProgress and b.prerender~=ISProgressBar.prerender)
 f.ui.cancel(f.actor);assert(b.removed and b.removals==1);f.ui.uninstall()
end)
test('authority snapshot counts target completion only, including already-clean and skipped work',function()
 local f=fixture();assert(f.ui.start(f.actor));local op=f.ui.active[f.actor].operation
 local initial=f.ui.jobs.status(f.actor,op);assert(initial.surveyed==false and initial.trashTotal==0)
 local a=f:untilPhase('clean');local b=f.ui.progress.bars[f.actor]
 assert(b.state.known and b.state.total==2 and b.state.completed==0 and b.progress==0)
 local count=0;for _ in pairs(f.ui.progress.bars) do count=count+1 end;assert(count==1)
 f:advance(a);f:tick();assert(b.state.completed==1 and b.progress==0.5)
 f:run();local result=f.ui.jobs.status(f.actor,op)
 assert(result.actions==2 and result.total==2 and b.removed and not f.ui.progress.bars[f.actor]);f.ui.uninstall()
end)
test('bar displays fetch preparation clean and return phases without fake elapsed progress',function()
 local f=fixture();local r={};local active={[f.actor]=r};local hud=Progress.new(active)
 for _,row in ipairs({{'fetch','waiting','Fetching supplies'}, {'clean','water','Preparing supplies'},
  {'clean','clean','Cleaning'}, {'return','waiting','Returning supplies'}}) do
  hud.update(f.actor,r,state(10,3,1,row[1],row[2]));local b=hud.bars[f.actor]
  assert(b.progress==0.3 and b.text==row[3]..': 30%')
 end
 hud.update(f.actor,r,state(10,10,2,'return'));assert(hud.bars[f.actor].text=='Returning supplies: 100%')
 hud.close();f.ui.uninstall()
end)
test('world projection follows movement zoom font changes and clips to the owning viewport',function()
 local f=fixture();local r={};local hud=Progress.new({[f.actor]=r});hud.update(f.actor,r,state(4,1))
 local b=hud.bars[f.actor];b:prerender();local x,y=b.x,b.y
 assert(#b.draws==2 and b.draws[2][3]==(b.width-4)*0.25 and b.clipped and not b.stencil)
 f.actor.stand=f.second;b:prerender();assert(b.x>x and b.y>y)
 local oldY=b.y;zoom=2;b:prerender();assert(b.y>oldY)
 local height=b.height;fontHeight=24;b:prerender();assert(b.height>height and b.textH==24)
 local before=#b.draws;screens[0].width=100;b:prerender();assert(#b.draws==before)
 screens[0].width=1280;hud.close();f.ui.uninstall()
end)
test('split-screen bars remain bound to the exact local actor and viewport',function()
 local f=fixture();local other={getPlayerNum=function() return 1 end,isDead=function() return false end,
  getX=function() return 10 end,getY=function() return 10 end,getZ=function() return 0 end}
 local lookup=getSpecificPlayer;getSpecificPlayer=function(n) if n==1 then return other end;return lookup(n) end
 local a,b={},{};local hud=Progress.new({[f.actor]=a,[other]=b})
 hud.update(f.actor,a,state(4,1));hud.update(other,b,state(8,6))
 local first,second=hud.bars[f.actor],hud.bars[other];first:prerender();second:prerender()
 assert(first.playerOnly==0 and second.playerOnly==1 and first.progress==0.25 and second.progress==0.75)
 assert(first.x==second.x and second.x+second.width<=screens[1].width)
 hud.close();getSpecificPlayer=lookup;f.ui.uninstall()
end)
test('invalid display snapshots cannot replace confirmed progress or touch job state',function()
 local f=fixture();local r={};local hud=Progress.new({[f.actor]=r});hud.update(f.actor,r,state(10,2));local b=hud.bars[f.actor]
 for _,bad in ipairs({state(10,11),state(-1,0),state(10,0/0),state(math.huge,1),state(10,2,3),state(10,1.5)}) do
  hud.update(f.actor,r,bad);assert(b.progress==0.2)
 end
 assert(not f.ui.active[f.actor] and f.target.blood and not f.adds);hud.close();f.ui.uninstall()
end)
test('cancel death actor replacement and stale-frame callbacks clean up exactly once',function()
 for _,case in ipairs({'cancel','death','replacement','uninstall'}) do
  local f=fixture();assert(f.ui.start(f.actor));local b=f.ui.progress.bars[f.actor]
  if case=='cancel' then f.ui.cancel(f.actor)
  elseif case=='death' then f.actor.dead=true;b:prerender()
  elseif case=='replacement' then getSpecificPlayer=function() return nil end;b:prerender()
  else f.ui.uninstall() end
  assert(b.removed and b.removals==1);b:prerender();f.ui.uninstall();assert(b.removals==1)
 end
end)
test('stale job cleanup does not remove the replacement job bar',function()
 local f=fixture();local old,new={},{};local active={[f.actor]=old};local hud=Progress.new(active)
 hud.update(f.actor,old,state(10,1));local previous=hud.bars[f.actor]
 active[f.actor]=new;hud.update(f.actor,new,state(5,2));local current=hud.bars[f.actor]
 hud.clear(f.actor,old);previous:prerender();assert(previous.removed and not current.removed and hud.bars[f.actor]==current)
 hud.close();f.ui.uninstall()
end)
test('area preview has no bar and only confirmed area work shows progress',function()
 local f=fixture();local before=package.loaded['B47ANCEDAutoClean/AreaSelector'];local confirm
 package.loaded['B47ANCEDAutoClean/AreaSelector']={open=function(num,callback) confirm=callback;return {closeEditor=function() end} end}
 assert(f.ui.selectArea(f.actor) and not f.ui.progress.bars[f.actor])
 confirm({{0,9,13,15},{0,10,13,15},{0,11,13,15}})
 assert(f.ui.progress.bars[f.actor]);f:run();assert(not f.ui.progress.bars[f.actor])
 f.ui.uninstall();package.loaded['B47ANCEDAutoClean/AreaSelector']=before
end)
test('multiplayer progress accepts only the matching job response and sends no display counts',function()
 local f=fixture();f.ui.uninstall();SERVER=false;CLIENT=true
 local A=require 'B47ANCEDAutoClean/NativeAction';_G[A.name]=nil
 local sent={};sendClientCommand=function(actor,module,command,args) sent[#sent+1]={command=command,args=args} end
 local ui=assert(require('B47ANCEDAutoClean/BuildingWire').client());assert(ui.start(f.actor))
 local request=sent[#sent].args.request;local b=ui.progress.bars[f.actor]
 local function message(args) for fn in pairs(Events.OnServerCommand.handlers) do fn('B47AutoCleanNativePOC','buildingState',args) end end
 message({protocol=1,request='foreign-request',operation='foreign',status='waiting',progress=state(10,9)})
 assert(b.progress==0 and not b.state)
 message({protocol=1,request=request,operation='owned',status='waiting',progress=state(10,4)})
 assert(b.progress==0.4)
 for _,p in ipairs(sent) do assert(not p.args.progress and not p.args.completed and not p.args.total) end
 ui.cancel(f.actor);assert(b.removed);ui.uninstall()
end)
test('server attaches owned progress snapshots and rejects client-supplied counters',function()
 local f=AUTO_CLEAN_BUILDING_FIXTURE();f.job.cancel(f.actor,f.id)
 local A=require 'B47ANCEDAutoClean/NativeAction';_G[A.name]=nil
 local output={};sendServerCommand=function(actor,module,command,args) assert(actor==f.actor);output[#output+1]=args end
 local installed=assert(require('B47ANCEDAutoClean/BuildingWire').server())
 local function fire(command,args) for fn in pairs(Events.OnClientCommand.handlers) do fn('B47AutoCleanNativePOC',command,f.actor,args) end end
 for _,key in ipairs({'progress','total','completed','trashTotal'}) do
  local args={protocol=1,request=getRandomUUID()};args[key]=999;fire('buildingBegin',args)
 end
 assert(#output==0)
 fire('buildingBegin',{protocol=1,request=getRandomUUID()});local first=output[#output]
 assert(first.operation and first.progress and not first.progress.known and first.progress.completed==0)
 local result
 for _=1,20 do
  NOW=NOW+300;fire('buildingPoll',{protocol=1,request=getRandomUUID(),operation=first.operation})
  result=output[#output];if result.progress.known then break end
 end
 assert(result.progress.known and result.progress.total==2 and result.progress.completed==0)
 assert(result.progress.stage=='fetch' and f.target.blood and not f.adds)
 installed.uninstall()
end)
print('PASS '..groups..' overhead progress scenarios OFFLINE; actual vanilla ISProgressBar, simulated native UI/viewport')
return groups
