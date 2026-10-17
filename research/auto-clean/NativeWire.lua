-- Inert native binding. Explicit install only; NOT under media/lua or packaged src.
local Action=require 'research/auto-clean/NativeAction'
local Server=require 'research/auto-clean/ServerTransport'
local Client=require 'research/auto-clean/ClientTransport'
local W={}
local function xyz(s) return {x=s:getX(),y=s:getY(),z=s:getZ()} end
local function square(p)
    if type(p)~='table' then return nil end
    for _,k in ipairs({'x','y','z'}) do
        local n=p[k];if type(n)~='number' or n~=n or math.abs(n)>1000000 or n~=math.floor(n) then return nil end
    end
    return getCell():getGridSquare(p.x,p.y,p.z)
end
local function register(api,event,handler)
    if rawget(_G,Action.name)~=nil then return nil,'classAlreadyRegistered' end
    _G[Action.name]=api.class
    event.Add(handler);Events.OnTick.Add(api.tick)
    local closed=false
    return function()
        if closed then return end;closed=true
        event.Remove(handler);Events.OnTick.Remove(api.tick);api.close()
        if rawget(_G,Action.name)==api.class then _G[Action.name]=nil end
    end
end
function W.server(poc,port,extra)
    if not port.server() then return nil,'notServer' end
    local api=Server.new(poc,port,{
        send=function(actor,command,args) sendServerCommand(actor,Server.module,command,args) end,
        describe=function(a,phase)
            if extra and extra.describe then local view=extra.describe(a,phase);if view then return view end end
            if phase=='bleach' then return {source=a.source:getOwner():getID(),bucket=a.target:getOwner():getID(),dose=a.amount} end
            if phase=='water' then return {bucket=a.item:getID(),water=xyz(a.waterObject:getSquare()),index=a.waterObject:getObjectIndex()} end
            return {bucket=a.cleaner:getID(),target=xyz(a.square)}
        end,
    })
    local uninstall,why=register(api,Events.OnClientCommand,api.command)
    if not uninstall then return nil,why end
    api.uninstall=uninstall;return api
end
function W.client(extra)
    if not isClient() or isServer() then return nil,'notClient' end
    require 'TimedActions/ISTimedActionQueue'
    require 'Fluids/ISFluidContainer'
    require 'Fluids/ISFluidUtil'
    require 'Fluids/ISFluidTransferAction'
    require 'TimedActions/ISTakeWaterAction'
    require 'TimedActions/ISCleanBlood'
    local api=Client.new({
        id=getRandomUUID,now=getTimestampMs,
        send=function(actor,command,args) sendClientCommand(actor,Server.module,command,args) end,
        idle=function(actor) return #ISTimedActionQueue.getTimedActionQueue(actor).queue==0 end,
        queue=function(action) ISTimedActionQueue.add(action) end,
        resolve=function(actor,view,phase)
            if extra and extra.resolve then local a=extra.resolve(actor,view,phase);if a then return a end end
            if type(view)~='table' or type(view.bucket)~='number' then return nil end
            local inv=actor:getInventory();local bucket=inv:getItemWithIDRecursiv(view.bucket)
            if not bucket or not bucket:getFluidContainer() then return nil end
            if phase=='bleach' then
                if type(view.source)~='number' then return nil end
                local source=inv:getItemWithIDRecursiv(view.source)
                if not source or not source:getFluidContainer() then return nil end
                local dose=view.dose or 0.01
                if type(dose)~='number' or dose~=dose or dose<=0 or dose>0.1 then return nil end
                return ISFluidTransferAction:new(actor,ISFluidContainer:new(source:getFluidContainer()),source:getFluidContainer(),
                    ISFluidContainer:new(bucket:getFluidContainer()),bucket:getFluidContainer(),dose)
            elseif phase=='water' then
                local sq=square(view.water);local index=view.index
                if not sq or type(index)~='number' or index~=math.floor(index) or index<0 or index>=sq:getObjects():size() then return nil end
                local water=sq:getObjects():get(index)
                if not water or not water:getFluidContainer() then return nil end
                return ISTakeWaterAction:new(actor,bucket,water,false)
            elseif phase=='clean' then
                local target=square(view.target);if not target then return nil end
                return ISCleanBlood:new(actor,target,bucket)
            end
        end,
    })
    local function handler(module,command,args) if module==Server.module then return api.message(command,args) end end
    local uninstall,why=register(api,Events.OnServerCommand,handler)
    if not uninstall then return nil,why end
    api.uninstall=uninstall;return api
end
return W
