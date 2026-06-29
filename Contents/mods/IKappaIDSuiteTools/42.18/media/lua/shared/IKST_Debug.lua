-- IKST development debug: tagged console lines on client and server JVMs.
-- Enable via sandbox IKappaIDSuiteTools.DebugLogEnabled (off by default).

require "IKST_Shared"

IKST_Debug = IKST_Debug or {}

IKST_Debug._ring = IKST_Debug._ring or {}
IKST_Debug._maxRing = 300

function IKST_Debug.enabled()
    if IKST_Access and IKST_Access.sandboxBool then
        return IKST_Access.sandboxBool("DebugLogEnabled", false)
    end
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteTools
    return sv and sv.DebugLogEnabled == true
end

function IKST_Debug.verbose()
    if IKST_Access and IKST_Access.sandboxBool then
        return IKST_Access.sandboxBool("DebugLogVerbose", false)
    end
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteTools
    return sv and sv.DebugLogVerbose == true
end

function IKST_Debug.maxRing()
    if IKST_Access and IKST_Access.sandboxInt then
        return IKST_Access.sandboxInt("DebugLogMaxEntries", 300, 50, 1000)
    end
    return IKST_Debug._maxRing
end

function IKST_Debug.jvm()
    if type(isServer) == "function" and isServer()
        and type(isClient) == "function" and isClient() then
        return "listen-host"
    end
    if type(isServer) == "function" and isServer() then
        return "server"
    end
    if type(isClient) == "function" and isClient() then
        return "client"
    end
    return "sp"
end

function IKST_Debug.now()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

function IKST_Debug.playerBrief(player)
    if not player then
        return "?"
    end
    local name = "?"
    if player.getUsername then
        local u = player:getUsername()
        if u and u ~= "" then
            name = u
        end
    end
    local id = "?"
    if player.getOnlineID then
        id = tostring(player:getOnlineID())
    end
    return name .. "#" .. id
end

function IKST_Debug.summarizeArgs(args, command)
    if not args or type(args) ~= "table" then
        return ""
    end
    if not IKST_Args then
        require "IKST_Args"
    end
    if IKST_Args and IKST_Args.summarize then
        return IKST_Args.summarize(args, command)
    end
    return ""
end

function IKST_Debug.remember(line)
    local max = IKST_Debug.maxRing()
    IKST_Debug._ring[#IKST_Debug._ring + 1] = line
    while #IKST_Debug._ring > max do
        table.remove(IKST_Debug._ring, 1)
    end
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and ModData and ModData.getOrCreate then
        local data = ModData.getOrCreate("IKST_DebugLog")
        data.entries = data.entries or {}
        data.entries[#data.entries + 1] = line
        while #data.entries > max do
            table.remove(data.entries, 1)
        end
    end
end

function IKST_Debug.log(tag, msg)
    if not IKST_Debug.enabled() then
        return
    end
    local line = string.format(
        "[IKST-DEBUG][%s][%s] %s",
        IKST_Debug.jvm(),
        tostring(tag),
        tostring(msg)
    )
    print(line)
    IKST_Debug.remember(line)
end

function IKST_Debug.logNet(phase, command, player, args, detail)
    if not IKST_Debug.enabled() then
        return
    end
    local parts = {
        tostring(phase),
        "cmd=" .. tostring(command),
        "user=" .. IKST_Debug.playerBrief(player),
    }
    local argLine = IKST_Debug.summarizeArgs(args, command)
    if argLine ~= "" then
        parts[#parts + 1] = argLine
    end
    if detail and detail ~= "" then
        parts[#parts + 1] = tostring(detail)
    end
    IKST_Debug.log("net", table.concat(parts, " "))
end

function IKST_Debug.logDeny(command, player, reason, args)
    if not IKST_Debug.enabled() then
        return
    end
    IKST_Debug.log("deny", string.format(
        "cmd=%s user=%s reason=%s %s",
        tostring(command),
        IKST_Debug.playerBrief(player),
        tostring(reason or "?"),
        IKST_Debug.summarizeArgs(args, command)
    ))
end

function IKST_Debug.logResult(command, player, ok, msg)
    if not IKST_Debug.enabled() then
        return
    end
    IKST_Debug.log("result", string.format(
        "cmd=%s ok=%s user=%s msg=%s",
        tostring(command),
        ok == true and "yes" or "no",
        IKST_Debug.playerBrief(player),
        tostring(msg or "")
    ))
end

function IKST_Debug.modFlags()
    local flags = {}
    if getActivatedMods then
        local mods = getActivatedMods()
        if mods and mods.contains then
            local ids = {
                "IKappaIDSuiteTools",
                "IKappaIDSuiteToolsTiles",
                "IKappaIDSuiteToolsVehicles",
                "IKappaIDSuiteToolsEconomy",
                "IKappaIDSuiteToolsLoot",
            }
            for i = 1, #ids do
                local id = ids[i]
                flags[#flags + 1] = id .. "=" .. (mods:contains(id) and "on" or "off")
            end
        end
    end
    return table.concat(flags, " ")
end

function IKST_Debug.buildStatus(player)
    local lines = {}
    lines[#lines + 1] = "IKST v" .. tostring(IKST.VERSION) .. " jvm=" .. IKST_Debug.jvm()
    lines[#lines + 1] = "mp=" .. tostring(IKST.isMultiplayerSession and IKST.isMultiplayerSession() or false)
    lines[#lines + 1] = "debug=" .. tostring(IKST_Debug.enabled()) .. " verbose=" .. tostring(IKST_Debug.verbose())
    lines[#lines + 1] = "mods " .. IKST_Debug.modFlags()
    if player then
        lines[#lines + 1] = "you=" .. IKST_Debug.playerBrief(player)
        if player.isGodMod then
            lines[#lines + 1] = "god=" .. tostring(player:isGodMod())
        end
        if player.isInvisible then
            lines[#lines + 1] = "invis=" .. tostring(player:isInvisible())
        end
        if player.isGhostMode then
            lines[#lines + 1] = "ghost=" .. tostring(player:isGhostMode())
        end
    end
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and getOnlinePlayers then
        local list = getOnlinePlayers()
        local n = 0
        if list and list.size then
            n = list:size()
        end
        lines[#lines + 1] = "online=" .. tostring(n)
    end
    return lines
end

function IKST_Debug.localTail(count)
    count = tonumber(count) or 40
    if count < 1 then
        count = 1
    end
    if count > 200 then
        count = 200
    end
    local out = {}
    local ring = IKST_Debug._ring or {}
    local start = math.max(1, #ring - count + 1)
    for i = start, #ring do
        out[#out + 1] = ring[i]
    end
    return out
end

function IKST_Debug.serverTail(count)
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() or not ModData then
        return {}
    end
    count = tonumber(count) or 40
    if count < 1 then
        count = 1
    end
    if count > 200 then
        count = 200
    end
    local data = ModData.getOrCreate("IKST_DebugLog")
    local entries = data.entries or {}
    local out = {}
    local start = math.max(1, #entries - count + 1)
    for i = start, #entries do
        out[#out + 1] = entries[i]
    end
    return out
end

function IKST_Debug.printStatus(player)
    local lines = IKST_Debug.buildStatus(player)
    for i = 1, #lines do
        IKST_Debug.log("status", lines[i])
    end
    return lines
end

function IKST_Debug.pushStatusToPanel(player, lines)
    if not player or not lines or not IKST.pushLog then
        return
    end
    for i = 1, #lines do
        IKST.pushLog(player, lines[i])
    end
end

function IKST_Debug.sendStatus(player)
    if not player then
        return
    end
    local lines = IKST_Debug.buildStatus(player)
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        IKST_Debug.printStatus(player)
    end
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.debugStatusResult, { lines = lines })
    else
        IKST_Debug.pushStatusToPanel(player, lines)
    end
end

function IKST_Debug.sendTail(player, count)
    if not player then
        return
    end
    local payload = {
        server = IKST_Debug.serverTail(count),
        client = IKST_Debug.localTail(count),
    }
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.debugTailResult, payload)
    end
end

function IKST_Debug.onClientStatusResult(player, args)
    if not args or not args.lines then
        return
    end
    if IKST_Debug.enabled() then
        for i = 1, #args.lines do
            IKST_Debug.log("status", args.lines[i])
        end
    end
    IKST_Debug.pushStatusToPanel(player, args.lines)
    if player and IKST.notify then
        IKST.notify(player, "IKST debug status — see panel log + console", true)
    end
end

function IKST_Debug.onClientTailResult(player, args)
    if not args then
        return
    end
    local function pushBlock(label, entries)
        if not entries or #entries == 0 then
            return
        end
        if IKST.pushLog then
            IKST.pushLog(player, "--- " .. label .. " (" .. #entries .. ") ---")
        end
        for i = 1, #entries do
            if IKST.pushLog then
                IKST.pushLog(player, entries[i])
            end
            if IKST_Debug.enabled() then
                print(entries[i])
            end
        end
    end
    pushBlock("server debug", args.server)
    pushBlock("client debug", args.client)
    if player and IKST.notify then
        IKST.notify(player, "IKST debug tail — see panel log + console", true)
    end
end
