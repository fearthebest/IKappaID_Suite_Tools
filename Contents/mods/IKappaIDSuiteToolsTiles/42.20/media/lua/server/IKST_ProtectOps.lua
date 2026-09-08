-- Tile / vehicle protection server ops.
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_TileProtect"
require "IKST_ModDataSync"

IKST_ProtectOps = IKST_ProtectOps or {}

local function commitProtect()
    IKST.transmitModData(IKST.ModDataKeys.Protect)
end

function IKST_ProtectOps.handle(command, player, args)
    args = args or {}
    local x = math.floor(tonumber(args.x) or (player and player:getX()) or 0)
    local y = math.floor(tonumber(args.y) or (player and player:getY()) or 0)
    local z = math.floor(tonumber(args.z) or (player and player:getZ()) or 0)
    local radius = IKST.clampRadius(args.radius)

    if command == IKST.CMD.protectSquare then
        IKST_TileProtect.protectTile(x, y, z, args.label or "admin")
        commitProtect()
        return true, "tile protected"
    end

    if command == IKST.CMD.unprotectSquare then
        local clearedTile, clearedReadonly = IKST_TileProtect.clearSquare(x, y, z)
        commitProtect()
        if clearedTile and clearedReadonly then
            return true, "tile unprotected + storage unlocked"
        end
        if clearedTile then
            return true, "tile unprotected"
        end
        if clearedReadonly then
            return true, "storage unlocked"
        end
        return false, "not protected"
    end

    if command == IKST.CMD.protectRadius then
        local n = IKST_TileProtect.protectRadius(x, y, z, radius)
        commitProtect()
        return true, "protected " .. n .. " tile(s)"
    end

    if command == IKST.CMD.unprotectRadius then
        local nTile, nReadonly = IKST_TileProtect.unprotectRadius(x, y, z, radius)
        commitProtect()
        if nTile == 0 and nReadonly == 0 then
            return true, "unprotected 0 tile(s)"
        end
        if nReadonly > 0 then
            return true, "unprotected " .. nTile .. " tile(s), unlocked " .. nReadonly .. " storage"
        end
        return true, "unprotected " .. nTile .. " tile(s)"
    end

    if command == IKST.CMD.protectVehicle then
        if IKST_TileProtect.protectVehicle(args.vehicleId) then
            commitProtect()
            return true, "vehicle #" .. tostring(args.vehicleId) .. " protected"
        end
        return false, "invalid vehicle"
    end

    if command == IKST.CMD.unprotectVehicle then
        if IKST_TileProtect.unprotectVehicle(args.vehicleId) then
            commitProtect()
            return true, "vehicle unprotected"
        end
        return false, "not protected"
    end

    if command == IKST.CMD.setDropbox then
        IKST_TileProtect.setDropbox(x, y, z, args.owner)
        commitProtect()
        if args.owner and args.owner ~= "" then
            return true, "dropbox owner: " .. args.owner
        end
        return true, "dropbox cleared"
    end

    if command == IKST.CMD.setReadonly then
        IKST_TileProtect.setReadonly(x, y, z, args.on == true)
        commitProtect()
        return true, args.on and "readonly on" or "readonly off"
    end

    return false, "unknown protect command"
end

function IKST_ProtectOps.sendList(player, cx, cy, cz, radius)
    IKST.deliverClientCommand(player, IKST.CMD.protectListResult, {
        total = IKST_TileProtect.count(),
        readonlyTotal = IKST_TileProtect.countReadonly(),
        tiles = IKST_TileProtect.listNearby(cx, cy, cz, radius),
    })
end
