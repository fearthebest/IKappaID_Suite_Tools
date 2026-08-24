-- Dashboard snapshot + favorite quick actions (client).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Identity"

IKST_Dashboard = IKST_Dashboard or {}
IKST_Dashboard.snapshot = nil

local function countMirrorEntries(mirror)
    if mirror and type(mirror.countEntries) == "function" then
        return mirror.countEntries() or 0
    end
    return 0
end

local function formatUptime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 1 then
        return "-", ""
    end
    local mins = math.floor(seconds / 60)
    local hrs = math.floor(mins / 60)
    mins = mins % 60
    local value
    if hrs > 0 then
        value = tostring(hrs) .. "h " .. tostring(mins) .. "m"
    else
        value = tostring(mins) .. "m"
    end
    return value, ""
end

function IKST_Dashboard.applyResult(args)
    IKST_Dashboard.snapshot = args or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance and IKST_JobsPanel.instance.refreshJobUI then
        IKST_JobsPanel.instance:refreshJobUI(true)
    end
end

function IKST_Dashboard.buildLocalSnapshot(player)
    local online = 1
    local maxPlayers = 1
    if getServerOptions and getServerOptions() and getServerOptions().getMaxPlayers then
        maxPlayers = tonumber(getServerOptions():getMaxPlayers()) or 1
    end
    local staff = IKST_Access and IKST_Access.canUseStaffTools(player) == true
    local name = "?"
    if player and type(player.getUsername) == "function" then
        name = player:getUsername() or name
    end
    local onlineNames = {}
    local onlineKeys = {}
    if name and name ~= "" and name ~= "?" then
        onlineNames[1] = name
    end
    if player and type(IKST_Identity.accountKey) == "function" then
        local key = IKST_Identity.accountKey(player)
        if key and key ~= "" then
            onlineKeys[1] = key
        end
    end
    return {
        online = online,
        maxPlayers = maxPlayers,
        safehouseClaims = countMirrorEntries(IKST_SafehouseClaimMirror),
        vehicleClaims = countMirrorEntries(IKST_VehicleClaimMirror),
        uptimeSec = 0,
        activeAdmins = staff and 1 or 0,
        adminNames = staff and name or "",
        pendingHelp = 0,
        helpOldestMin = 0,
        staffView = staff,
        onlineNames = onlineNames,
        onlineKeys = staff and onlineKeys or {},
    }
end

function IKST_Dashboard.isClaimOwnerOnline(owner, ownerLabel)
    local snap = IKST_Dashboard.snapshot
    if not snap then
        return false
    end
    local names = snap.onlineNames
    local keys = snap.onlineKeys
    local function nameMatches(candidate)
        if not candidate or candidate == "" or not names then
            return false
        end
        local want = string.lower(tostring(candidate))
        for i = 1, #names do
            if string.lower(tostring(names[i])) == want then
                return true
            end
        end
        return false
    end
    if nameMatches(ownerLabel) or nameMatches(owner) then
        return true
    end
    if owner and owner ~= "" and keys and type(IKST_Identity.keysEqual) == "function" then
        for i = 1, #keys do
            if IKST_Identity.keysEqual(owner, keys[i]) then
                return true
            end
        end
    end
    return false
end

function IKST_Dashboard.request(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    if IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
        IKST_Dashboard.applyResult(IKST_Dashboard.buildLocalSnapshot(player))
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.dashboardSnapshot, {})
end

function IKST_Dashboard.statLines(statId)
    local s = IKST_Dashboard.snapshot
    if not s then
        return "-", IKST.text("IGUI_IKST_Dashboard_Stat_Placeholder", "Tap Refresh")
    end
    if statId == "online" then
        local maxP = tonumber(s.maxPlayers) or 0
        -- Do not put %1 in getText strings - B42 Translator formats it and throws every frame.
        local sub = ""
        if maxP > 0 then
            sub = IKST.text("IGUI_IKST_Dashboard_Stat_OnlineSub", "of") .. " " .. tostring(maxP) .. " "
                .. IKST.text("IGUI_IKST_Dashboard_Stat_OnlineSubMax", "max")
        end
        return tostring(s.online or 0), sub
    end
    if statId == "safehouse" then
        return tostring(s.safehouseClaims or 0), IKST.text("IGUI_IKST_Dashboard_Stat_ClaimsSub", "active")
    end
    if statId == "vehicle" then
        return tostring(s.vehicleClaims or 0), IKST.text("IGUI_IKST_Dashboard_Stat_ClaimsSub", "active")
    end
    if statId == "uptime" then
        local value, sub = formatUptime(s.uptimeSec)
        if s.uptimeSince and s.uptimeSince ~= "" then
            sub = IKST.text("IGUI_IKST_Dashboard_Stat_UptimeSub", "since") .. " " .. tostring(s.uptimeSince)
        end
        return value, sub
    end
    if statId == "admins" then
        if s.staffView ~= true then
            return "-", IKST.text("IGUI_IKST_Dashboard_StaffOnly", "Staff only")
        end
        return tostring(s.activeAdmins or 0), tostring(s.adminNames or "")
    end
    if statId == "help" then
        if s.staffView ~= true then
            return "-", IKST.text("IGUI_IKST_Dashboard_StaffOnly", "Staff only")
        end
        local pending = tonumber(s.pendingHelp) or 0
        local sub = ""
        if pending > 0 and tonumber(s.helpOldestMin) and s.helpOldestMin > 0 then
            sub = IKST.text("IGUI_IKST_Dashboard_Stat_HelpSub", "oldest") .. " "
                .. tostring(s.helpOldestMin) .. IKST.text("IGUI_IKST_Dashboard_Stat_HelpSubMin", "m ago")
        end
        return tostring(pending), sub
    end
    return "-", ""
end

function IKST_Dashboard.runFavoriteAction(panel, action)
    if not panel or not action then
        return false
    end
    local p = panel.player
    if not p then
        return false
    end
    if action == "healSelf" then
        if not IKST_Access.canUseStaffTools(p) then
            IKST.notify(p, IKST.text("IGUI_IKST_Dashboard_StaffOnly", "Staff only"), false)
            return true
        end
        IKST.dispatchCommand(p, IKST.CMD.healSelf, {})
        return true
    end
    if action == "tpHome" then
        if IKST_JobGuard and IKST_JobGuard.safehouses then
            for _, row in ipairs(IKST_JobGuard.safehouses) do
                if row and row.canRelease and row.x and row.y and row.w and row.h then
                    IKST.dispatchCommand(p, IKST.CMD.safehouseTp, {
                        x = row.x, y = row.y, z = row.z or 0, w = row.w, h = row.h,
                    })
                    return true
                end
            end
        end
        IKST.dispatchCommand(p, IKST.CMD.tpWaypoint, { name = "home" })
        return true
    end
    return false
end
