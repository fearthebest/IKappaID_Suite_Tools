if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Arrival"
require "IKST_Chrome"

IKST_ArrivalClient = ISPanel:derive("IKST_ArrivalClient")
IKST_ArrivalClient.instance = nil

function IKST_ArrivalClient:new(player)
    local sw = getCore():getScreenWidth()
    local w, h = 280, 32
    local o = ISPanel:new((sw - w) / 2, 48, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.remainingMs = 0
    o.background = false
    o.moveWithMouse = false
    return o
end

function IKST_ArrivalClient:render()
    if (self.remainingMs or 0) <= 0 then
        return
    end
    local remaining = math.ceil(self.remainingMs / 1000)
    local label = IKST.text("IGUI_IKST_Arrival_HUD", "Arrival stabilization") .. " · " .. remaining .. "s"
    local c = IKST_Chrome.colors
    self:drawRect(0, 0, self.width, self.height, 0.85, c.bgApp.r, c.bgApp.g, c.bgApp.b)
    self:drawRect(0, 0, 3, self.height, 1, c.accent.r, c.accent.g, c.accent.b)
    self:drawText(label, 10, 8, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
end

function IKST_ArrivalClient.ensure()
    if not IKST_Arrival.enabled() then
        return
    end
    local player = getPlayer()
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if not player then
        return
    end
    if not IKST_ArrivalClient.instance then
        IKST_ArrivalClient.instance = IKST_ArrivalClient:new(player)
        IKST_ArrivalClient.instance:initialise()
        IKST_ArrivalClient.instance:addToUIManager()
    end
    IKST_ArrivalClient.instance.player = player
end

function IKST_ArrivalClient.onSync(args)
    if not args then
        return
    end
    if args.active ~= true then
        if IKST_ArrivalClient.instance then
            IKST_ArrivalClient.instance:removeFromUIManager()
            IKST_ArrivalClient.instance = nil
        end
        return
    end
    IKST_ArrivalClient.ensure()
    if IKST_ArrivalClient.instance then
        IKST_ArrivalClient.instance.remainingMs = tonumber(args.remainingMs) or 0
    end
    if args.reason == "started" then
        local player = getPlayer()
        if not player and getSpecificPlayer then
            player = getSpecificPlayer(0)
        end
        local remaining = math.ceil((tonumber(args.remainingMs) or 0) / 1000)
        local label = IKST.text("IGUI_IKST_Arrival_HUD", "Arrival stabilization")
        if remaining > 0 then
            label = label .. " · " .. remaining .. "s"
        end
        if IKST.notify then
            IKST.notify(player, label, true)
        end
    end
end

function IKST_ArrivalClient.onTick()
    if not IKST_ArrivalClient.instance or not IKST_ArrivalClient.instance.remainingMs then
        return
    end
    local step = 33
    if getTimestampMs then
        IKST_ArrivalClient._lastTickMs = IKST_ArrivalClient._lastTickMs or getTimestampMs()
        local now = getTimestampMs()
        step = math.max(0, now - IKST_ArrivalClient._lastTickMs)
        IKST_ArrivalClient._lastTickMs = now
    end
    IKST_ArrivalClient.instance.remainingMs = math.max(0, IKST_ArrivalClient.instance.remainingMs - step)
    if IKST_ArrivalClient.instance.remainingMs <= 0 then
        IKST_ArrivalClient.instance:removeFromUIManager()
        IKST_ArrivalClient.instance = nil
    end
end

if Events and Events.OnTick then
    Events.OnTick.Add(IKST_ArrivalClient.onTick)
end
