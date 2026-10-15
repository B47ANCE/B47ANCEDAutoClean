-- Explicit shared-class factory; requiring this file does not register a class.
local A={name='ISB47AutoCleanNativePOC',protocol=1}
function A.class(resolve)
    local class=ISBaseTimedAction:derive(A.name)
    -- Native NetTimedAction.set serializes these exact prototype parameter names.
    -- Never add resource references, amounts, timing or callback fields here.
    function class:new(character, operation, phase, grant)
        return resolve(character,operation,phase,grant)
    end
    return class
end
function A.stamp(action,class,operation,phase,grant)
    -- Preserve the complete resolved native inheritance chain and instance guards.
    -- The native serializer needs the shared class as the *actual* metatable.
    local resolved={}
    local parent=getmetatable(action)
    local seen={}
    while type(parent)=='table' and not seen[parent] do
        seen[parent]=true
        for k,v in pairs(parent) do
            if k~='__index' and k~='new' and k~='Type' and k~='SuperType'
                and action[k]~=nil and resolved[k]==nil then resolved[k]=action[k] end
        end
        local mt=getmetatable(parent)
        if type(parent.__index)=='table' and parent.__index~=parent then parent=parent.__index
        else parent=mt and (mt.__index or mt) end
    end
    for k,v in pairs(resolved) do if rawget(action,k)==nil then action[k]=v end end
    class.__index=class
    setmetatable(action,class)
    action.Type=class.Type;action.operation=operation;action.phase=phase;action.grant=grant
    return action
end
function A.token(s) return type(s)=='string' and #s>0 and #s<=80 and s:match('^[%w%-]+$')~=nil end
function A.phase(s) return s=='bleach' or s=='water' or s=='clean' or s=='fetch' or s=='equip' or s=='return' or s=='unequip' end
return A
