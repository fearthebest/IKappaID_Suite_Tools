-- Catch/release helpers (split from IKST_GuardOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_StaffOps"

IKST_GuardOps = IKST_GuardOps or {}

function IKST_GuardOps.syncCaughtClient(player, caught, x, y, z)
    if not player then
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.catchSync, {
        caught = caught == true,
        x = x,
        y = y,
        z = z,
    })
end

function IKST_GuardOps.setCaught(player, caught)
    if not player then
        return false, "no player"
    end
    local md = player:getModData()
    md.IKST_caught = caught == true
    if md.IKST_caught then
        md.IKST_catchX = player:getX()
        md.IKST_catchY = player:getY()
        md.IKST_catchZ = player:getZ()
    else
        md.IKST_catchX = nil
        md.IKST_catchY = nil
        md.IKST_catchZ = nil
    end
    if player.setBlockMovement then
        player:setBlockMovement(md.IKST_caught)
    end
    IKST_GuardOps.syncCaughtClient(player, md.IKST_caught, md.IKST_catchX, md.IKST_catchY, md.IKST_catchZ)
    return true, caught and "caught" or "released"
end

function IKST_GuardOps.enforceCaughtPosition(player)
    if not player then
        return
    end
    local md = player:getModData()
    if not md.IKST_caught then
        return
    end
    if md.IKST_catchX and md.IKST_catchY then
        if math.abs(player:getX() - md.IKST_catchX) > 0.5 or math.abs(player:getY() - md.IKST_catchY) > 0.5 then
            IKST_StaffOps.teleportPlayer(player, md.IKST_catchX, md.IKST_catchY, md.IKST_catchZ or 0)
        end
    end
end
