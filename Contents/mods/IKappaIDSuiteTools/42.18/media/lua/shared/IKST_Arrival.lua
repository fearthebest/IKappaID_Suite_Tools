-- Arrival Stabilization: shared sandbox helpers.

require "IKST_Shared"
require "IKST_Access"

IKST_Arrival = IKST_Arrival or {}

function IKST_Arrival.enabled()
    if not IKST.isModEnabled() then
        return false
    end
    return IKST_Access.sandboxBool("ArrivalStabilizationEnabled", true)
end

function IKST_Arrival.durationMs()
    local seconds = IKST_Access.sandboxInt("ArrivalStabilizationSeconds", 30, 0, 300)
    return seconds * 1000
end

function IKST_Arrival.onJoin()
    return IKST_Access.sandboxBool("ArrivalOnJoin", true)
end

function IKST_Arrival.onRespawn()
    return IKST_Access.sandboxBool("ArrivalOnRespawn", true)
end

function IKST_Arrival.attackEndsGrace()
    return IKST_Access.sandboxBool("ArrivalAttackEndsGrace", true)
end

function IKST_Arrival.moveEndsGrace()
    return IKST_Access.sandboxBool("ArrivalMoveEndsGrace", false)
end

function IKST_Arrival.moveThresholdTiles()
    return IKST_Access.sandboxInt("ArrivalMoveThresholdTiles", 3, 1, 20)
end

function IKST_Arrival.shouldApply(reason)
    if not IKST_Arrival.enabled() then
        return false
    end
    if IKST_Arrival.durationMs() <= 0 then
        return false
    end
    if reason == "respawn" then
        return IKST_Arrival.onRespawn()
    end
    return IKST_Arrival.onJoin()
end
