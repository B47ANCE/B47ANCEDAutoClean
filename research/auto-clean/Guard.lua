-- Isolated server-owned POC state. No events, networking, persistence or world writes.
local G = {}
local phases = {bleach='water', water='clean', clean='done'}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function copy(t)
    if type(t)~='table' then return t end
    local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function G.new(port)
    local runs,owners,locks,history={},{},{},{}
    -- Technical admission/retention limits for this inert test fixture, not gameplay settings.
    local maxActive,retained,lifetime=4,32,120000
    local function server() return port.server()==true end
    local function release(op)
        if owners[op.actor]==op then owners[op.actor]=nil end
        for _,key in ipairs(op.keys) do if locks[key]==op then locks[key]=nil end end
    end
    local function close(op,status,reason)
        if op.closed then return false end
        op.closed=true;op.status=status;op.reason=reason;release(op)
        op.context=nil;op.action=nil;op.keys=nil -- receipts keep numbers, not retained world handles
        history[#history+1]=op.id
        if #history>retained then local old=table.remove(history,1);runs[old]=nil end
        return false,reason
    end
    local function find(actor,id)
        if not server() then return nil,'notServer' end
        local op=type(id)=='string' and runs[id]
        if not op or op.actor~=actor then return nil,'notOwned' end
        if op.closed then return nil,'closed' end
        if port.now()-op.time>=lifetime then close(op,'cancelled','expired');return nil,'expired' end
        return op
    end
    local function live(op)
        local ok,state=pcall(port.inspect,op.context,op.phase)
        if not ok or not state then return nil,'currentStateInvalid' end
        if not same(state,op.expected) then return nil,'stateChanged' end
        if not state.blood then return nil,'targetClean' end
        return state
    end
    local function evidence(op,before,after,kind)
        -- Subtracting two large float readings loses more precision than a small delta.
        -- Bound by the original measured operands as well as the resulting delta.
        local bound=0
        for _,s in ipairs({before.bucket,before.bleach,before.water,after.bucket,after.bleach,after.water}) do
            for _,n in pairs(s) do bound=math.max(bound,port.tolerance(n,n)) end
        end
        local near=function(a,b) return math.abs(a-b)<=math.max(bound,port.tolerance(a,b)) end
        local b,a=before.bucket,after.bucket
        if kind=='bleach' then
            local moved=a.bleach-b.bleach
            if moved<0 or a.water~=b.water or not same(before.water,after.water)
                or not near(a.total-b.total,moved)
                or not near(before.bleach.bleach-after.bleach.bleach,moved)
                or not near(before.bleach.total-after.bleach.total,moved)
                or a.bleach>op.doseGoal+port.tolerance(a.bleach,op.doseGoal)
                or before.blood~=after.blood or before.grime~=after.grime then return false end
        elseif kind=='water' then
            local moved=a.water-b.water
            if moved<0 or a.bleach~=b.bleach or not same(before.bleach,after.bleach)
                or not near(a.total-b.total,moved)
                or not near(before.water.water-after.water.water,moved)
                or not near(before.water.total-after.water.total,moved)
                or a.total>a.capacity+port.tolerance(a.total,a.capacity)
                or before.blood~=after.blood or before.grime~=after.grime then return false end
        else
            local used=port.cleanAmount()
            local ratio=(b.total-used)/b.total
            if not finite(used) or used<=0 or b.total<used or after.blood or after.grime
                or not same(before.bleach,after.bleach) or not same(before.water,after.water)
                or not near(b.total-a.total,used) or not near(a.bleach,b.bleach*ratio)
                or not near(a.water,b.water*ratio) then return false end
        end
        return true
    end
    local api={}
    function api.begin(actor,selection)
        if not server() then return nil,'notServer' end
        if owners[actor] then return nil,'busy' end
        local n=0;for _ in pairs(owners) do n=n+1 end;if n>=maxActive then return nil,'busy' end
        local ok,context,keys=pcall(port.bind,actor,selection)
        if not ok or not context then return nil,'invalidSelection' end
        local phase=port.initialPhase and port.initialPhase(context) or 'bleach'
        local valid,state=pcall(port.inspect,context,phase)
        if not valid or not state or not state.blood then return nil,'invalidInitialState' end
        if port.initialAllowed then
            if not port.initialAllowed(context,state) then return nil,'invalidInitialState' end
        elseif state.bucket.total~=0 then return nil,'invalidInitialState' end
        if type(keys)~='table' or #keys<5 or #keys>600 then return nil,'invalidClaims' end
        for _,key in ipairs(keys) do if locks[key] then return nil,'resourceBusy' end end
        local id=port.id()
        if type(id)~='string' or #id<1 or runs[id] then return nil,'invalidID' end
        local dose=port.doseFor and port.doseFor(context) or port.dose
        local op={id=id,actor=actor,context=context,keys=keys,phase=phase,status='ready',doseGoal=state.bucket.bleach+dose,
            time=port.now(),initial=copy(state),expected=copy(state),steps={},mutations=0}
        runs[id]=op;owners[actor]=op
        for _,key in ipairs(keys) do locks[key]=op end
        return id
    end
    function api.attach(actor,id,action)
        local op,reason=find(actor,id);if not op then return false,reason end
        if op.action then return false,'alreadyAttached' end
        local state=live(op);if not state then return close(op,'cancelled','stateChanged') end
        if not port.actionMatches(op.context,op.phase,action) then return false,'wrongAction' end
        op.action=action;op.stageStart=copy(state);return true
    end
    local function authorized(actor,id,action)
        local op,reason=find(actor,id);if not op then return nil,reason end
        if op.action~=action or op.busy then return nil,'wrongAction' end
        if not port.actionMatches(op.context,op.phase,action) then close(op,'cancelled','actionChanged');return nil,'actionChanged' end
        local state,why=live(op)
        if not state then close(op,'cancelled',why);return nil,why end
        return op,state
    end
    function api.start(actor,id,action)
        local op,why=authorized(actor,id,action);if not op then return false,why end
        if op.started then return false,'alreadyStarted' end
        op.started=true;op.status='running';return true
    end
    function api.mutate(actor,id,action,callback)
        local op,before=authorized(actor,id,action);if not op then return false,before end
        if not op.started then return false,'notStarted' end
        local checked,allowed=pcall(port.canMutate,op.context,op.phase,action)
        if not checked or allowed~=true then return close(op,'cancelled','nativeValidationChanged') end
        if op.mutations>=4096 then return close(op,'cancelled','mutationLimit') end
        op.busy=true -- set before native callback; reentry cannot invoke it twice
        local ok,result=pcall(callback)
        local observed,after=pcall(port.inspect,op.context,op.phase)
        op.busy=false;op.mutations=op.mutations+1
        if observed and after then op.observed=copy(after) end
        if not ok or result==false or not observed or not after or not evidence(op,before,after,op.phase) then
            return close(op,'uncertain','nativeOutcomeUncertain')
        end
        op.expected=copy(after)
        return true,result
    end
    function api.complete(actor,id,action,callback)
        local op,why=authorized(actor,id,action);if not op then return false,why end
        if not op.started or op.completing then return false,'notCompletable' end
        op.completing=true
        local ok,result
        if op.phase=='water' then
            -- Its original complete invokes the separately guarded transferFluid method.
            ok,result=pcall(callback)
        else
            ok,result=api.mutate(actor,id,action,callback)
        end
        op.completing=false
        if op.closed then return false,op.reason end
        if not ok or result~=true then return close(op,'uncertain','nativeCompletionFailed') end
        local state=op.expected
        if op.phase=='bleach' and math.abs(state.bucket.bleach-op.doseGoal)>port.tolerance(state.bucket.bleach,op.doseGoal) then
            return close(op,'uncertain','doseIncomplete')
        elseif op.phase=='water' and math.abs(state.bucket.total-state.bucket.capacity)>port.tolerance(state.bucket.total,state.bucket.capacity) then
            return close(op,'uncertain','fillIncomplete')
        end
        op.steps[#op.steps+1]={phase=op.phase,before=copy(op.stageStart),after=copy(state)}
        op.phase=phases[op.phase];op.action=nil;op.started=false;op.status='ready'
        if op.phase=='done' then close(op,'done','nativeStateObserved');return true end
        return true
    end
    function api.cancel(actor,id,reason)
        local op,why=find(actor,id);if not op then return false,why end
        if op.busy or op.completing then return false,'inFlight' end
        local ok,state=pcall(port.measure,op.context)
        if ok and state then op.observed=copy(state) end
        return close(op,'cancelled',reason or 'cancelled')
    end
    function api.status(actor,id)
        if not server() then return nil,'notServer' end
        local op=runs[id];if not op or op.actor~=actor then return nil,'notOwned' end
        return {id=id,phase=op.phase,status=op.status,reason=op.reason,mutations=op.mutations,
            initial=copy(op.initial),latest=copy(op.observed or op.expected),steps=copy(op.steps)}
    end
    function api.prepare(actor,id)
        local op,reason=find(actor,id);if not op then return nil,reason end
        if op.action then return nil,'alreadyAttached' end
        local state=live(op);if not state then close(op,'cancelled','stateChanged');return nil,'stateChanged' end
        return port.makeAction(op.context,op.phase),op.phase
    end
    function api.tick()
        if not server() then return end
        for actor,op in pairs(owners) do
            if not op.busy and not op.completing and (port.now()-op.time>=lifetime or not port.actorValid(actor)) then
                api.cancel(actor,op.id,'expiredOrDisconnected')
            end
        end
    end
    return api
end
return G
