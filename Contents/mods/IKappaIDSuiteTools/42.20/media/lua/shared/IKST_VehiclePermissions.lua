-- Vehicle claim permission keys and timed-action mapping.

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"

IKST_VehiclePermissions = IKST_VehiclePermissions or {}

IKST_VehiclePermissions.GROUP_EVERYONE = "everyone"
IKST_VehiclePermissions.GROUP_SAFEHOUSE = "safehouse"
IKST_VehiclePermissions.GROUP_FACTION = "faction"

IKST_VehiclePermissions.ACTIONS = {
    "enter", "drive", "loot", "doors", "engine", "mechanics", "refuel", "tow",
}

IKST_VehiclePermissions.TIMED_ACTION = {
    ISEnterVehicle = "enter",
    ISSwitchVehicleSeat = "enter",
    ISOpenVehicleDoor = "doors",
    ISCloseVehicleDoor = "doors",
    ISUnlockVehicleDoor = "doors",
    ISLockVehicleDoor = "doors",
    ISLockDoors = "doors",
    ISOpenCloseVehicleWindow = "doors",
    ISStartVehicleEngine = "engine",
    ISShutOffVehicleEngine = "engine",
    ISOpenMechanicsUIAction = "mechanics",
    ISInstallVehiclePart = "mechanics",
    ISUninstallVehiclePart = "mechanics",
    ISRepairEngine = "mechanics",
    ISTakeEngineParts = "mechanics",
    ISAddGasolineToVehicle = "refuel",
    ISRefuelFromGasPump = "refuel",
    ISTakeGasolineFromVehicle = "refuel",
    ISAttachTrailerToVehicle = "tow",
    ISDetachTrailerFromVehicle = "tow",
    ISHotwireVehicle = "engine",
    ISSmashVehicleWindow = "doors",
}

function IKST_VehiclePermissions.emptyPerms()
    return {
        enter = false, drive = false, loot = false, doors = false,
        engine = false, mechanics = false, refuel = false, tow = false,
    }
end

function IKST_VehiclePermissions.ownerPerms()
    return {
        enter = true, drive = true, loot = true, doors = true,
        engine = true, mechanics = true, refuel = true, tow = true,
    }
end

function IKST_VehiclePermissions.guestPermsFromSandbox()
    if IKST_ClaimPolicy.whitelistOnly() then
        return IKST_VehiclePermissions.emptyPerms()
    end
    return {
        enter = IKST_ClaimPolicy.guestMayEnter(),
        drive = IKST_ClaimPolicy.guestMayDrive(),
        loot = IKST_ClaimPolicy.guestMayLoot(),
        doors = IKST_ClaimPolicy.guestMayVehicleDoors(),
        engine = false,
        mechanics = false,
        refuel = IKST_ClaimPolicy.guestMayVehicleRefuel(),
        tow = false,
    }
end

function IKST_VehiclePermissions.matePermsFromSandbox()
    return {
        enter = IKST_ClaimPolicy.mateMayEnterVehicle(),
        drive = IKST_ClaimPolicy.mateMayDriveVehicle(),
        loot = IKST_ClaimPolicy.mateMayLootVehicle(),
        doors = IKST_ClaimPolicy.mateMayEnterVehicle(),
        engine = false,
        mechanics = false,
        refuel = false,
        tow = false,
    }
end

function IKST_VehiclePermissions.sanitizeUserPerms(perms)
    local out = IKST_VehiclePermissions.copyPerms(perms)
    if IKST_ClaimPolicy.ownersGrantExtra() then
        return out
    end
    local cap = IKST_VehiclePermissions.guestPermsFromSandbox()
    for _, key in ipairs(IKST_VehiclePermissions.ACTIONS) do
        if out[key] == true and cap[key] ~= true then
            out[key] = false
        end
    end
    return out
end

function IKST_VehiclePermissions.defaultGroups()
    local guest = IKST_VehiclePermissions.guestPermsFromSandbox()
    local mate = IKST_VehiclePermissions.matePermsFromSandbox()
    return {
        everyone = IKST_VehiclePermissions.copyPerms(guest),
        safehouse = IKST_VehiclePermissions.copyPerms(mate),
        faction = {
            enter = mate.enter,
            drive = false,
            loot = false,
            doors = mate.enter,
            engine = false,
            mechanics = false,
            refuel = false,
            tow = false,
        },
    }
end

function IKST_VehiclePermissions.copyPerms(src)
    local out = IKST_VehiclePermissions.emptyPerms()
    if not src then
        return out
    end
    for _, key in ipairs(IKST_VehiclePermissions.ACTIONS) do
        out[key] = src[key] == true
    end
    return out
end

function IKST_VehiclePermissions.mergePerms(base, overlay)
    local out = IKST_VehiclePermissions.copyPerms(base)
    if not overlay then
        return out
    end
    for _, key in ipairs(IKST_VehiclePermissions.ACTIONS) do
        if overlay[key] ~= nil then
            out[key] = overlay[key] == true
        end
    end
    return out
end

function IKST_VehiclePermissions.actionAllowed(perms, action)
    if not perms or not action then
        return false
    end
    if action == "drive" and perms.drive ~= true and perms.enter == true then
        return false
    end
    if perms[action] == true then
        return true
    end
    if action == "switchSeat" or action == "enter" then
        return perms.enter == true
    end
    return false
end

function IKST_VehiclePermissions.resolve(entry, player, action)
    if not entry or not player or not action then
        return true
    end
    if IKST_Identity.playerOwnsKey(player, entry.owner) then
        return true
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_ClaimPolicy.adminBypass() and IKST_Access.canUseTools(player) then
        return true
    end

    local users = entry.users or {}
    local userPerms = IKST_ClaimPolicy.findUserPerms(users, player)
    if userPerms then
        return IKST_VehiclePermissions.actionAllowed(userPerms, action)
    end

    local groups = entry.groups or IKST_VehiclePermissions.defaultGroups()
    local ownerKey = entry.owner
    local username = IKST_ClaimSocial.username(player)

    if groups.everyone and IKST_VehiclePermissions.actionAllowed(groups.everyone, action) then
        return true
    end

    if username and groups.safehouse and IKST_VehiclePermissions.actionAllowed(groups.safehouse, action) then
        if IKST_ClaimSocial.userInSafehouseOwnedBy(username, ownerKey) then
            return true
        end
    end

    if username and groups.faction and IKST_VehiclePermissions.actionAllowed(groups.faction, action) then
        if IKST_ClaimSocial.sameFaction(username, ownerKey) then
            return true
        end
    end

    return false
end

function IKST_VehiclePermissions.actionForClass(classTable)
    if not classTable or not classTable.Type then
        return nil
    end
    return IKST_VehiclePermissions.TIMED_ACTION[classTable.Type]
end
