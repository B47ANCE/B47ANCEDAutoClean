-- A transient selection view over Rooms' editor, draft and rendering controls.
-- No roomList/roomChange request, registry mutation or cleaning action is sent here.
local Editor=require 'B47ANCEDRooms/Editor'
local Draft=require 'B47ANCEDRooms/Draft'
local G=require 'B47ANCEDRooms/Geometry'
local U=B47RoomsUI
local S=Editor:derive('B47AutoCleanAreaSelector')
local active={}
local function text(key,...) return getText('UI_B47AutoClean_'..key,...) end
local function roomText(key,...) return getText('UI_B47Rooms_'..key,...) end
function S:closeEditor(confirmed)
 if self.closed then return end
 self.closed=true;self.down=false;self.first=nil
 self:setCapture(false);self:setWantKeyEvents(false)
 for _,hook in ipairs(self.hooks or {}) do hook.event.Remove(hook.fn) end
 self.hooks=nil;active[self.playerNum]=nil
 ISPanelJoypad.removeFromUIManager(self)
 U.Focus.restore(self.playerNum,nil)
 local cancelled=self.onCancel;self.onCancel=nil;self.onConfirm=nil
 self.draft=nil;self.edgeCache=nil;self.saved=nil
 if confirmed~=true and cancelled then cancelled() end
end
function S:confirm()
 if self.closed or self.first or self.down or getSpecificPlayer(self.playerNum)~=self.player or self.player:isDead() then return false end
 local options=require('B47ANCEDRooms/API').cleaningOptions()
 local geometry=G.normalize(self.draft.geometry.rows,options.tileLimit)
 if not options.enabled or not geometry or geometry.count==0 then return false end
 local callback=self.onConfirm
 self:closeEditor(true)
 if callback then callback(geometry.rows) end
 return true
end
function S:onKeyPress(key)
 if key==Keyboard.KEY_ESCAPE then self:closeEditor()
 elseif isCtrlKeyDown() and key==Keyboard.KEY_Z then
  if isShiftKeyDown() then self.draft:redo() else self.draft:undo() end
 elseif isCtrlKeyDown() and key==Keyboard.KEY_Y then self.draft:redo() end
end
function S:createChildren()
 self.sidebar=ISPanelJoypad:new(math.max(0,self.width-360),0,math.min(360,self.width),self.height)
 self.sidebar.playerNum=self.playerNum;self.sidebar:initialise();self:addChild(self.sidebar);U.skin(self.sidebar,'panel')
 self.sidebar:setScrollChildren(true);self.sidebar:addScrollBars()
 self.joypadButtonsY={};self.allJoypadButtons={};self.joypadButtons={};self.buttons={};self.controlRows={}
 local y=12;local h=U.Theme.metrics().button;local width=self.sidebar.width-24
 self.controlHeight=h
 local function row(left,right)
  local controls={}
  for i,spec in ipairs({left,right}) do
   local w=right and (width-4)/2 or width
   local b=U.Button:new(12+(i-1)*(w+4),y,w,h,spec.label,self,spec.action)
   b.playerNum=self.playerNum;b:initialise();b:instantiate();self.sidebar:addChild(b);U.skin(b,'button',spec.primary and 'primary')
   self.buttons[spec.key]=b;controls[#controls+1]=b
  end
  self:insertNewLineOfButtons(unpack(controls));y=y+h+4
  self.controlRows[#self.controlRows+1]=controls
 end
 local function tool(key)
  return {key=key,label=roomText(key),action=function() self.tool=key;self.first=nil;self.down=false;self:setCapture(false);self.worldFocus=true;setJoypadFocus(self.playerNum,self) end}
 end
 row(tool('RoomAddRectangle'),tool('RoomRemoveRectangle'))
 row(tool('RoomPaint'),tool('RoomErase'))
 row({key='Undo',label=roomText('RoomUndo'),action=function() self.draft:undo();self.first=nil end},
     {key='Redo',label=roomText('RoomRedo'),action=function() self.draft:redo();self.first=nil end})
 row({key='FloorDown',label=roomText('RoomFloorDown'),action=function() self:changeFloor(-1) end},
     {key='FloorUp',label=roomText('RoomFloorUp'),action=function() self:changeFloor(1) end})
 row({key='Clear',label=roomText('RoomClear'),action=function() self.draft:set(assert(G.normalize({})));self.first=nil;self.down=false;self:setCapture(false) end})
 row({key='Start',label=text('StartCleaning'),action=S.confirm,primary=true},
     {key='Cancel',label=roomText('Cancel'),action=S.closeEditor})
 self.statusY=y+8
 local old=self.sidebar.prerender
 self.sidebar.prerender=function(panel)
  if self.closed or not self.draft then return end
  old(panel)
  local width=panel.width-24
  local lines={text('SelectTitle'),text('SelectionOnly'),roomText(self.tool),
   roomText('RoomCounts',self.floor,self.draft.geometry.count),text('SelectionHelp'),
   text('SelectionHelp2'),text('SelectionGuard'),text('SelectionLogistics'),roomText('RoomWorldHelp')}
  local lineHeight=math.max(24,(U.Theme.metrics().font or 16)+8)
  for i,line in ipairs(lines) do U.Renderer.text(panel,U.Renderer.fit(line,width),12,self.statusY+(i-1)*lineHeight,U.Theme.colors.text) end
  panel:setScrollHeight(self.statusY+#lines*lineHeight+12)
 end
 self.joypadIndex=1;self.joypadIndexY=1
end
function S:changeFloor(delta)
 self.floor=math.max(-32,math.min(31,self.floor+delta));self.cursor.z=self.floor
 self.first=nil;self.down=false;self:setCapture(false);self.edgeSource=nil
end
function S:update()
 if self.closed then return end
 if self.removed or getSpecificPlayer(self.playerNum)~=self.player or self.player:isDead() then self:closeEditor();return end
 local width,height=getPlayerScreenWidth(self.playerNum),getPlayerScreenHeight(self.playerNum)
 self:setX(getPlayerScreenLeft(self.playerNum));self:setY(getPlayerScreenTop(self.playerNum))
 local buttonHeight=U.Theme.metrics().button
 if width~=self.width or height~=self.height or buttonHeight~=self.controlHeight then
  self:setWidth(width);self:setHeight(height);self.sidebar:setWidth(math.min(360,width));self.sidebar:setX(math.max(0,width-self.sidebar.width));self.sidebar:setHeight(height)
  local y=12
  for _,row in ipairs(self.controlRows) do
   local w=(self.sidebar.width-24-(#row-1)*4)/#row
   for i,button in ipairs(row) do button:setX(12+(i-1)*(w+4));button:setY(y);button:setWidth(w);button:setHeight(buttonHeight) end
   y=y+buttonHeight+4
  end
  self.statusY=y+8;self.controlHeight=buttonHeight
 end
 self.buttons.Start:setEnable(self.draft.geometry.count>0 and not self.first and not self.down)
 for _,key in ipairs({'RoomAddRectangle','RoomRemoveRectangle','RoomPaint','RoomErase'}) do self.buttons[key].b47Selected=self.tool==key end
end
function S.open(num,onConfirm,onCancel)
 if isServer() or type(onConfirm)~='function' then return nil end
 if active[num] then active[num]:closeEditor() end
 local player=getSpecificPlayer(num);if not player or player:isDead() then return nil end
 local panel=ISPanelJoypad.new(S,getPlayerScreenLeft(num),getPlayerScreenTop(num),getPlayerScreenWidth(num),getPlayerScreenHeight(num))
 panel.playerNum=num;panel.player=player;panel.floor=math.floor(player:getZ())
 panel.cursor={x=math.floor(player:getX()),y=math.floor(player:getY()),z=panel.floor}
 panel.draft=Draft.new();panel.saved={};panel.tool='RoomAddRectangle';panel.worldFocus=true
 panel.onConfirm=onConfirm;panel.onCancel=onCancel;panel.hooks={}
 panel:initialise();panel:instantiate();panel:addToUIManager();panel:setWantKeyEvents(true);panel:bringToTop()
 active[num]=panel;setJoypadFocus(num,panel)
 if Events then for _,name in ipairs({'OnDisconnect','OnMainMenuEnter','OnPlayerDeath'}) do
  local eventName=name
  local event=Events[name]
  if event then
   local fn=function(actor) if eventName~='OnPlayerDeath' or actor==player then panel:closeEditor() end end
   event.Add(fn);panel.hooks[#panel.hooks+1]={event=event,fn=fn}
  end
 end end
 return panel
end
return S
