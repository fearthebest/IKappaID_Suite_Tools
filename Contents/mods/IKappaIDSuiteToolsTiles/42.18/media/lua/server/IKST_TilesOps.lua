if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_WorldOps"
require "IKST_Lifecycle"
require "IKST_TilesWorldOps"
require "IKST_AutomationOps"
require "IKST_ProtectOps"
require "IKST_TilesGuardOps"

IKST_TilesOps = IKST_TilesOps or {}

local function readCoord(args, key)
    if not args then
        return nil
    end
    local v = tonumber(args[key])
    if v == nil then
        return nil
    end
    return math.floor(v)
end

function IKST_TilesOps.handle(command, player, args)
    args = args or {}
    if IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
        return false, "world loading"
    end
    if not player then
        return false, "no player"
    end

    if command == IKST.CMD.inspectSquare then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local sq = IKST_TilesWorldOps.getSquare(x, y, z)
        IKST_WorldOps.sendInspect(player, x, y, z, IKST_TilesWorldOps.inspectSquare(sq))
        return true, "ok"
    end

    if command == IKST.CMD.cleanupObject or command == IKST.CMD.cleanupTile or command == IKST.CMD.cleanupSquare or command == IKST.CMD.paintRemove then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local mode = command
        if command == IKST.CMD.paintRemove then
            mode = IKST.CMD.cleanupObject
        end
        local argMode = args and args.mode
        if argMode == IKST.CLEANUP_MODES.vegetation or argMode == "vegetation" then
            mode = IKST.CLEANUP_MODES.vegetation
        end
        local ok, message = IKST_TilesWorldOps.runCleanup(mode, x, y, z, player, command)
        if ok then
            IKST.pushLog(player, command .. " @ " .. x .. "," .. y .. "," .. z .. " — " .. tostring(message))
        end
        return ok, message, x, y, z
    end

    if command == IKST.CMD.cleanupRadius then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local radius = IKST.clampRadius(args.radius)
        local mode = args.mode or IKST.CLEANUP_MODES.removeObject
        local squares = IKST_Grid.squaresInRadius(x, y, z, radius)
        IKST_Grid.sortNearest(squares, x, y)
        IKST_TilesWorldOps.runBatch(player, squares, IKST_TilesWorldOps.cleanupModeToCommand(mode), "radius " .. radius)
        return true, "batch started", x, y, z
    end

    if command == IKST.CMD.cleanupCube then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local half = IKST.clampCubeHalf(args.halfExtent)
        local mode = args.mode or IKST.CLEANUP_MODES.removeObject
        local squares = IKST_Grid.squaresInCube(x, y, z, half)
        if #squares == 0 then
            return false, "no scope", x, y, z
        end
        local edge = IKST.cubeEdgeLength(half)
        IKST_TilesWorldOps.runBatch(player, squares, IKST_TilesWorldOps.cleanupModeToCommand(mode), "cube " .. edge .. "x" .. edge .. "x" .. edge)
        return true, "cube batch started (" .. #squares .. ")", x, y, z
    end

    if command == IKST.CMD.cleanupRoom or command == IKST.CMD.cleanupBuilding then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local sq = IKST_TilesWorldOps.getSquare(x, y, z)
        local mode = args.mode or IKST.CLEANUP_MODES.removeObject
        local squares = command == IKST.CMD.cleanupRoom
            and IKST_Grid.squaresInRoomFromSquare(sq)
            or IKST_Grid.squaresInBuildingFromSquare(sq)
        if #squares == 0 then
            return false, "no scope", x, y, z
        end
        local label = command == IKST.CMD.cleanupRoom and "room" or "building"
        IKST_TilesWorldOps.runBatch(player, squares, IKST_TilesWorldOps.cleanupModeToCommand(mode), label)
        return true, "batch started (" .. #squares .. ")", x, y, z
    end

    if command == IKST.CMD.cleanupVegetation then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local radius = IKST.clampRadius(args.radius)
        local squares = IKST_Grid.squaresInRadius(x, y, z, radius)
        IKST_TilesWorldOps.runBatch(player, squares, "vegetation", "vegetation " .. radius)
        return true, "vegetation batch started", x, y, z
    end

    if command == IKST.CMD.paintPlace then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local ok, message = IKST_TilesWorldOps.paintPlace(x, y, z, args.sprite, player)
        if ok then
            IKST.pushLog(player, "paint " .. tostring(args.sprite) .. " @ " .. x .. "," .. y)
        end
        return ok, message, x, y, z
    end

    if command == IKST.CMD.rewind then
        local ok, message = IKST_TilesWorldOps.rewind(player)
        if ok then
            IKST.pushLog(player, message)
        elseif message then
            IKST.notify(player, message, false)
        end
        return ok, message
    end

    if command == IKST.CMD.protectList then
        local x = math.floor(tonumber(args.x) or player:getX())
        local y = math.floor(tonumber(args.y) or player:getY())
        local z = tonumber(args.z) or player:getZ()
        IKST_ProtectOps.sendList(player, x, y, z, args.radius)
        return true, "listed"
    end

    if IKST.AUTO_COMMANDS and IKST.AUTO_COMMANDS[command] then
        return IKST_AutomationOps.handle(command, player, args)
    end

    if IKST.PROTECT_COMMANDS and IKST.PROTECT_COMMANDS[command] then
        return IKST_ProtectOps.handle(command, player, args)
    end

    if IKST_TilesGuardOps and IKST_TilesGuardOps.handle then
        local ok, msg = IKST_TilesGuardOps.handle(command, player, args)
        if ok ~= nil then
            return ok, msg
        end
    end

    return false, "unknown tiles command"
end
