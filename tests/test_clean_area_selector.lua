-- Actual Rooms editor/draft and Auto Clean selector; UI/engine services are doubles.
local groups=0
local function check(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));groups=groups+1 end
SERVER=false;CLIENT=false
local function events()
 return setmetatable({},{__index=function(t,k)
  local e={handlers={}};function e.Add(fn) e.handlers[fn]=true end;function e.Remove(fn) e.handlers[fn]=nil end;rawset(t,k,e);return e
 end})
end
Events=events()
local Panel=ISBaseObject:derive('SelectorTestPanel')
function Panel:new(x,y,w,h) self.__index=self;return setmetatable({x=x,y=y,width=w,height=h,children={},joypadButtonsY={}},self) end
function Panel:initialise() self.children={} end
function Panel:instantiate() if self.createChildren then self:createChildren() end end
function Panel:addChild(child) self.children[#self.children+1]=child;child.parent=self end
function Panel:addToUIManager() self.added=true end
function Panel:removeFromUIManager() self.removed=true end
function Panel:setCapture(value) self.capture=value end
function Panel:setWantKeyEvents(value) self.keys=value end
function Panel:bringToTop() end
function Panel:prerender() end
function Panel:setScrollChildren() end
function Panel:addScrollBars() end
function Panel:setScrollHeight(value) self.scrollHeight=value end
function Panel:setX(value) self.x=value end
function Panel:setY(value) self.y=value end
function Panel:setWidth(value) self.width=value end
function Panel:setHeight(value) self.height=value end
function Panel:insertNewLineOfButtons(...) self.joypadButtonsY[#self.joypadButtonsY+1]={...} end
function Panel:restoreJoypadFocus() self.focusRestored=true end
function Panel:drawLineAbsolute(...) self.lines=self.lines or {};self.lines[#self.lines+1]={...} end
ISPanelJoypad=Panel
local Button=Panel:derive('SelectorTestButton')
function Button:new(x,y,w,h,title,target,onclick)
 local self=Panel.new(self,x,y,w,h);self.title=title;self.target=target;self.onclick=onclick;return self
end
function Button:setEnable(value) self.enabled=value end
local function click(button) return button.onclick(button.target,button) end
local restoreCount=0
B47RoomsUI={Button=Button,skin=function() end,Theme={metrics=function() return {button=28} end,colors={text={}}},
 Renderer={text=function() end,fit=function(value) return value end},
 Dialog={active=function() return false end},Focus={restore=function() restoreCount=restoreCount+1 end}}
package.loaded['ISUI/ISPanelJoypad']=true;package.loaded['ISUI/ISContextMenu']=true
package.loaded['B47RoomsUI/Controls']=true;package.loaded['B47RoomsUI/Dialog']=true
package.loaded['B47ANCEDRooms/Editor']=nil;package.loaded['B47ANCEDAutoClean/AreaSelector']=nil
local screen={left=0,top=0,width=1280,height=720}
getPlayerScreenLeft=function() return screen.left end;getPlayerScreenTop=function() return screen.top end
getPlayerScreenWidth=function() return screen.width end;getPlayerScreenHeight=function() return screen.height end
local actor={isDead=function(self) return self.dead end,getX=function() return 10 end,getY=function() return 10 end,getZ=function() return 0 end}
local current=actor
getSpecificPlayer=function(num) return num==0 and current or nil end
setJoypadFocus=function() end
local mouse={x=10,y=10}
getMouseXScaled=function() return mouse.x end;getMouseYScaled=function() return mouse.y end
ISCoordConversion={ToWorld=function(x,y) return x,y end}
isoToScreenX=function(num,x,y,z) return screen.left+(x-y)*10 end
isoToScreenY=function(num,x,y,z) return screen.top+(x+y-z)*10 end
Keyboard={KEY_ESCAPE=27,KEY_Z=90,KEY_Y=89};Joypad={AButton=1,BButton=2,YButton=4}
local ctrl,shift=false,false
isCtrlKeyDown=function() return ctrl end;isShiftKeyDown=function() return shift end
if ROOMS_EDITOR_COMPAT_PATH then package.loaded['B47ANCEDRooms/Editor']=dofile(ROOMS_EDITOR_COMPAT_PATH) end
local Selector=require 'B47ANCEDAutoClean/AreaSelector'
local Editor=require 'B47ANCEDRooms/Editor'
local function drag(panel,x1,y1,x2,y2)
 mouse.x=x1;mouse.y=y1;panel:onMouseDown(0,0)
 mouse.x=x2;mouse.y=y2;if x1~=x2 or y1~=y2 then panel:onMouseMove(x2-x1,y2-y1) end;panel:onMouseUp(0,0)
end
local function count(event) local n=0;for _ in pairs(event.handlers) do n=n+1 end;return n end
check('reuses Rooms input and native zoom-aware outline implementation',function()
 assert(Selector.onMouseDown==Editor.onMouseDown and Selector.onMouseUp==Editor.onMouseUp)
 assert(Selector.apply==Editor.apply and Selector.prerender==Editor.prerender and Selector.drawWorldLine==Editor.drawWorldLine)
end)
check('drag previews only; explicit Start confirms exactly once',function()
 local calls=0;local p=Selector.open(0,function(rows) calls=calls+1;assert(#rows==3 and rows[1][3]==13 and rows[1][4]==15) end)
 assert(p and calls==0 and not p.closed)
 drag(p,13,9,15,11);assert(p.draft.geometry.count==9 and calls==0)
 p:update();assert(p.buttons.Start.enabled)
 assert(click(p.buttons.Start));assert(calls==1 and p.closed and not p:confirm())
end)
check('Cancel button and repeated close never confirm or strand selection',function()
 local confirmed,cancelled=0,0;local p=Selector.open(0,function() confirmed=confirmed+1 end,function() cancelled=cancelled+1 end)
 drag(p,13,9,15,11);click(p.buttons.Cancel);p:closeEditor()
 p.sidebar:prerender() -- stale same-frame presentation callback after removal
 assert(p.closed and not p.capture and not p.keys and confirmed==0 and cancelled==1)
end)
check('empty or unfinished rectangle cannot start',function()
 local p=Selector.open(0,function() error('unexpected start') end)
 p:update();assert(not p.buttons.Start.enabled and not p:confirm())
 p.first={x=1,y=1,z=0};assert(not p:confirm());p:closeEditor()
end)
check('paint, erase and undo/redo retain exact preview geometry',function()
 local p=Selector.open(0,function() end)
 p.tool='RoomPaint';drag(p,13,9,14,9);assert(p.draft.geometry.count==2)
 p.tool='RoomErase';drag(p,13,9,13,9);assert(p.draft.geometry.count==1)
 click(p.buttons.Undo);assert(p.draft.geometry.count==2)
 click(p.buttons.Redo);assert(p.draft.geometry.count==1);p:closeEditor()
end)
check('floor controls add explicit separate layers and clear is undoable',function()
 local p=Selector.open(0,function() end);drag(p,13,9,15,11)
 click(p.buttons.FloorUp);assert(p.floor==1 and p.cursor.z==1)
 drag(p,13,9,15,11);assert(p.draft.geometry.count==18)
 click(p.buttons.Clear);assert(p.draft.geometry.count==0)
 click(p.buttons.Undo);assert(p.draft.geometry.count==18)
 click(p.buttons.FloorDown);assert(p.floor==0);p:closeEditor()
end)
check('keyboard undo/redo and Escape cancel without confirmation',function()
 local cancelled=0;local p=Selector.open(0,function() error('unexpected start') end,function() cancelled=cancelled+1 end)
 drag(p,13,9,15,11);ctrl=true;p:onKeyPress(Keyboard.KEY_Z);assert(p.draft.geometry.count==0)
 p:onKeyPress(Keyboard.KEY_Y);assert(p.draft.geometry.count==9);ctrl=false
 p:onKeyPress(Keyboard.KEY_ESCAPE);assert(p.closed and cancelled==1)
end)
check('inherited controller world selection and focus exit are available',function()
 local p=Selector.open(0,function() end);p:onJoypadDown(Joypad.AButton,{})
 p:onJoypadDirRight({});p:onJoypadDown(Joypad.AButton,{});assert(p.draft.geometry.count==2)
 p:onJoypadDown(Joypad.BButton,{});assert(not p.worldFocus and not p.closed)
 p:onJoypadDown(Joypad.BButton,{});assert(p.closed)
end)
check('viewport resize keeps sidebar and controls inside the player viewport',function()
 local p=Selector.open(0,function() end)
 screen={left=640,top=0,width=480,height=540};p:update()
 assert(p.x==640 and p.width==480 and p.sidebar.x+p.sidebar.width<=480)
 for _,row in ipairs(p.controlRows) do for _,button in ipairs(row) do assert(button.x>=0 and button.x+button.width<=p.sidebar.width) end end
 local metrics=B47RoomsUI.Theme.metrics;B47RoomsUI.Theme.metrics=function() return {button=56,font=44} end
 p:update();assert(p.buttons.Start.height==56 and p.controlRows[2][1].y==72)
 p.sidebar:prerender();assert(p.sidebar.scrollHeight>p.statusY)
 B47RoomsUI.Theme.metrics=metrics
 p:closeEditor();screen={left=0,top=0,width=1280,height=720}
end)
check('death/disconnect hooks are removed and cancellation is one-shot',function()
 local baseline=count(Events.OnDisconnect);local cancelled=0
 local p=Selector.open(0,function() end,function() cancelled=cancelled+1 end)
 assert(count(Events.OnDisconnect)==baseline+1)
 for fn in pairs(Events.OnPlayerDeath.handlers) do fn(actor) end
 assert(p.closed and cancelled==1 and count(Events.OnDisconnect)==baseline)
end)
check('local-player replacement closes preview without starting',function()
 local cancelled=0;local p=Selector.open(0,function() error('unexpected start') end,function() cancelled=cancelled+1 end)
 current={};p:update();assert(p.closed and cancelled==1);current=actor
end)
check('reopening replaces prior preview and rendering uses Rooms boundary edges',function()
 local cancelled=0;local p=Selector.open(0,function() end,function() cancelled=cancelled+1 end)
 local nextPanel=Selector.open(0,function() end);assert(p.closed and cancelled==1)
 drag(nextPanel,13,9,15,11);nextPanel:prerender();assert(#nextPanel.lines>0)
 nextPanel:closeEditor()
end)
print('PASS '..groups..' Rooms-derived area selector scenarios OFFLINE; native rendering NOT TESTED')
return groups
