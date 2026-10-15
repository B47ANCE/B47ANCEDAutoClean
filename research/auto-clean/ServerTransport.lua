-- Native commands authorize intent; native timed actions still own scheduling/work.
-- No event/class registration at load time. Constructor character is NOT a sender.
local Action=require 'research/auto-clean/NativeAction'
local S={module='B47AutoCleanNativePOC'}
function S.new(poc,port,wire)
    local byActor,byGrant,budgets={},{},{}
    local api={}
    local class
    local function status(l) return poc.status(l.actor,l.operation) end
    local function emit(l,command,args)
        args.protocol=Action.protocol;args.operation=l.operation;args.phase=l.phase;args.grant=l.grant
        return pcall(wire.send,l.actor,command,args)
    end
    local function retire(l)
        l.live=false
        if byActor[l.actor]==l then byActor[l.actor]=nil end
        if byGrant[l.grant]==l then byGrant[l.grant]=nil end
    end
    local function finish(l,reason)
        if not l.live then return false,reason end
        poc.cancel(l.actor,l.operation,reason)
        local r=status(l)
        retire(l)
        emit(l,'result',{status=r and r.status or 'cancelled',reason=reason,nextPhase=r and r.phase})
        return false,reason
    end
    local function live(l)
        if not port.server() or not l.live or not port.actorValid(l.actor) then return false end
        local r=status(l)
        return r and r.phase==l.phase and (r.status=='ready' or r.status=='running')
            and port.now()-l.created<120000
    end
    local function authorized(l)
        if not live(l) then return finish(l,'leaseInvalid') end
        if not l.confirmed then return false,'notConfirmed' end
        return true
    end
    local function reconstruct(character,operation,phase,grant)
        if not port.server() or not Action.token(operation) or not Action.phase(phase) or not Action.token(grant) then return nil end
        local l=byGrant[grant]
        if not l or character~=l.actor or operation~=l.operation or phase~=l.phase or not live(l) then return nil end
        if l.reconstructed or port.now()-l.created>=5000 then return nil end
        l.reconstructed=true
        -- Return the retained server object, including its closure-owned Guard callbacks.
        -- No resource, amount, duration or callback supplied by a client is copied.
        return l.action
    end
    class=Action.class(reconstruct);api.class=class
    local function offer(l)
        local ok,view=pcall(wire.describe,l.action,l.phase)
        if not ok or type(view)~='table' then return finish(l,'descriptionFailed') end
        if not emit(l,'offer',{request=l.request,view=view}) then return finish(l,'sendFailed') end
        return true
    end
    local function prepare(actor,args)
        local old=byActor[actor]
        if old then
            if old.operation==args.operation and old.phase==args.phase and old.request==args.request
                and live(old) and not old.reconstructed then return offer(old) end
            return false,'busy'
        end
        local r=poc.status(actor,args.operation)
        if not r or r.status~='ready' or r.phase~=args.phase then return false,'notReadyOrOwned' end
        local action,phase=poc.next(actor,args.operation)
        if not action then return false,phase end
        local grant=port.id()
        if not Action.token(grant) or byGrant[grant] then poc.cancel(actor,args.operation,'invalidGrant');return false,'invalidGrant' end
        local l={actor=actor,operation=args.operation,phase=phase,grant=grant,action=action,
            request=args.request,created=port.now(),live=true}
        byActor[actor]=l;byGrant[grant]=l
        Action.stamp(action,class,l.operation,l.phase,l.grant)
        local start,complete,update,transfer=action.serverStart,action.complete,action.update,action.transferFluid
        function action:serverStart()
            if self~=l.action or not l.reconstructed or l.started or not live(l) then return false end
            l.started=true;l.challenge=port.id()
            if not Action.token(l.challenge) then return finish(l,'invalidChallenge') end
            if not emit(l,'challenge',{challenge=l.challenge}) then return finish(l,'sendFailed') end
            return true -- native start/time continues; original guarded start waits for sender confirmation
        end
        function action:complete()
            if self~=l.action or not authorized(l) then return finish(l,'completionDenied') end
            local ok,result=pcall(complete,self)
            retire(l)
            if not ok then poc.cancel(l.actor,l.operation,'completionError') end
            local r=status(l)
            emit(l,'result',{status=r and r.status or 'cancelled',reason=r and r.reason or (not ok and 'completionError' or nil),nextPhase=r and r.phase})
            return ok and result==true
        end
        if update then function action:update() if self==l.action and authorized(l) then return update(self) end;return false end end
        if transfer then function action:transferFluid(amount) if self==l.action and authorized(l) then return transfer(self,amount) end;return false end end
        function action:serverStop() return finish(l,'nativeStopped') end
        function action:stop() return finish(l,'nativeStopped') end
        function action:forceCancel() return finish(l,'nativeCancelled') end
        l.start=start -- already guarded by Poc; not exposed in the serialized constructor
        return offer(l)
    end
    local fields={next={protocol=true,operation=true,phase=true,request=true},
        confirm={protocol=true,operation=true,phase=true,grant=true,challenge=true},
        cancel={protocol=true,operation=true},status={protocol=true,operation=true}}
    function api.command(module,command,player,args)
        if module~=S.module or not port.server() or not port.actorValid(player) then return false,'notSender' end
        -- 'player' is exclusively the native OnClientCommand argument. Never args.actor/player.
        local schema=fields[command]
        if not schema or type(args)~='table' then return false,'malformed' end
        local count=0
        for k in pairs(args) do count=count+1;if count>6 or not schema[k] then return false,'malformed' end end
        if args.protocol~=Action.protocol or not Action.token(args.operation) then return false,'malformed' end
        for k in pairs(schema) do if k~='protocol' and not Action.token(args[k]) then return false,'malformed' end end
        if args.phase and not Action.phase(args.phase) then return false,'malformed' end
        -- Bound processing per connected actor; malformed input allocates no budget/state.
        local b=budgets[player]
        if not b or port.now()-b.time>=1000 then b={time=port.now(),count=0};budgets[player]=b end
        b.count=b.count+1;if b.count>16 then return false,'rateLimited' end
        if command=='next' then return prepare(player,args) end
        if command=='status' then
            local r=poc.status(player,args.operation)
            if not r then return false,'notOwned' end
            return pcall(wire.send,player,'status',{protocol=Action.protocol,operation=args.operation,phase=r.phase,status=r.status,reason=r.reason})
        end
        if command=='cancel' then
            local l=byActor[player]
            if l and l.operation==args.operation then return finish(l,'clientCancelled') end
            return poc.cancel(player,args.operation,'clientCancelled')
        end
        local l=byGrant[args.grant]
        if not l or l.actor~=player or l.operation~=args.operation or l.phase~=args.phase then return false,'notOwned' end
        if not live(l) or not l.started or args.challenge~=l.challenge then return false,'challengeMismatch' end
        if l.confirmed then return true end -- no repeated native start/animation registration
        if port.now()-l.created>=5000 then return finish(l,'confirmationExpired') end
        local ok,progress=pcall(function() return l.action.netAction:getProgress() end)
        if not ok or type(progress)~='number' or progress~=progress or progress<0 or progress>=1 then return finish(l,'nativeClockInvalid') end
        -- Authenticated command + fresh instance challenge, never packet character alone.
        l.confirmed=true
        local started,result=pcall(l.start,l.action)
        if not started or result~=true then return finish(l,'guardStartDenied') end
        return true
    end
    function api.tick()
        if not port.server() then return end
        poc.tick()
        for _,l in pairs(byActor) do
            if not live(l) or not l.confirmed and port.now()-l.created>=5000 then finish(l,'expiredOrUnavailable') end
        end
        for actor in pairs(budgets) do if not port.actorValid(actor) then budgets[actor]=nil end end
    end
    function api.close()
        for _,l in pairs(byActor) do finish(l,'transportClosed') end
        budgets={}
    end
    return api
end
return S
