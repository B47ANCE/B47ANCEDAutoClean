-- Independent allowlist from vanilla forageSystem.spriteAffinities.trash (42.21).
-- Exact plain decorative objects only. Never enumerate or collect world items.
local T={}
local sprites={}
for i=0,25 do sprites['d_trash_'..i]=true end
for i=0,12 do sprites['trash_01_'..i]=true end
for i=16,53 do sprites['trash_01_'..i]=true end
local function member(square,object)
 local list=square and square:getObjects()
 if not list or list:size()>512 then return false end -- same bounded survey limit
 for i=0,list:size()-1 do if list:get(i)==object then return true end end
 return false
end
function T.capture(object,square)
 if not object or not square or not square:getChunk() or instanceof(object,'IsoWorldInventoryObject') or not instanceof(object,'IsoObject')
  or not object.getObjectName or object:getObjectName()~='IsoObject' or object:getContainerCount()~=0
  or not object.getSprite or object:getSquare()~=square or not member(square,object) then return nil end
 local sprite=object:getSprite()
 if not sprite or not sprites[sprite:getName()] or sprite:getSpriteGrid()~=nil or next(object:getModData())~=nil then return nil end
 return {object=object,square=square,sprite=sprite,name=sprite:getName(),chunk=square:getChunk()}
end
function T.valid(record)
 if not record or getCell():getGridSquare(record.square:getX(),record.square:getY(),record.square:getZ())~=record.square
  or record.square:getChunk()~=record.chunk then return false end
 local current=T.capture(record.object,record.square)
 return current~=nil and current.sprite==record.sprite and current.name==record.name
end
function T.allowed(actor,record,scope,native,rooms)
 local s=record and record.square
 return native.server() and native.actorValid(actor) and T.valid(record)
  and rooms.cleaningTargetTile(actor,scope,s:getX(),s:getY(),s:getZ())
  and rooms.canCleanBuildingTile(actor,scope,s:getX(),s:getY(),s:getZ()).state=='allow'
end
function T.broom(item)
 return item and (item:getFullType()=='Base.Broom' or item:getFullType()=='Base.Broom_Twig')
  and not item:isBroken() and not item:isFavorite() and not item:getIsCraftingConsumed() and item:getAttachedSlot()==-1
  and not item:isForceDropHeavyItem() and not item:canBeActivated()
end
function T.presentation(actor,object,broom)
 require 'TimedActions/ISPickUpGroundCoverItem'
 require 'TimedActions/ISClearAshes'
 require 'Util/BuildingHelper'
 local a
 if broom then a=ISClearAshes:new(actor,object)
 else a=ISPickUpGroundCoverItem:new(actor,object:getSquare(),object) end
 a.trashObject=object;a.trashBroom=broom
 -- Keep vanilla duration, modifiers, wait/start/update/stop/perform. Its original
 -- completion may create inventory items or expand removal, so never queue it.
 function a:complete() return false end
 return a
end
function T.action(actor,record,scope,options,native,rooms)
 local broom=record.broom
 local a=T.presentation(actor,record.object,broom)
 local duration,adjust=a.getDuration,a.adjustMaxTime
 local started,closed,minimum=false,false,nil
 local function valid(self)
  return self==a and self.character==actor and not closed and T.allowed(actor,record,scope,native,rooms)
   and native.optionsValid(options) and native.near(actor,record.square)
   and self.trashObject==record.object and self.trashBroom==broom
   and (not broom or T.broom(broom) and native.carried(actor,broom) and native.hand(actor)==broom)
 end
 function a:isValid() return valid(self) end
 function a:serverStart()
  if started or not valid(self) then return false end
  -- Same owned vanilla callbacks as NetTimedAction.getDuration; 20 ms per native
  -- action tick is the installed engine conversion, not a gameplay duration.
  local adjusted=adjust(self,duration(self))
  if type(adjusted)~='number' or adjusted~=adjusted or adjusted<=0 or adjusted>6000 then return false end
  minimum=math.floor(adjusted*20) -- native Action.setTimeData stores whole milliseconds
  started=native.now();return true
 end
 function a:complete()
  if not started or not valid(self) then return false end
  local elapsed=native.now()-started
  local progress=native.localAuthority and self:getJobDelta() or self.netAction and self.netAction:getProgress()
  -- SP's owned native queue accounts for game-speed acceleration. Its completed
  -- native progress is authoritative; a wall-clock minimum would break it.
  if elapsed<0 or elapsed>120000 or progress~=1 or not native.localAuthority and elapsed<minimum then return false end
  closed=true -- latch before native mutation, including callbacks/reentry/errors
  local result=record.square:transmitRemoveItemFromSquare(record.object,false)
  return type(result)=='number' and result>=0 and not member(record.square,record.object)
 end
 return a
end
return T
