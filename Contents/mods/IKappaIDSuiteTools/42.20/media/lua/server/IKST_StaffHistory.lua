-- Durable staff-facing history rows (extends audit with typed kinds). Server JVM only.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_AuditLog"
require "IKST_Access"

IKST_StaffHistory = IKST_StaffHistory or {}

local KINDS = {
    spawn = true,
    claim = true,
    give = true,
    catch = true,
    unstuck = true,
    event = true,
    help = true,
    blueprint = true,
}

function IKST_StaffHistory.record(player, kind, detail, ok)
    kind = tostring(kind or "misc")
    if not KINDS[kind] then
        kind = "misc"
    end
    if not IKST_AuditLog or type(IKST_AuditLog.record) ~= "function" then
        return
    end
    local args = { kind = kind, detail = tostring(detail or "") }
    IKST_AuditLog.record(player, "history:" .. kind, args, ok ~= false, tostring(detail or ""))
end

function IKST_StaffHistory.tail(count, kindFilter)
    if not IKST_AuditLog or type(IKST_AuditLog.tail) ~= "function" then
        return {}
    end
    local raw = IKST_AuditLog.tail(math.max(count or 50, 50))
    local out = {}
    for i = 1, #raw do
        local e = raw[i]
        if e and type(e.cmd) == "string" and string.find(e.cmd, "^history:") then
            local kind = string.sub(e.cmd, 9)
            if not kindFilter or kindFilter == "" or kindFilter == kind then
                out[#out + 1] = e
            end
        end
    end
    while #out > (count or 40) do
        table.remove(out, 1)
    end
    return out
end
