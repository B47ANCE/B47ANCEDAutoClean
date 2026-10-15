-- Shared gameplay values are read on the authority; clients cannot submit them.
local O={}
function O.read(base)
 local result={};for k,v in pairs(base or {}) do result[k]=v end
 local vars=SandboxVars and SandboxVars.B47ANCEDAutoClean or {}
 result.trashEnabled=vars.RemoveTrashObjects==nil or vars.RemoveTrashObjects==true
 local seconds=vars.TrashPickupSeconds
 if type(seconds)~='number' or seconds~=seconds or seconds%1~=0 or seconds<1 or seconds>10 then seconds=2 end
 result.trashSeconds=seconds
 return result
end
function O.matches(options)
 local current=O.read()
 return options and options.trashEnabled==current.trashEnabled and options.trashSeconds==current.trashSeconds
end
return O
