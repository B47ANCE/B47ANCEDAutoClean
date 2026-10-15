-- Network/engine scheduling is simulated. Native Lua mutations are real callbacks.
local Server=require 'research/auto-clean/ServerTransport'
local Client=require 'research/auto-clean/ClientTransport'
local Action=require 'research/auto-clean/NativeAction'
local Wire=require 'research/auto-clean/NativeWire'
local cases=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));cases=cases+1 end
local function approx(a,b) assert(math.abs(a-b)<0.00002,tostring(a)..' ~= '..tostring(b)) end
local function fixture()
    local f=AUTO_CLEAN_FIXTURE();f:begin()
    local outbound={}
    f.server=Server.new(f.poc,f.port,{
        send=function(actor,command,args) outbound[#outbound+1]={actor=actor,command=command,args=args} end,
        describe=function(a,phase) f.prepared=a;return {fixture=true} end,
    })
    f.outbound=outbound
    function f:command(command,args,actor)
        return self.server.command(Server.module,command,actor or self.actor,args)
    end
    function f:offer(phase,request)
        phase=phase or self.poc.status(self.actor,self.id).phase
        local args={protocol=1,operation=self.id,phase=phase,request=request or 'request-1'}
        assert(self:command('next',args));self.offerArgs=args
        self.offerMessage=outbound[#outbound].args;return self.offerMessage
    end
    function f:reconstruct(o)
        o=o or self.offerMessage
        local a=self.server.class:new(self.actor,o.operation,o.phase,o.grant)
        assert(a and a==self.prepared);self.a=a
        a.netAction={getProgress=function() return a.progress or 0 end};return a
    end
    function f:start() assert(self.a:serverStart());self.challenge=outbound[#outbound].args.challenge end
    function f:confirmation()
        local o=self.offerMessage
        return {protocol=1,operation=self.id,phase=o.phase,grant=o.grant,challenge=self.challenge}
    end
    function f:confirm() return self:command('confirm',self:confirmation()) end
    function f:stage()
        self:offer();local a=self:reconstruct();self:start();assert(self:confirm());a.progress=1;assert(a:complete());return a
    end
    return f
end
check('load is inert and class prototype exposes exactly four protocol fields',function()
    assert(rawget(_G,Action.name)==nil and Events==nil)
    local class=Action.class(function() end)
    local info=debug.getinfo(class.new,'u');assert(info.nups==1)
    assert(Action.name~=ISCleanBlood.Type)
end)
check('retained native actions survive constructor-only reconstruction for full recipe',function()
    local f=fixture()
    local c,t,w=ISCleanBlood.complete,ISFluidTransferAction.complete,ISTakeWaterAction.transferFluid
    local bleach=f:stage();approx(f.bucket.fc.bleach,0.01)
    assert(f.outbound[#f.outbound].args.reason==nil and f.outbound[#f.outbound].args.nextPhase=='water')
    assert(getmetatable(bleach)==f.server.class and rawget(bleach,'complete') and rawget(bleach,'isValid'))
    assert(bleach.amount==0.01 and bleach.sourceFluidObject==f.bleach.fc and bleach.targetFluidObject==f.bucket.fc)
    assert(rawget(bleach,'getDuration') and rawget(bleach,'adjustMaxTime') and rawget(bleach,'isUsingTimeout') and rawget(bleach,'stop'))
    assert(bleach:getDuration()==bleach.maxTime and bleach:isUsingTimeout())
    local water=f:stage();approx(f.bucket.fc:getAmount(),10);assert(water.netAction.events==1)
    local clean=f:stage();assert(f.target.cleans==1 and not f.target.blood)
    assert(f.poc.status(f.actor,f.id).status=='done' and #f.poc.status(f.actor,f.id).steps==3)
    assert(ISCleanBlood.complete==c and ISFluidTransferAction.complete==t and ISTakeWaterAction.transferFluid==w)
    assert(not clean:complete() and not bleach:complete() and f.target.cleans==1)
    AUTO_CLEAN_TRANSPORT_RESULT=f.poc.status(f.actor,f.id)
end)
check('foreign authenticated sender cannot confirm even knowing every field',function()
    local f=fixture();f:offer();f:reconstruct();f:start()
    local other={};f.players[#f.players+1]=other;function other:isDead() return false end
    assert(not f:command('confirm',f:confirmation(),other))
    assert(not f.a:update());assert(f.bucket.fc:getAmount()==0)
    assert(f:confirm());assert(f.a:complete());approx(f.bucket.fc.bleach,0.01)
end)
check('constructor character spoof alone cannot authorize mutation',function()
    local f=fixture();f:offer();local a=f:reconstruct();f:start()
    -- Models native PlayerID global-map fallback resolving the victim character.
    -- A server challenge targets that victim; there is no bound client's active action.
    assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
    assert(f.poc.status(f.actor,f.id).status=='cancelled')
end)
check('normal and minus-one client-command indexes stay on actual connection',function()
    local victim,attacker={},{}
    local function received(connection,index)
        if index>=0 and index<4 then return connection[index+1] end
        if index==-1 then for i=1,4 do if connection[i] then return connection[i] end end end
    end
    assert(received({attacker},0)==attacker and received({attacker},-1)==attacker)
    assert(received({attacker},-1)~=victim and received({attacker},4)==nil and received({attacker},-2)==nil)
end)
check('unknown mismatched and duplicate constructors fail before native start',function()
    local f=fixture();local o=f:offer()
    assert(not f.server.class:new({},o.operation,o.phase,o.grant))
    assert(not f.server.class:new(f.actor,o.operation,'water',o.grant))
    assert(not f.server.class:new(f.actor,o.operation,o.phase,'missing'))
    local a=f:reconstruct();assert(not f.server.class:new(f.actor,o.operation,o.phase,o.grant))
    assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
end)
check('repeated next request resends one grant and altered request is refused',function()
    local f=fixture();local o=f:offer();assert(f:command('next',f.offerArgs))
    assert(f.outbound[#f.outbound].args.grant==o.grant)
    assert(not f:command('next',{protocol=1,operation=f.id,phase='bleach',request='different'}))
    f:reconstruct();assert(not f:command('next',f.offerArgs))
end)
check('server-start replay and confirm replay never repeat native start',function()
    local f=fixture();f:stage();f:offer();local a=f:reconstruct();f:start();assert(not a:serverStart())
    assert(f:confirm());assert(f:confirm());assert(a.netAction.events==1)
    a.progress=1;assert(a:complete());assert(not f:confirm())
end)
check('confirmation before reconstruction or challenge is rejected',function()
    local f=fixture();f:offer();f.challenge='invented';assert(not f:confirm());f:reconstruct();assert(not f:confirm())
    assert(not f.a:update());assert(f.bucket.fc:getAmount()==0)
end)
check('accounting fields remain guarded after reconstruction',function()
    local f=fixture();f:offer();local a=f:reconstruct();f:start();assert(f:confirm());a.amount=1
    assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
end)
check('water animation and direct transfer cannot bypass confirmation',function()
    local f=fixture();f:stage();f:offer();local a=f:reconstruct();f:start()
    a.progress=0.5;a:animEvent('takeFluid','');assert(not a:transferFluid(2))
    approx(f.bucket.fc:getAmount(),0.01);assert(not a:complete());approx(f.bucket.fc:getAmount(),0.01)
end)
check('changed permissions before confirmed native start prevent mutation',function()
    local f=fixture();f:offer();f:reconstruct();f:start();f.target.denied=true
    assert(not f:confirm());assert(not f.a:complete());assert(f.bucket.fc:getAmount()==0)
end)
check('malformed payload cannot supply actor resources amounts clocks or callbacks',function()
    local f=fixture()
    for _,k in ipairs({'player','actor','bucket','amount','maxTime','complete','source'}) do
        local args={protocol=1,operation=f.id,phase='bleach',request='r'};args[k]=f.actor
        assert(not f:command('next',args))
    end
    assert(not f:command('next',{protocol=1,operation=f.id,phase='clean',request='r'}))
    assert(not f:command('next',{protocol=1,operation=f.id,phase='bleach',request=string.rep('x',81)}))
    assert(not f:command('begin',{protocol=1,operation=f.id}))
    f:offer();f:reconstruct();f:start();assert(f:confirm())
end)
check('native clock and confirmation timeout fail closed',function()
    for _,progress in ipairs({-1,1,math.huge,0/0}) do
        local f=fixture();f:offer();local a=f:reconstruct();f:start();a.progress=progress
        assert(not f:confirm());assert(f.bucket.fc:getAmount()==0)
    end
    local f=fixture();f:offer();f:reconstruct();f:start();NOW=5000;assert(not f:confirm())
    assert(f.bucket.fc:getAmount()==0)
end)
check('expiry disconnect restart and cancellation revoke retained callbacks',function()
    local f=fixture();f:offer();local a=f:reconstruct();f:start();NOW=5000;f.server.tick()
    assert(not a:complete() and not f:confirm());assert(f.bucket.fc:getAmount()==0)
    f=fixture();f:offer();a=f:reconstruct();f:start();assert(f:confirm());f.players[1]=nil;f.server.tick()
    assert(not a:complete());assert(f.bucket.fc:getAmount()==0)
    f=fixture();local o=f:offer();local fresh=Server.new(f.poc,f.port,{})
    assert(not fresh.class:new(f.actor,o.operation,o.phase,o.grant));f.server.close()
    assert(not f.server.class:new(f.actor,o.operation,o.phase,o.grant))
end)
check('sender cannot cancel or inspect another actor operation',function()
    local f=fixture();f:offer();local other={};function other:isDead() return false end;f.players[2]=other
    assert(not f:command('cancel',{protocol=1,operation=f.id},other))
    assert(not f:command('status',{protocol=1,operation=f.id},other))
    f:reconstruct();f:start();assert(f:confirm());assert(f.a:complete())
end)
check('valid request budget is bounded and resets',function()
    local f=fixture();local args={protocol=1,operation=f.id}
    for _=1,16 do assert(f:command('status',args)) end
    local ok,why=f:command('status',args);assert(not ok and why=='rateLimited')
    NOW=1000;assert(f:command('status',args))
end)
check('native partial failure stays uncertain and cannot replay after transport retirement',function()
    local f=fixture();f:stage();f:offer();local a=f:reconstruct();f:start();assert(f:confirm())
    local transfer=f.water.transferFluidTo
    f.water.transferFluidTo=function(s,to,n) transfer(s,to,n/2);error('simulated native failure') end
    assert(not a:complete());local total=f.bucket.fc:getAmount();assert(total>0.01 and total<10)
    assert(f.poc.status(f.actor,f.id).status=='uncertain');assert(not a:complete());assert(f.bucket.fc:getAmount()==total)
end)
check('client challenge waits for actual local start and never completes locally',function()
    local f=fixture();local sent,queued={},{ }
    local originalStart,originalPerform=ISFluidTransferAction.start,ISBaseTimedAction.perform
    -- Presentation APIs only are simulated; server native mutation callbacks remain original.
    ISFluidTransferAction.start=function(self) self.presentation=true end
    ISBaseTimedAction.perform=function(self) self.localQueueFinished=true end
    local client=Client.new({id=getRandomUUID,now=getTimestampMs,idle=function() return true end,
        queue=function(a) queued[#queued+1]=a end,
        send=function(actor,command,args) sent[#sent+1]={actor=actor,command=command,args=args} end,
        resolve=function(actor)
            SERVER=false;CLIENT=true
            local a=ISFluidTransferAction:new(actor,ISFluidContainer:new(f.bleach.fc),f.bleach.fc,ISFluidContainer:new(f.bucket.fc),f.bucket.fc,0.01)
            SERVER=true;CLIENT=false;return a
        end})
    assert(client.request(f.actor,f.id,'bleach'))
    assert(f:command(sent[1].command,sent[1].args));local offer=f.outbound[#f.outbound].args
    assert(client.message('offer',offer));local ca=queued[1];assert(ca and ca~=f.a)
    assert(client.message('offer',offer) and #queued==1)
    f.offerMessage=offer;local a=f:reconstruct(offer);f:start();local challenge=f.outbound[#f.outbound].args
    assert(client.message('challenge',challenge));assert(#sent==1 and not ca:complete())
    SERVER=false;CLIENT=true;ca:start();SERVER=true;CLIENT=false
    assert(ca.presentation and #sent==2 and sent[2].actor==f.actor and sent[2].command=='confirm')
    assert(f:command(sent[2].command,sent[2].args));assert(a:complete())
    local result=f.outbound[#f.outbound].args;assert(client.message('result',result))
    assert(not ca.localQueueFinished and not client.request(f.actor,f.id,'water'))
    ca:perform();assert(ca.localQueueFinished and client.request(f.actor,f.id,'water'))
    ISFluidTransferAction.start=originalStart;ISBaseTimedAction.perform=originalPerform
end)
check('client cannot queue while busy or accept unsolicited offers and challenges',function()
    local f=fixture();local sent=0
    local c=Client.new({idle=function() return false end,id=getRandomUUID,now=getTimestampMs,send=function() sent=sent+1 end})
    assert(not c.request(f.actor,f.id,'bleach'));assert(not c.message('offer',{protocol=1,operation=f.id,phase='bleach',grant='x'}));assert(sent==0)
    c=Client.new({idle=function() return true end,id=getRandomUUID,now=getTimestampMs,send=function() sent=sent+1 end})
    assert(c.request(f.actor,f.id,'bleach'));assert(not c.message('challenge',{protocol=1,operation=f.id,phase='bleach',grant='x',challenge='y'}))
    NOW=120000;c.tick();assert(c.request(f.actor,f.id,'bleach'))
end)
check('explicit native wire installation owns only its hooks and class',function()
    local f=fixture();local count=0
    local function event() local e={handlers={}};function e.Add(fn) assert(not e.handlers[fn]);e.handlers[fn]=true;count=count+1 end
        function e.Remove(fn) assert(e.handlers[fn]);e.handlers[fn]=nil;count=count-1 end;return e end
    Events={OnTick=event(),OnClientCommand=event(),OnServerCommand=event()}
    local api=assert(Wire.server(f.poc,f.port));assert(count==2 and _G[Action.name]==api.class)
    assert(not Wire.server(f.poc,f.port));assert(count==2)
    api.uninstall();api.uninstall();assert(count==0 and rawget(_G,Action.name)==nil)
    Events=nil
end)
check('native server wire emits targeted scalar descriptors through its actual command hook',function()
    local f=fixture();local messages={}
    local function event() return {Add=function() end,Remove=function() end} end
    Events={OnTick=event(),OnClientCommand=event()}
    sendServerCommand=function(actor,module,command,args)
        assert(actor==f.actor and module==Server.module);messages[#messages+1]={command=command,args=args}
    end
    local api=assert(Wire.server(f.poc,f.port))
    assert(api.command(Server.module,'next',f.actor,{protocol=1,operation=f.id,phase='bleach',request='wire-request'}))
    local offer=messages[#messages].args
    assert(offer.view.source==2 and offer.view.bucket==1 and offer.view.amount==nil)
    local a=api.class:new(f.actor,f.id,'bleach',offer.grant)
    a.netAction={getProgress=function() return 0 end};assert(a:serverStart())
    local challenge=messages[#messages].args.challenge
    assert(api.command(Server.module,'confirm',f.actor,{protocol=1,operation=f.id,phase='bleach',grant=offer.grant,challenge=challenge}))
    assert(a:complete());approx(f.bucket.fc.bleach,0.01)
    api.uninstall();Events=nil;sendServerCommand=nil
end)
check('native client wire resolves all three native presentations and sends actor-bound intent',function()
    local f=fixture();local sent,queued={},{}
    local function event() return {Add=function() end,Remove=function() end} end
    Events={OnTick=event(),OnServerCommand=event()}
    local queue={queue={}}
    ISTimedActionQueue={getTimedActionQueue=function(actor) assert(actor==f.actor);return queue end,
        add=function(a) queued[#queued+1]=a;queue.queue={a} end}
    package.loaded['TimedActions/ISTimedActionQueue']=true
    sendClientCommand=function(actor,module,command,args)
        assert(actor==f.actor and module==Server.module);sent[#sent+1]={command=command,args=args}
    end
    local sq=f.water:getSquare();function sq:getObjects() return {size=function() return 1 end,get=function(_,i) assert(i==0);return f.water end} end
    for _,phase in ipairs({'bleach','water','clean'}) do
        SERVER=false;CLIENT=true
        local api=assert(Wire.client());queue.queue={}
        assert(api.request(f.actor,f.id,phase));local request=sent[#sent].args.request
        local view={bucket=1,source=2,water={x=10,y=11,z=0},index=0,target={x=10,y=10,z=0}}
        assert(api.message('offer',{protocol=1,operation=f.id,phase=phase,grant='native-grant',request=request,view=view}))
        local a=queued[#queued];assert(a.character==f.actor and getmetatable(a)==api.class)
        assert(rawget(a,'isUsingTimeout') and rawget(a,'getDuration'))
        if phase=='bleach' then assert(a.amount==0.01 and a.sourceFluidObject==f.bleach.fc)
        elseif phase=='water' then assert(a.item==f.bucket and a.waterObject==f.water)
        else assert(a.cleaner==f.bucket and a.square==f.target) end
        assert(not a:complete() and f.bucket.fc:getAmount()==0 and f.target.cleans==0)
        api.uninstall()
        assert(sent[#sent].command=='cancel' and rawget(_G,Action.name)==nil)
    end
    SERVER=true;CLIENT=false;Events=nil;sendClientCommand=nil;ISTimedActionQueue=nil
end)
print('PASS OFFLINE Auto Clean native transport: '..cases..' scenario groups; simulated network/reconstruction/clock')
return cases
