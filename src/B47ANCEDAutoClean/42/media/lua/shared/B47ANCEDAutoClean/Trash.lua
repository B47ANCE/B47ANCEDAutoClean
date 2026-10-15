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
function T.presentation(actor,object,ticks)
 local a=ISBaseTimedAction:new(actor);a.maxTime=ticks;a.trashObject=object
 function a:isValid() return self.trashObject and self.trashObject:getSquare()~=nil end
 function a:getDuration() return ticks end
 function a:adjustMaxTime() return ticks end -- no instant-action timing bypass
 function a:start()
  self.character:faceThisObject(object);self:setActionAnim('Loot')
  self.character:SetVariable('LootPosition','Low');self:setOverrideHandModels(nil,nil)
 end
 return a
end
function T.action(actor,record,scope,options,native,rooms)
 local ticks=options.trashSeconds*50
 local a=T.presentation(actor,record.object,ticks)
 local started,closed=false,false
 local function valid(self)
  return self==a and self.character==actor and not closed and T.allowed(actor,record,scope,native,rooms)
   and native.optionsValid(options) and native.near(actor,record.square)
 end
 function a:isValid() return valid(self) end
 function a:serverStart()
  if started or not valid(self) then return false end
  started=native.now();return true
 end
 function a:complete()
  if not started or not valid(self) then return false end
  local elapsed=native.now()-started
  local progress=native.localAuthority and self:getJobDelta() or self.netAction and self.netAction:getProgress()
  if elapsed<ticks*20 or elapsed>120000 or progress~=1 then return false end
  closed=true -- latch before native mutation, including callbacks/reentry/errors
  local result=record.square:transmitRemoveItemFromSquare(record.object,false)
  return type(result)=='number' and result>=0 and not member(record.square,record.object)
 end
 return a
end
return T
