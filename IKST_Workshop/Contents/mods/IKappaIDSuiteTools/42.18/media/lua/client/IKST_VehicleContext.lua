if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_VehicleClaim"
require "IKST_VehiclePermissions"
require "IKST_Access"
require "IKST_ClaimIcons"
require "IKST_VehicleUtil"

IKST_VehicleContext = IKST_VehicleContext or {}

function IKST_VehicleContext.vehicleFromWorldObjects(worldobjects)
    if not worldobjects then
        return nil
    end
    for _, obj in ipairs(worldobjects) do
        if obj and instanceof and instanceof(obj, "BaseVehicle") then
            return obj
        end
    end
    return nil
end

function IKST_VehicleContext.mayUseClaims(player)
    if IKST_Access.canUseTools(player) then
        return true
    end
    return IKST_ClaimPolicy and IKST_ClaimPolicy.playerClaimsEnabled()
end

function IKST_VehicleContext.addOption(sub, label, player, fn, iconPath)
    local opt = sub:addOption(label, player, fn)
    IKST_ClaimIcons.applyContextIcon(opt, iconPath)
    return opt
end

function IKST_VehicleContext.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    if not IKST_VehicleContext.mayUseClaims(player) then
        return
    end
    local vehicle = IKST_VehicleContext.vehicleFromWorldObjects(worldobjects)
    if not vehicle or not vehicle.getId then
        return
    end
    local vid = vehicle:getId()
    if vid == nil then
        return
    end
    local entry = IKST_VehicleClaim.get(vid)
    local username = IKST_VehicleClaim.playerUsername(player)
    local isAdmin = IKST_Access.canUseTools(player)
    local isOwner = entry and IKST_VehicleClaim.isOwner(entry, username)
    local canEdit = entry and IKST_VehicleClaim.playerMayEdit(entry, player)

    local root = context:addOption(IKST.text("IGUI_IKST_VehicleClaim_Menu", "Vehicle claim"))
    IKST_ClaimIcons.applyContextIcon(root, IKST_ClaimIcons.VEHICLE_CLAIM)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    if not entry or IKST_VehicleClaim.isEntryExpired(entry) then
        IKST_VehicleContext.addOption(sub, IKST.text("IGUI_IKST_Guard_Claim", "Claim vehicle"), player, function()
            IKST.dispatchCommand(player, IKST.CMD.vehicleClaim, { vehicleId = vid })
        end, IKST_ClaimIcons.VEHICLE_CLAIM)
        return
    end

    if isOwner or isAdmin then
        IKST_VehicleContext.addOption(sub, IKST.text("IGUI_IKST_Guard_ReleaseClaim", "Release claim"), player, function()
            IKST.dispatchCommand(player, IKST.CMD.vehicleReleaseClaim, { vehicleId = vid })
        end, IKST_ClaimIcons.VEHICLE_UNCLAIM)
    end

    if canEdit then
        IKST_VehicleContext.addOption(sub, IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"), player, function()
            if IKST_VehicleClaimUI and IKST_VehicleClaimUI.open then
                IKST_VehicleClaimUI.open(player, vid)
            end
        end, IKST_ClaimIcons.PERMS)
    end

    if IKST.Plugins and IKST.Plugins.isActive("vehicles") and entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        local mayRecover = isOwner or canEdit or IKST_VehicleUtil.playerHasVehicleKey(player, vehicle)
        if mayRecover then
            IKST_VehicleContext.addOption(sub, IKST.text("IGUI_IKST_FieldRecovery", "Field recovery"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.vehicleFieldRecovery, { vehicleId = vid })
            end, IKST_ClaimIcons.VEHICLE_CLAIM)
        end
    end

    if entry then
        sub:addOption(IKST.text("IGUI_IKST_VehicleClaim_Info", "Owner") .. ": " .. tostring(entry.owner or "?"), nil, nil)
    end
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_VehicleContext.onFillWorldObjectContextMenu)
end
