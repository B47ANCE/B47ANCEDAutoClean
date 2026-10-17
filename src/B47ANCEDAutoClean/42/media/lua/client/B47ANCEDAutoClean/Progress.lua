-- Local presentation only. Never touches the native current-action progress bar.
require 'ISUI/ISProgressBar'
local P={}
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<math.huge and n%1==0 end
local function snapshot(s)
 if type(s)~='table' or type(s.known)~='boolean' or not integer(s.total) or not integer(s.completed)
  or not integer(s.skipped) or s.completed>s.total or s.skipped>s.completed then return nil end
 return {known=s.known,total=s.total,completed=s.completed,skipped=s.skipped,stage=s.stage,phase=s.phase}
end
local function label(s)
 if not s or not s.known then return getText('UI_B47AutoClean_ProgressSurvey') end
 local text
 if s.stage=='return' then text=getText('UI_B47AutoClean_ProgressReturn')
 elseif s.stage=='fetch' or s.stage=='trashPrepare' then text=getText('UI_B47AutoClean_ProgressFetch')
 elseif s.phase=='bleach' or s.phase=='water' then text=getText('UI_B47AutoClean_ProgressPrepare')
 else text=getText('UI_B47AutoClean_ProgressClean') end
 return getText('UI_B47AutoClean_ProgressCount',text,s.total>0 and math.floor(100*s.completed/s.total) or 0)
end
function P.new(active)
 local bars={};local api={bars=bars}
 function api.clear(actor,record)
  local b=bars[actor]
  if not b or record and b.record~=record then return end
  bars[actor]=nil;b.closed=true;b:removeFromUIManager()
 end
 function api.update(actor,record,state)
  if not actor or not actor.getPlayerNum or getSpecificPlayer(actor:getPlayerNum())~=actor or actor:isDead() or active[actor]~=record then
   api.clear(actor,record);return
  end
  local b=bars[actor]
  if b and b.record~=record then api.clear(actor);b=nil end
  if not b then
   b=ISProgressBar:new(0,0,180,20,nil,UIFont.Small)
   b:initialise();b:setWantMouseEvents(false);b:setWantKeyEvents(false)
   b.record=record;b.playerNum=actor:getPlayerNum();bars[actor]=b
   function b:prerender()
    if self.closed then return end
    if active[actor]~=record or actor:isDead() or getSpecificPlayer(self.playerNum)~=actor then api.clear(actor,record);return end
    -- Vanilla ISSearchManager's viewport-local, zoom-aware overhead projection.
    local num=self.playerNum;local zoom=getCore():getZoom(num)
    if type(zoom)~='number' or zoom~=zoom or zoom<=0 or zoom==math.huge then return end
    local tm=getTextManager();local fontHeight=tm:getFontFromEnum(self.font):getLineHeight()
    self.textH=fontHeight;self.textW=tm:MeasureStringX(self.font,self.text or '')
    local vw,vh=getPlayerScreenWidth(num),getPlayerScreenHeight(num)
    local width=math.min(vw-8,math.max(180,(self.textW or 0)+16))
    local height=fontHeight+6
    local x=isoToScreenX(num,actor:getX(),actor:getY(),actor:getZ())-getPlayerScreenLeft(num)-width/2
    local y=isoToScreenY(num,actor:getX(),actor:getY(),actor:getZ())-getPlayerScreenTop(num)-140/zoom-3*fontHeight-height
    -- Do not spill into another split-screen viewport or draw an offscreen actor.
    if width<=0 or x<0 or x+width>vw or y<0 or y+height>vh then return end
    self:setX(x);self:setY(y);self:setWidth(width);self:setHeight(height)
    self:setStencilRect(0,0,width,height)
    ISProgressBar.prerender(self)
    self:clearStencilRect()
   end
   b:addToUIManager();b:setCapture(false);b:setFollowGameWorld(true);b:setRenderThisPlayerOnly(b.playerNum)
  end
  local observed=snapshot(state)
  if observed then b.state=observed end
  b:setText(label(b.state))
  b:setProgress(b.state and b.state.known and b.state.total>0 and b.state.completed/b.state.total or 0)
 end
 function api.close() for actor in pairs(bars) do api.clear(actor) end end
 return api
end
return P
