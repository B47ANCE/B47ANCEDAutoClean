-- Trusted-server-only instance adapter. Never serialize these per-instance callbacks.
local Guard=require 'research/auto-clean/Guard'
local P={}
function P.new(port)
    local guard=Guard.new(port)
    local api={begin=guard.begin,status=guard.status,cancel=guard.cancel,tick=guard.tick}
    function api.next(actor,id)
        if not port.server() then return nil,'notServer' end
        local ok,action,phase=pcall(guard.prepare,actor,id)
        if not ok then guard.cancel(actor,id,'constructionFailed');return nil,'constructionFailed' end
        if not action then return nil,phase end
        local attached,why=guard.attach(actor,id,action)
        if not attached then return nil,why end
        local complete,stop,forceCancel=action.complete,action.stop,action.forceCancel
        local serverStart=action.serverStart
        function action:serverStart()
            local allowed,reason=guard.start(actor,id,self)
            if not allowed then return false,reason end
            if serverStart then
                local success=pcall(serverStart,self)
                if not success then guard.cancel(actor,id,'serverStartFailed');return false,'serverStartFailed' end
            end
            return true
        end
        function action:complete()
            return guard.complete(actor,id,self,function() return complete(self) end)
        end
        if phase=='bleach' then
            local update=action.update
            function action:update()
                return guard.mutate(actor,id,self,function() update(self);return true end)
            end
        elseif phase=='water' then
            local transfer=action.transferFluid
            function action:transferFluid(amount)
                if type(amount)~='number' or amount~=amount or amount<0 or amount==math.huge then
                    guard.cancel(actor,id,'invalidFillAmount');return false
                end
                return guard.mutate(actor,id,self,function() transfer(self,amount);return true end)
            end
        end
        function action:serverStop() return guard.cancel(actor,id,'nativeStopped') end
        function action:stop()
            guard.cancel(actor,id,'nativeStopped')
            if port.server() and stop then return stop(self) end
        end
        function action:forceCancel()
            guard.cancel(actor,id,'queueCancelled')
            if port.server() and forceCancel then return forceCancel(self) end
        end
        return action,phase
    end
    return api
end
return P
