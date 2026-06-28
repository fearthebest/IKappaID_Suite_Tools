-- Safehouse claim permission keys (mirrors vehicle groups / user overrides).

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"

IKST_SafehousePermissions = IKST_SafehousePermissions or {}

IKST_SafehousePermissions.GROUP_EVERYONE = "everyone"
IKST_SafehousePermissions.GROUP_MEMBER = "member"
IKST_SafehousePermissions.GROUP_FACTION = "faction"

IKST_SafehousePermissions.ACTIONS = {
    "build", "destroy", "loot", "doors", "invite",
}

function IKST_SafehousePermissions.emptyPerms()
    return {
        build = false, destroy = false, loot = false, doors = false, invite = false,
    }
end

function IKST_SafehousePermissions.ownerPerms()
    return {
        build = true, destroy = true, loot = true, doors = true, invite = true,
    }
end

function IKST_SafehousePermissions.guestPermsFromSandbox()
    if IKST_ClaimPolicy.whitelistOnly() then
        return IKST_SafehousePermissions.emptyPerms()
    end
    return {
        build = IKST_ClaimPolicy.guestMayBuildSafehouse(),
        destroy = IKST_ClaimPolicy.guestMayDestroySafehouse(),
        loot = IKST_ClaimPolicy.guestMayLootSafehouse(),
        doors = IKST_ClaimPolicy.guestMaySafehouseDoors(),
        invite = false,
    }
end

function IKST_SafehousePermissions.memberPermsFromSandbox()
    return {
        build = IKST_ClaimPolicy.memberMayBuildSafehouse(),
        destroy = IKST_ClaimPolicy.memberMayDestroySafehouse(),
        loot = IKST_ClaimPolicy.memberMayLootSafehouse(),
        doors = IKST_ClaimPolicy.memberMayBuildSafehouse(),
        invite = false,
    }
end

function IKST_SafehousePermissions.sanitizeUserPerms(perms)
    local out = IKST_SafehousePermissions.copyPerms(perms)
    if IKST_ClaimPolicy.ownersGrantExtra() then
        return out
    end
    local cap = IKST_SafehousePermissions.guestPermsFromSandbox()
    for _, key in ipairs(IKST_SafehousePermissions.ACTIONS) do
        if out[key] == true and cap[key] ~= true then
            out[key] = false
        end
    end
    return out
end

function IKST_SafehousePermissions.defaultGroups()
    local guest = IKST_SafehousePermissions.guestPermsFromSandbox()
    local member = IKST_SafehousePermissions.memberPermsFromSandbox()
    return {
        everyone = IKST_SafehousePermissions.copyPerms(guest),
        member = IKST_SafehousePermissions.copyPerms(member),
        faction = { build = false, destroy = false, loot = false, doors = false, invite = false },
    }
end

function IKST_SafehousePermissions.copyPerms(src)
    local out = IKST_SafehousePermissions.emptyPerms()
    if not src then
        return out
    end
    for _, key in ipairs(IKST_SafehousePermissions.ACTIONS) do
        out[key] = src[key] == true
    end
    return out
end

function IKST_SafehousePermissions.mergePerms(base, overlay)
    local out = IKST_SafehousePermissions.copyPerms(base)
    if not overlay then
        return out
    end
    for _, key in ipairs(IKST_SafehousePermissions.ACTIONS) do
        if overlay[key] ~= nil then
            out[key] = overlay[key] == true
        end
    end
    return out
end

function IKST_SafehousePermissions.actionAllowed(perms, action)
    if not perms or not action then
        return false
    end
    return perms[action] == true
end

function IKST_SafehousePermissions.resolve(entry, player, action, sh)
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
        return IKST_SafehousePermissions.actionAllowed(userPerms, action)
    end

    local groups = entry.groups or IKST_SafehousePermissions.defaultGroups()
    local username = IKST_ClaimSocial.username(player)

    if groups.everyone and IKST_SafehousePermissions.actionAllowed(groups.everyone, action) then
        return true
    end

    if username and groups.member and IKST_SafehousePermissions.actionAllowed(groups.member, action) then
        if sh and IKST_ClaimSocial.safehouseHasMember(sh, username) then
            return true
        end
    end

    if username and groups.faction and IKST_SafehousePermissions.actionAllowed(groups.faction, action) then
        if IKST_ClaimSocial.sameFaction(username, entry.owner) then
            return true
        end
    end

    return false
end
