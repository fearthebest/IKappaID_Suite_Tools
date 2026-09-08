-- Shared inventory transfer rules (client hooks + server TransferServer guard).

require "IKST_Shared"
require "IKST_Access"
require "IKST_Identity"
require "IKST_VehicleClaim"

IKST_TransferRules = IKST_TransferRules or {}

local function coordsFromContainer(container)
    if IKST_ContainerRules and type(IKST_ContainerRules.coordsForContainer) == "function" then
        return IKST_ContainerRules.coordsForContainer(container)
    end
    if IKST_VehicleClaim and type(IKST_VehicleClaim.vehicleFromContainer) == "function" then
        local vehicle = IKST_VehicleClaim.vehicleFromContainer(container)
        if vehicle and type(vehicle.getX) == "function" then
            return vehicle:getX(), vehicle:getY(), vehicle:getZ() or 0
        end
    end
    local parent = container and type(container.getParent) == "function" and container:getParent() or nil
    if parent and type(parent.getSquare) == "function" then
        local sq = parent:getSquare()
        if sq and type(sq.getX) == "function" then
            return sq:getX(), sq:getY(), sq:getZ()
        end
    end
    if container and type(container.getSourceGrid) == "function" then
        local sq = container:getSourceGrid()
        if sq and type(sq.getX) == "function" then
            return sq:getX(), sq:getY(), sq:getZ()
        end
    end
    return nil
end

local function safehouseLootAllowed(container, player, quiet)
    if not container or not player then
        return true
    end
    if not IKST_SafehouseClaim or type(IKST_SafehouseClaim.canAtCoords) ~= "function" then
        return true
    end
    local x, y, z = coordsFromContainer(container)
    if not x then
        return true
    end
    local allowed = IKST_SafehouseClaim.canAtCoords(player, x, y, z, "loot")
    if allowed == false then
        if not quiet and IKST.notify then
            IKST.notify(player, IKST.text("IGUI_IKST_Claim_SafehouseDenied", "This safe area is claimed by another player."), false)
        end
        return false
    end
    return true
end

function IKST_TransferRules.transferAllowed(item, srcContainer, destContainer, player, quiet)
    if not player or not item then
        return true
    end
    if IKST_EconomyIdentity and IKST_EconomyIdentity.bankCardTransferAllowed then
        if not IKST_EconomyIdentity.bankCardTransferAllowed(item, srcContainer, destContainer, player, quiet) then
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

    -- Tiles plugin: dropbox / readonly / locks / safehouse / vehicle (when loaded).
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

    if not safehouseLootAllowed(srcContainer, player, quiet) then
        return false
    end
    if not safehouseLootAllowed(destContainer, player, quiet) then
        return false
    end

    return true
end
