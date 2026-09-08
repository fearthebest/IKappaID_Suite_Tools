if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_ClaimPermissionsUI"
require "IKST_SafehouseClaim"

IKST_SafehouseClaimUI = IKST_SafehouseClaimUI or {}
IKST_SafehouseClaimUI.instance = nil

function IKST_SafehouseClaimUI.close()
    IKST_ClaimPermissionsUI.close()
    IKST_SafehouseClaimUI.instance = nil
end

function IKST_SafehouseClaimUI.open(player, x, y, w, h, defaultScope)
    IKST_ClaimPermissionsUI.openSafehouse(player, x, y, w, h, defaultScope)
    IKST_SafehouseClaimUI.instance = IKST_ClaimPermissionsUI.instance
end

function IKST_SafehouseClaimUI.openFromSafehouse(player, sh)
    if not sh then
        return
    end
    local x, y, w, h = IKST_SafehouseClaim.boundsFromSafehouse(sh)
    if x then
        IKST_SafehouseClaimUI.open(player, x, y, w, h)
    end
end
