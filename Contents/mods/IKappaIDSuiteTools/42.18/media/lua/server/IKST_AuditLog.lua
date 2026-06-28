-- Server audit log (console + ModData ring buffer).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Args"

IKST_AuditLog = IKST_AuditLog or {}

function IKST_AuditLog.enabled()
    if IKST_Access.sandboxBool then
        return IKST_Access.sandboxBool("AuditLogEnabled", true)
    end
    return true
end

function IKST_AuditLog.maxEntries()
    if IKST_Access.sandboxInt then
        return IKST_Access.sandboxInt("AuditLogMaxEntries", 500, 50, 2000)
    end
    return 500
end

function IKST_AuditLog.store()
    return ModData.getOrCreate("IKST_AuditLog")
end

function IKST_AuditLog.playerMeta(player)
    if not player then
        return "?", nil
    end
    local username = "?"
    if player.getUsername then
        username = player:getUsername() or username
    end
    local onlineId = nil
    if player.getOnlineID then
        onlineId = player:getOnlineID()
    end
    return username, onlineId
end

function IKST_AuditLog.record(player, command, args, ok, reason)
    if not IKST_AuditLog.enabled() then
        return
    end
    local username, onlineId = IKST_AuditLog.playerMeta(player)
    local summary = IKST_Args.summarize(args, command)
    local px, py, pz = nil, nil, nil
    if player and player.getX then
        px = math.floor(player:getX())
        py = math.floor(player:getY())
        pz = player:getZ()
    end
    local entry = {
        t = getTimestampMs and getTimestampMs() or (getTimeInMillis and getTimeInMillis() or 0),
        user = username,
        id = onlineId,
        cmd = tostring(command or "?"),
        args = summary,
        ok = ok == true,
        reason = tostring(reason or ""),
        x = px,
        y = py,
        z = pz,
    }
    local data = IKST_AuditLog.store()
    data.entries = data.entries or {}
    table.insert(data.entries, entry)
    local max = IKST_AuditLog.maxEntries()
    while #data.entries > max do
        table.remove(data.entries, 1)
    end
    local line = string.format(
        "[IKST-AUDIT] %s id=%s cmd=%s ok=%s reason=%s %s @%s,%s,%s",
        entry.user,
        tostring(entry.id or "?"),
        entry.cmd,
        entry.ok and "yes" or "no",
        entry.reason,
        entry.args,
        tostring(entry.x or "?"),
        tostring(entry.y or "?"),
        tostring(entry.z or "?")
    )
    print(line)
end

function IKST_AuditLog.tail(count)
    count = tonumber(count) or 50
    if count < 1 then
        count = 1
    end
    if count > 200 then
        count = 200
    end
    local data = IKST_AuditLog.store()
    local entries = data.entries or {}
    local out = {}
    local start = math.max(1, #entries - count + 1)
    for i = start, #entries do
        out[#out + 1] = entries[i]
    end
    return out
end

function IKST_AuditLog.sendTail(player, count)
    if not player then
        return
    end
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.auditTailResult, {
            entries = IKST_AuditLog.tail(count),
        })
    end
end
