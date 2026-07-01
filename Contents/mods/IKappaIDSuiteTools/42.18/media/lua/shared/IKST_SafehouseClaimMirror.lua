-- Client mirror for server-authoritative safehouse claim ModData (MP).

require "IKST_Shared"
require "IKST_SafehouseClaim"

IKST_SafehouseClaimMirror = IKST_SafehouseClaimMirror or {}

function IKST_SafehouseClaimMirror.applyMirror(args)
    if not args then
        return false
    end
    if type(isClient) == "function" and not isClient() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and type(isClient) == "function" and not isClient() then
            return false
        end
    end
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local w = math.floor(tonumber(args.w) or 0)
    local h = math.floor(tonumber(args.h) or 0)
    if w < 1 or h < 1 then
        return false
    end
    local data = IKST_SafehouseClaim.store()
    local key = IKST_SafehouseClaim.keyFor(x, y, w, h)
    if args.action == "remove" then
        data.byKey[key] = nil
        return true
    end
    if args.action == "set" and type(args.entry) == "table" then
        local entry = args.entry
        IKST_SafehouseClaim.ensureEntryShape(entry)
        entry.key = key
        entry.x = x
        entry.y = y
        entry.w = w
        entry.h = h
        data.byKey[key] = entry
        return true
    end
    return false
end
