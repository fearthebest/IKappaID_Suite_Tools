-- Dropbox / readonly container transfer rules.

require "IKST_Shared"
require "IKST_TileProtect"
require "IKST_Access"
require "IKST_Locks"
require "IKST_Identity"

IKST_ContainerRules = IKST_ContainerRules or {}

function IKST_ContainerRules.squareFromContainer(container)
    if not container then
        return nil
    end
    if container.getParent then
        local parent = container:getParent()
        if parent and parent.getSquare then
            return parent:getSquare()
        end
    end
    if container.getSourceGrid then
        local sq = container:getSourceGrid()
        if sq then
            return sq
        end
    end
    return nil
end

function IKST_ContainerRules.coordsForContainer(container)
    local sq = IKST_ContainerRules.squareFromContainer(container)
    if not sq then
        return nil
    end
    return sq:getX(), sq:getY(), sq:getZ()
end

function IKST_ContainerRules.playerName(player)
    if not player then
        return ""
    end
    if player.getUsername then
        return player:getUsername() or ""
    end
    if player.getDisplayName then
        return player:getDisplayName() or ""
    end
    return ""
end

function IKST_ContainerRules.transferAllowed(item, srcContainer, destContainer, player, quiet)
    if not player or not item then
        return true
    end
    if IKST_Access.canUseTools(player) then
        return true
    end

    if IKST_VehicleClaim and IKST_VehicleClaim.transferAllowed then
        if not IKST_VehicleClaim.transferAllowed(item, srcContainer, destContainer, player) then
            if not quiet and player then
                IKST.notify(player, IKST.text("IGUI_IKST_Claim_VehicleDenied", "This vehicle is claimed by another player."), false)
            end
            return false
        end
    end

    local function checkContainer(container, takingOut)
        if not container then
            return true
        end
        local x, y, z = IKST_ContainerRules.coordsForContainer(container)
        if not x then
            return true
        end
        if IKST_TileProtect.isReadonly(x, y, z) then
            if not quiet and player then
                IKST.notify(player, IKST.text("IGUI_IKST_Guard_ReadonlyBlock", "Container is readonly."), false)
            end
            return false
        end
        local owner = IKST_TileProtect.getDropboxOwner(x, y, z)
        if owner and owner ~= "" then
            local allowed = false
            if IKST_Identity and IKST_Identity.playerOwnsKey then
                allowed = IKST_Identity.playerOwnsKey(player, owner)
            else
                allowed = IKST_ContainerRules.playerName(player) == owner
            end
            if takingOut and not allowed then
                if not quiet and player then
                    IKST.notify(player, IKST.text("IGUI_IKST_Guard_DropboxBlock", "Dropbox: deposit only."), false)
                end
                return false
            end
        end
        if IKST_Locks and IKST_Locks.isLocked(x, y, z) and not IKST_Locks.mayAccess(player, x, y, z) then
            if not quiet and player then
                IKST.notify(player, IKST.text("IGUI_IKST_Keypad_Locked", "Container is locked."), false)
            end
            return false
        end
        if IKST_SafehouseClaim and IKST_SafehouseClaim.canAtCoords then
            local allowed = IKST_SafehouseClaim.canAtCoords(player, x, y, z, "loot")
            if allowed == false then
                if not quiet and player then
                    IKST.notify(player, IKST.text("IGUI_IKST_Claim_SafehouseDenied", "This safe area is claimed by another player."), false)
                end
                return false
            end
        end
        return true
    end

    if not checkContainer(srcContainer, true) then
        return false
    end
    if not checkContainer(destContainer, false) then
        return false
    end
    return true
end
