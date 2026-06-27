if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ActionLog"
require "IKST_JobGuard"
require "IKST_JobLayout"
require "IKST_ClaimPolicy"

IKST_JobClaim = IKST_JobClaim or {}

function IKST_JobClaim.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state or not IKST_JobGuard then
        return 8
    end

    local tool = state.navTool or "safehouses"
    local y = 8

    if IKST_ClaimPolicy then
        panel:makeJobLabel(12, y, IKST_ClaimPolicy.limitsSummary(), UIFont.Small)
        y = y + 22
    end

    if tool == "vehicleclaim" then
        state.guardMode = "vehicles"
        y = IKST_JobGuard.buildVehicles(panel, y)
    else
        state.guardMode = "safehouses"
        if not state.claimShRequested and IKST_JobGuard.requestSafehouses then
            state.claimShRequested = true
            IKST_JobGuard.requestSafehouses(panel.player)
        end
        y = IKST_JobGuard.buildSafehouses(panel, y)
    end

    panel.logPanel = IKST_ActionLog.dock(panel, panel.player, y)
    return y
end
