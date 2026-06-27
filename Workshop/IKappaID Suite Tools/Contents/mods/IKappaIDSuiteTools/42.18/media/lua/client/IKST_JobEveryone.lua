if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_VehicleClaim"
require "IKST_ClaimPolicy"

IKST_JobEveryone = IKST_JobEveryone or {}

function IKST_JobEveryone.build(panel)
    local p = panel.player
    if not p then
        return 8
    end

    local y = 8
    local x = math.floor(p:getX())
    local py = math.floor(p:getY())
    local z = p:getZ()
    local cellX = math.floor(x / 300)
    local cellY = math.floor(py / 300)

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Everyone_Where", "Your position"), UIFont.Small)
    y = y + 18
    panel:makeJobLabel(12, y, string.format("%d, %d, %d  ·  Cell %d,%d", x, py, z, cellX, cellY), UIFont.Small)
    y = y + 22
    if IKST_ClaimPolicy then
        panel:makeJobLabel(12, y, IKST_ClaimPolicy.limitsSummary(), UIFont.Small)
        y = y + 22
    end

    panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_Everyone_RefreshClaims", "Refresh my claims"), function()
        IKST.dispatchCommand(p, IKST.CMD.vehicleClaimList, { all = false })
        if IKST_JobGuard then
            IKST_JobGuard.requestNearbyVehicles(p)
        end
        panel:refreshJobUI()
    end, false)
    y = y + 32

    local claims = IKST_JobGuard and IKST_JobGuard.claims or {}
    if #claims == 0 then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Everyone_NoClaims", "No vehicle claims loaded — press Refresh."), UIFont.Small)
        y = y + 22
    else
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Everyone_MyClaims", "My vehicle claims"), UIFont.Small)
        y = y + 18
        for i, claim in ipairs(claims) do
            if i > 10 then
                break
            end
            local line = "#" .. tostring(claim.id) .. " " .. IKST_VehicleClaim.claimLabel(claim)
            if claim.x and claim.y then
                line = line .. " @ " .. claim.x .. "," .. claim.y
            end
            panel:makeJobLabel(12, y, line, UIFont.Small)
            y = y + 18
        end
    end

    y = y + 8
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Everyone_Hint", "Use Claim workspace to claim safehouses and vehicles."), UIFont.Small)
    y = y + 24

    return y
end
