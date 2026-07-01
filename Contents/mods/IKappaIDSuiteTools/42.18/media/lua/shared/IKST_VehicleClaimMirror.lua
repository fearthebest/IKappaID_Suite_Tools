-- Client mirror for server-authoritative vehicle claim ModData (MP).

require "IKST_Shared"
require "IKST_VehicleClaim"

IKST_VehicleClaimMirror = IKST_VehicleClaimMirror or {}

function IKST_VehicleClaimMirror.applyMirror(args)
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
    local data = IKST_VehicleClaim.store()
    if args.action == "remove" then
        local vid = tonumber(args.vehicleId)
        if not vid then
            return false
        end
        local key = tostring(vid)
        local entry = data.byId[key]
        if entry and entry.owner then
            IKST_VehicleClaim.removeFromOwnerList(entry.owner, key)
        end
        data.byId[key] = nil
        return true
    end
    if args.action == "set" and type(args.entry) == "table" then
        local entry = args.entry
        local key = tostring(entry.id or args.vehicleId)
        if key == "" or key == "nil" then
            return false
        end
        IKST_VehicleClaim.ensureEntryShape(entry)
        data.byId[key] = entry
        if entry.owner then
            IKST_VehicleClaim.addToOwnerList(entry.owner, key)
        end
        return true
    end
    return false
end
