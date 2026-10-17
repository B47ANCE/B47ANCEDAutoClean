-- Client presentation/intents only. No completion or shared-state authority.
local Action=require 'research/auto-clean/NativeAction'
local C={}
function C.new(wire)
    local records={}
    local api={}
    local class=Action.class(function(actor,operation,phase,grant)
        local r=records[actor]
        if not r or not r.offer or r.action or r.operation~=operation or r.phase~=phase or r.grant~=grant then return nil end
        local action=wire.resolve(actor,r.offer.view,phase)
        if not action then return nil end
        Action.stamp(action,api.class,operation,phase,grant);r.action=action
        local start,stop,cancel,perform=action.start,action.stop,action.forceCancel,action.perform
        local function confirm()
            if r.started and not r.closed and r.challenge and not r.confirmed then
                r.confirmed=true
                wire.send(actor,'confirm',{protocol=Action.protocol,operation=operation,phase=phase,grant=grant,challenge=r.challenge})
            end
        end
        r.confirm=confirm
        function action:start()
            if start then start(self) end
            r.started=true;confirm()
        end
        local function cancelled()
            if not r.closed then
                r.closed=true
                wire.send(actor,'cancel',{protocol=Action.protocol,operation=operation})
                if records[actor]==r then records[actor]=nil end
            end
        end
        function action:stop() cancelled();if stop then return stop(self) end end
        function action:forceCancel() cancelled();if cancel then return cancel(self) end end
        function action:perform()
            r.performed=true
            if r.result then r.closed=true;if records[actor]==r then records[actor]=nil end end
            if perform then return perform(self) end
        end
        function action:complete() return false end -- only server/native completion is authoritative
        return action
    end)
    api.class=class
    function api.busy(actor) return records[actor]~=nil end
    function api.cancel(actor)
        local r=records[actor];if not r then return false end
        r.closed=true;records[actor]=nil
        wire.send(actor,'cancel',{protocol=Action.protocol,operation=r.operation})
        if r.action and r.action.forceStop then pcall(r.action.forceStop,r.action) end
        return true
    end
    local function queueOffer(actor,r)
        local ok,action=pcall(class.new,class,actor,r.operation,r.phase,r.grant)
        if ok and not action then return true end -- wait for native inventory/world replication
        if not ok then
            wire.send(actor,'cancel',{protocol=Action.protocol,operation=r.operation});records[actor]=nil;return false
        end
        local queued=pcall(wire.queue,action)
        if not queued then action:forceCancel();return false end
        return true
    end
    function api.request(actor,operation,phase)
        if records[actor] or not wire.idle(actor) or not Action.token(operation) or not Action.phase(phase) then return false end
        local request=wire.id()
        if not Action.token(request) then return false end
        records[actor]={operation=operation,phase=phase,request=request,created=wire.now()}
        wire.send(actor,'next',{protocol=Action.protocol,operation=operation,phase=phase,request=request})
        return true
    end
    function api.message(command,args)
        if type(args)~='table' or args.protocol~=Action.protocol or not Action.token(args.operation) then return false end
        local actor,r
        for a,v in pairs(records) do if v.operation==args.operation then actor=a;r=v;break end end
        if not r or r.closed or args.phase~=r.phase then return false end
        if command=='offer' then
            if r.offer then return args.grant==r.grant and args.request==r.request end
            if args.request~=r.request or not Action.token(args.grant) or not wire.idle(actor) then return false end
            r.offer=args;r.grant=args.grant
            r.offerAt=wire.now()
            return queueOffer(actor,r)
        end
        if args.grant~=r.grant then return false end
        if command=='challenge' then
            if not Action.token(args.challenge) or r.challenge and r.challenge~=args.challenge then return false end
            r.challenge=args.challenge;if r.confirm then r.confirm() end;return true
        end
        if command=='result' then
            r.result={status=args.status,reason=args.reason,nextPhase=args.nextPhase}
            if r.performed then r.closed=true;records[actor]=nil end
            return true -- never calls perform/forceComplete or queues the next phase
        end
        return false
    end
    function api.tick()
        for actor,r in pairs(records) do
            if r.offer and not r.action and wire.now()-r.offerAt<5000 and wire.idle(actor) then queueOffer(actor,r) end
            if wire.now()-r.created>=120000 or r.offer and not r.action and wire.now()-r.offerAt>=5000 then
                r.closed=true;records[actor]=nil
                wire.send(actor,'cancel',{protocol=Action.protocol,operation=r.operation})
            end
        end
    end
    function api.close()
        for actor,r in pairs(records) do
            r.closed=true;wire.send(actor,'cancel',{protocol=Action.protocol,operation=r.operation});records[actor]=nil
        end
    end
    return api
end
return C
