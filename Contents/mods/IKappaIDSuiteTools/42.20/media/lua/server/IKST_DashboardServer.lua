-- Dashboard snapshot for MP (online count, claims, help queue, uptime).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Identity"
require "IKST_ServerPlayers"
require "IKST_HelpQueue"
require "IKST_ClaimRequestQueue"
require "IKST_VehicleClaim"
require "IKST_SafehouseClaim"

IKST_DashboardServer = IKST_DashboardServer or {}
IKST_DashboardServer.MOD_KEY = "IKST_Dashboard"
IKST_DashboardServer.bootMs = IKST_DashboardServer.bootMs or nil

local function nowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

function IKST_DashboardServer.ensureBootTime()
    if IKST_DashboardServer.bootMs and IKST_DashboardServer.bootMs > 0 then
        return
    end
    local data = ModData.getOrCreate(IKST_DashboardServer.MOD_KEY)
    local boot = tonumber(data.bootMs) or 0
    if boot < 1 then
        boot = nowMs()
        data.bootMs = boot
        if ModData.transmit then
            ModData.transmit(IKST_DashboardServer.MOD_KEY)
        end
    end
    IKST_DashboardServer.bootMs = boot
end

function IKST_DashboardServer.countVehicleClaims()
    local data = IKST_VehicleClaim.store()
    local n = 0
    if data.byId then
        for _, entry in pairs(data.byId) do
            if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
                n = n + 1
            end
        end
    end
    return n
end

function IKST_DashboardServer.collectOnlineOwners()
    local onlineNames = {}
    local onlineKeys = {}
    IKST_ServerPlayers.foreachOnlinePlayer(function(p)
        if IKST_ServerPlayers.playerInWorld(p) then
            local name = IKST_ServerPlayers.playerKey(p)
            if name and name ~= "" then
                onlineNames[#onlineNames + 1] = name
            end
            if type(IKST_Identity.accountKey) == "function" then
                local key = IKST_Identity.accountKey(p)
                if key and key ~= "" then
                    onlineKeys[#onlineKeys + 1] = key
                end
            end
        end
    end)
    return onlineNames, onlineKeys
end

function IKST_DashboardServer.countSafehouseClaims()
    local data = IKST_SafehouseClaim.store()
    local n = 0
    if data.byKey then
        for _, entry in pairs(data.byKey) do
            if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
                n = n + 1
            end
        end
    end
    return n
end

function IKST_DashboardServer.buildSnapshot(viewer)
    IKST_DashboardServer.ensureBootTime()

    local online = 0
    IKST_ServerPlayers.foreachOnlinePlayer(function(p)
        if IKST_ServerPlayers.playerInWorld(p) then
            online = online + 1
        end
    end)

    local maxPlayers = 32
    if getServerOptions and getServerOptions() then
        local opts = getServerOptions()
        if type(opts.getMaxPlayers) == "function" then
            maxPlayers = tonumber(opts:getMaxPlayers()) or maxPlayers
        end
    end

    local staffView = IKST_Access.canUseStaffTools(viewer) == true
    local pending = IKST_HelpQueue.list()
    local pendingHelp = #pending
    local helpOldestMin = 0
    if pendingHelp > 0 then
        local now = nowMs()
        local oldest = tonumber(pending[1].t) or 0
        if oldest > 0 and now > oldest then
            helpOldestMin = math.floor((now - oldest) / 60000)
        end
    end

    local pendingClaims = 0
    if IKST_ClaimRequestQueue and type(IKST_ClaimRequestQueue.list) == "function" then
        pendingClaims = #(IKST_ClaimRequestQueue.list() or {})
    end

    local boot = IKST_DashboardServer.bootMs or 0
    local uptimeSec = 0
    if boot > 0 then
        local now = nowMs()
        if now > boot then
            uptimeSec = math.floor((now - boot) / 1000)
        end
    end

    local onlineNames, onlineKeys = IKST_DashboardServer.collectOnlineOwners()

    return {
        online = online,
        maxPlayers = maxPlayers,
        safehouseClaims = IKST_DashboardServer.countSafehouseClaims(),
        vehicleClaims = IKST_DashboardServer.countVehicleClaims(),
        uptimeSec = uptimeSec,
        uptimeSince = "",
        pendingHelp = staffView and pendingHelp or 0,
        pendingClaimRequests = staffView and pendingClaims or 0,
        helpOldestMin = staffView and helpOldestMin or 0,
        staffView = staffView,
        onlineNames = onlineNames,
        onlineKeys = staffView and onlineKeys or {},
    }
end

function IKST_DashboardServer.sendSnapshot(player)
    if not player then
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.dashboardSnapshotResult,
        IKST_DashboardServer.buildSnapshot(player))
end

if Events and Events.OnServerStarted and Events.OnServerStarted.Add then
    Events.OnServerStarted.Add(function()
        IKST_DashboardServer.ensureBootTime()
    end)
end
