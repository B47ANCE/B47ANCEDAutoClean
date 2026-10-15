-- Shared gameplay values are read on the authority; clients cannot submit them.
local O={}
function O.read(base)
 local result={};for k,v in pairs(base or {}) do result[k]=v end
 local vars=SandboxVars and SandboxVars.B47ANCEDAutoClean or {}
 result.trashEnabled=vars.RemoveTrashObjects==nil or vars.RemoveTrashObjects==true
 return result
end
function O.matches(options)
 local current=O.read()
 return options and options.trashEnabled==current.trashEnabled
end
return O
