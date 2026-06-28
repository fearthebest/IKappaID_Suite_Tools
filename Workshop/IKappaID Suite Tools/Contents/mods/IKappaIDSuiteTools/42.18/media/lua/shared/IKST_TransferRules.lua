-- Shared inventory transfer rules (server authority + UI checks).

require "IKST_Shared"
require "IKST_Access"
require "IKST_Identity"
require "IKST_VehicleClaim"

IKST_TransferRules = IKST_TransferRules or {}

function IKST_TransferRules.transferAllowed(item, srcContainer, destContainer, player, quiet)
    if not player or not item then
        return true
    end
    if IKST_Identity and IKST_Identity.bankCardTransferAllowed then
        if not IKST_Identity.bankCardTransferAllowed(item, srcContainer, destContainer, player, quiet) then
            return false
        end
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return true
    end

    if IKST_Economy and IKST_Economy.vendTransferAllowed then
        if not IKST_Economy.vendTransferAllowed(item, srcContainer, destContainer, player, quiet) then
            return false
        end
    end

    if IKST_ContainerRules and IKST_ContainerRules.transferAllowed then
        return IKST_ContainerRules.transferAllowed(item, srcContainer, destContainer, player, quiet)
    end

    if IKST_VehicleClaim and IKST_VehicleClaim.transferAllowed then
        if not IKST_VehicleClaim.transferAllowed(item, srcContainer, destContainer, player) then
            if not quiet and IKST.notify then
                IKST.notify(player, IKST.text("IGUI_IKST_Claim_VehicleDenied", "This vehicle is claimed by another player."), false)
            end
            return false
        end
    end

    return true
end
