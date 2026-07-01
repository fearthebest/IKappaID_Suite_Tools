-- Sandbox-driven limits and MP permissions for vehicle / safehouse claims.

require "IKST_Shared"
require "IKST_Identity"

IKST_ClaimPolicy = IKST_ClaimPolicy or {}

function IKST_ClaimPolicy.sandbox()
    return SandboxVars and SandboxVars.IKappaIDSuiteTools or nil
end

function IKST_ClaimPolicy.sandboxInt(key, fallback, minVal, maxVal)
    local sv = IKST_ClaimPolicy.sandbox()
    local n = sv and tonumber(sv[key])
    if n == nil then
        n = fallback
    end
    n = math.floor(n)
    if minVal ~= nil and n < minVal then
        n = minVal
    end
    if maxVal ~= nil and n > maxVal then
        n = maxVal
    end
    return n
end

function IKST_ClaimPolicy.sandboxBool(key, fallback)
    local sv = IKST_ClaimPolicy.sandbox()
    local v = sv and sv[key]
    if v == nil then
        return fallback == true
    end
    return v == true
end

function IKST_ClaimPolicy.playerClaimsEnabled()
    return IKST_ClaimPolicy.sandboxBool("ClaimPlayerSelfService", true)
end

function IKST_ClaimPolicy.maxVehicleClaims()
    return IKST_ClaimPolicy.sandboxInt("MaxVehicleClaims", 3, 0, 50)
end

function IKST_ClaimPolicy.maxSafehouseClaims()
    return IKST_ClaimPolicy.sandboxInt("MaxSafehouseClaims", 1, 0, 20)
end

function IKST_ClaimPolicy.claimDurationDays()
    return IKST_ClaimPolicy.sandboxInt("ClaimDurationDays", 0, 0, 365)
end

function IKST_ClaimPolicy.claimDurationHours()
    local days = IKST_ClaimPolicy.claimDurationDays()
    if days <= 0 then
        return 0
    end
    return days * 24
end

function IKST_ClaimPolicy.adminBypass()
    return IKST_ClaimPolicy.sandboxBool("ClaimAdminBypass", true)
end

function IKST_ClaimPolicy.whitelistOnly()
    return IKST_ClaimPolicy.sandboxBool("ClaimWhitelistOnly", false)
end

function IKST_ClaimPolicy.allowNamedPlayers()
    return IKST_ClaimPolicy.sandboxBool("ClaimAllowNamedPlayers", true)
end

function IKST_ClaimPolicy.maxNamedPlayers()
    return IKST_ClaimPolicy.sandboxInt("ClaimMaxNamedPlayers", 30, 0, 200)
end

function IKST_ClaimPolicy.ownersGrantExtra()
    return IKST_ClaimPolicy.sandboxBool("ClaimOwnersGrantExtra", true)
end

function IKST_ClaimPolicy.ownersEditGroups()
    return IKST_ClaimPolicy.sandboxBool("ClaimOwnersEditGroups", true)
end

function IKST_ClaimPolicy.trimUsername(name)
    if not name then
        return ""
    end
    return tostring(name):match("^%s*(.-)%s*$") or ""
end

function IKST_ClaimPolicy.countNamedUsers(users)
    local n = 0
    if users then
        for _ in pairs(users) do
            n = n + 1
        end
    end
    return n
end

function IKST_ClaimPolicy.findUserPerms(users, usernameOrPlayer)
    if not users or not usernameOrPlayer then
        return nil
    end
    if type(usernameOrPlayer) == "table" and usernameOrPlayer.getUsername then
        local perms = IKST_Identity.findUserPerms(users, usernameOrPlayer)
        if perms then
            return perms
        end
        usernameOrPlayer = IKST_Identity.username(usernameOrPlayer)
    end
    if not usernameOrPlayer or usernameOrPlayer == "" then
        return nil
    end
    local resolved = IKST_Identity.resolveWhitelistKey(usernameOrPlayer)
    if resolved and users[resolved] then
        return users[resolved]
    end
    if users[usernameOrPlayer] then
        return users[usernameOrPlayer]
    end
    local lower = string.lower(tostring(usernameOrPlayer))
    for key, perms in pairs(users) do
        if string.lower(tostring(key)) == lower then
            return perms
        end
    end
    return nil
end

function IKST_ClaimPolicy.findUserKey(users, username)
    if IKST_Identity and IKST_Identity.findUserKey then
        return IKST_Identity.findUserKey(users, username)
    end
    if not users or not username or username == "" then
        return nil
    end
    if users[username] then
        return username
    end
    local lower = string.lower(tostring(username))
    for key in pairs(users) do
        if string.lower(tostring(key)) == lower then
            return key
        end
    end
    return nil
end

function IKST_ClaimPolicy.isGroupScope(scope)
    scope = tostring(scope or "")
    return scope == "everyone" or scope == "safehouse" or scope == "faction" or scope == "member"
end

function IKST_ClaimPolicy.canEditPermissionScope(scope, users, username)
    scope = tostring(scope or "")
    if scope == "remove_user" then
        if not IKST_ClaimPolicy.allowNamedPlayers() then
            return false, "named players disabled"
        end
        return true, nil
    end
    if scope == "user" then
        if not IKST_ClaimPolicy.allowNamedPlayers() then
            return false, "named players disabled"
        end
        username = IKST_ClaimPolicy.trimUsername(username)
        if username == "" then
            return false, "username required"
        end
        local existing = IKST_ClaimPolicy.findUserKey(users, username)
        if not existing then
            local max = IKST_ClaimPolicy.maxNamedPlayers()
            if max > 0 and IKST_ClaimPolicy.countNamedUsers(users) >= max then
                return false, "whitelist full"
            end
        end
        return true, nil
    end
    if IKST_ClaimPolicy.isGroupScope(scope) then
        if not IKST_ClaimPolicy.ownersEditGroups() then
            return false, "group editing disabled"
        end
        return true, nil
    end
    return false, "invalid permission scope"
end

function IKST_ClaimPolicy.guestMayEnter()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleGuestEnter", false)
end

function IKST_ClaimPolicy.guestMayDrive()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleGuestDrive", false)
end

function IKST_ClaimPolicy.guestMayLoot()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleGuestLoot", false)
end

function IKST_ClaimPolicy.guestMayVehicleDoors()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleGuestDoors", false)
end

function IKST_ClaimPolicy.guestMayVehicleRefuel()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleGuestRefuel", false)
end

function IKST_ClaimPolicy.mateMayEnterVehicle()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleMateEnter", true)
end

function IKST_ClaimPolicy.mateMayDriveVehicle()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleMateDrive", false)
end

function IKST_ClaimPolicy.mateMayLootVehicle()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleMateLoot", false)
end

function IKST_ClaimPolicy.guestMayBuildSafehouse()
    return IKST_ClaimPolicy.sandboxBool("ClaimSafehouseGuestBuild", false)
end

function IKST_ClaimPolicy.guestMayDestroySafehouse()
    return IKST_ClaimPolicy.sandboxBool("ClaimSafehouseGuestDestroy", false)
end

function IKST_ClaimPolicy.guestMayLootSafehouse()
    local sv = IKST_ClaimPolicy.sandbox()
    if sv and sv.ClaimSafehouseGuestLoot ~= nil then
        return sv.ClaimSafehouseGuestLoot == true
    end
    return false
end

function IKST_ClaimPolicy.guestMaySafehouseDoors()
    return IKST_ClaimPolicy.sandboxBool("ClaimSafehouseGuestDoors", false)
end

function IKST_ClaimPolicy.memberMayBuildSafehouse()
    return IKST_ClaimPolicy.sandboxBool("ClaimSafehouseMemberBuild", true)
end

function IKST_ClaimPolicy.memberMayDestroySafehouse()
    return IKST_ClaimPolicy.sandboxBool("ClaimSafehouseMemberDestroy", true)
end

function IKST_ClaimPolicy.memberMayLootSafehouse()
    return IKST_ClaimPolicy.sandboxBool("ClaimSafehouseMemberLoot", true)
end

function IKST_ClaimPolicy.nowHours()
    if getGameTime and getGameTime() and getGameTime().getWorldAgeHours then
        return getGameTime():getWorldAgeHours()
    end
    return 0
end

function IKST_ClaimPolicy.expiresAtFromNow()
    local hours = IKST_ClaimPolicy.claimDurationHours()
    if hours <= 0 then
        return nil
    end
    return IKST_ClaimPolicy.nowHours() + hours
end

function IKST_ClaimPolicy.isExpired(expiresAt)
    if expiresAt == nil then
        return false
    end
    return IKST_ClaimPolicy.nowHours() >= tonumber(expiresAt)
end

function IKST_ClaimPolicy.hoursRemaining(expiresAt)
    if expiresAt == nil then
        return nil
    end
    local remain = tonumber(expiresAt) - IKST_ClaimPolicy.nowHours()
    if remain <= 0 then
        return 0
    end
    return remain
end

function IKST_ClaimPolicy.hoursRemainingLabel(expiresAt)
    if expiresAt == nil then
        return ""
    end
    local hours = IKST_ClaimPolicy.hoursRemaining(expiresAt)
    if hours == nil then
        return ""
    end
    if hours <= 0 then
        return "expired"
    end
    local days = math.floor(hours / 24)
    local hrs = math.floor(hours % 24)
    if days > 0 then
        return tostring(days) .. "d " .. tostring(hrs) .. "h left"
    end
    return tostring(hrs) .. "h left"
end

function IKST_ClaimPolicy.usernamesEqual(a, b)
    if IKST_Identity and IKST_Identity.keysEqual then
        return IKST_Identity.keysEqual(a, b)
    end
    if not a or not b then
        return false
    end
    return string.lower(tostring(a)) == string.lower(tostring(b))
end

function IKST_ClaimPolicy.safehouseMetaKey(x, y, w, h)
    return tostring(math.floor(tonumber(x) or 0)) .. "_"
        .. tostring(math.floor(tonumber(y) or 0)) .. "_"
        .. tostring(math.floor(tonumber(w) or 0)) .. "_"
        .. tostring(math.floor(tonumber(h) or 0))
end

function IKST_ClaimPolicy.safehouseMetaStore()
    local data = ModData.getOrCreate("IKST_WorldRules")
    data.safehouseClaimMeta = data.safehouseClaimMeta or {}
    return data.safehouseClaimMeta
end

function IKST_ClaimPolicy.recordSafehouseClaim(owner, x, y, w, h)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return
    end
    local key = IKST_ClaimPolicy.safehouseMetaKey(x, y, w, h)
    IKST_ClaimPolicy.safehouseMetaStore()[key] = {
        owner = owner,
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
        w = math.floor(tonumber(w) or 0),
        h = math.floor(tonumber(h) or 0),
        claimedAt = IKST_ClaimPolicy.nowHours(),
        expiresAt = IKST_ClaimPolicy.expiresAtFromNow(),
    }
    if IKST.transmitModData and IKST.ModDataKeys then
        IKST.transmitModData(IKST.ModDataKeys.WorldRules)
    end
end

function IKST_ClaimPolicy.getSafehouseMeta(x, y, w, h)
    return IKST_ClaimPolicy.safehouseMetaStore()[IKST_ClaimPolicy.safehouseMetaKey(x, y, w, h)]
end

function IKST_ClaimPolicy.isSafehouseMetaExpired(meta)
    return meta and IKST_ClaimPolicy.isExpired(meta.expiresAt)
end

function IKST_ClaimPolicy.limitsSummary()
    local maxV = IKST_ClaimPolicy.maxVehicleClaims()
    local maxS = IKST_ClaimPolicy.maxSafehouseClaims()
    local days = IKST_ClaimPolicy.claimDurationDays()
    local vText = maxV > 0 and tostring(maxV) or IKST.text("IGUI_IKST_Claim_Unlimited", "unlimited")
    local sText = maxS > 0 and tostring(maxS) or IKST.text("IGUI_IKST_Claim_Unlimited", "unlimited")
    local dText = days > 0
        and (tostring(days) .. " " .. IKST.text("IGUI_IKST_Claim_Days", "days"))
        or IKST.text("IGUI_IKST_Claim_NoExpiry", "no expiry")
    local fmt = IKST.text("IGUI_IKST_Claim_LimitsFmt", "Vehicles: %s  Safehouses: %s  Duration: %s")
    return string.format(fmt, vText, sText, dText)
end
