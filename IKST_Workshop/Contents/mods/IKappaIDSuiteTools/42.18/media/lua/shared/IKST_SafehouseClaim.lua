-- Safehouse ownership permissions (server-authoritative ModData, keyed by bounds).

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"
require "IKST_SafehousePermissions"
require "IKST_ModDataSync"
require "IKST_Access"
require "IKST_Grid"

IKST_SafehouseClaim = IKST_SafehouseClaim or {}

function IKST_SafehouseClaim.store()
    local data = ModData.getOrCreate("IKST_SafehouseClaim")
    data.byKey = data.byKey or {}
    return data
end

function IKST_SafehouseClaim.keyFor(x, y, w, h)
    return IKST_ClaimPolicy.safehouseMetaKey(x, y, w, h)
end

function IKST_SafehouseClaim.get(x, y, w, h)
    if x == nil or y == nil then
        return nil
    end
    return IKST_SafehouseClaim.store().byKey[IKST_SafehouseClaim.keyFor(x, y, w, h)]
end

function IKST_SafehouseClaim.transmit()
    if IKST.transmitModData and IKST.ModDataKeys then
        IKST.transmitModData(IKST.ModDataKeys.SafehouseClaim)
    end
end

function IKST_SafehouseClaim.isEntryExpired(entry)
    return entry and IKST_ClaimPolicy.isExpired(entry.expiresAt)
end

function IKST_SafehouseClaim.ensureEntryShape(entry)
    entry.groups = entry.groups or IKST_SafehousePermissions.defaultGroups()
    entry.users = entry.users or {}
    if not entry.groups.everyone then
        entry.groups.everyone = IKST_SafehousePermissions.guestPermsFromSandbox()
    end
    if not entry.groups.member then
        entry.groups.member = IKST_SafehousePermissions.defaultGroups().member
    end
    if not entry.groups.faction then
        entry.groups.faction = IKST_SafehousePermissions.defaultGroups().faction
    end
    return entry
end

function IKST_SafehouseClaim.boundsFromSafehouse(sh)
    if not sh then
        return nil
    end
    local x = sh.getX and sh:getX() or nil
    local y = sh.getY and sh:getY() or nil
    local w = sh.getW and sh:getW() or nil
    local h = sh.getH and sh:getH() or nil
    local owner = sh.getOwner and sh:getOwner() or nil
    if x == nil or y == nil or not w or not h or w < 1 or h < 1 then
        return nil
    end
    return x, y, w, h, owner
end

function IKST_SafehouseClaim.safehouseAtSquare(square)
    if not IKST_SafeHouse then
        require "IKST_SafeHouse"
    end
    return IKST_SafeHouse.atSquare(square)
end

function IKST_SafehouseClaim.entryForSquare(square)
    local sh = IKST_SafehouseClaim.safehouseAtSquare(square)
    if not sh then
        return nil, nil
    end
    local x, y, w, h = IKST_SafehouseClaim.boundsFromSafehouse(sh)
    if not x then
        return nil, sh
    end
    return IKST_SafehouseClaim.get(x, y, w, h), sh
end

function IKST_SafehouseClaim.pointInside(x, y, bx, by, bw, bh)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    bx = math.floor(tonumber(bx) or 0)
    by = math.floor(tonumber(by) or 0)
    bw = math.floor(tonumber(bw) or 0)
    bh = math.floor(tonumber(bh) or 0)
    if bw < 1 or bh < 1 then
        return false
    end
    return x >= bx and x < bx + bw and y >= by and y < by + bh
end

function IKST_SafehouseClaim.ensureOnClaim(owner, x, y, w, h)
    if not owner or x == nil or y == nil then
        return false
    end
    w = math.floor(tonumber(w) or 0)
    h = math.floor(tonumber(h) or 0)
    if w < 1 or h < 1 then
        return false
    end
    local key = IKST_SafehouseClaim.keyFor(x, y, w, h)
    local existing = IKST_SafehouseClaim.store().byKey[key]
    if existing then
        return true
    end
    local meta = IKST_ClaimPolicy.getSafehouseMeta(x, y, w, h)
    local ownerKey = IKST_Identity.migrateOwnerField(owner)
    local entry = {
        key = key,
        owner = ownerKey,
        x = math.floor(x),
        y = math.floor(y),
        w = w,
        h = h,
        groups = IKST_SafehousePermissions.defaultGroups(),
        users = {},
        claimedAt = meta and meta.claimedAt or IKST_ClaimPolicy.nowHours(),
        expiresAt = meta and meta.expiresAt or IKST_ClaimPolicy.expiresAtFromNow(),
    }
    IKST_SafehouseClaim.ensureEntryShape(entry)
    IKST_SafehouseClaim.store().byKey[key] = entry
    IKST_SafehouseClaim.transmit()
    return true
end

function IKST_SafehouseClaim.release(x, y, w, h)
    local key = IKST_SafehouseClaim.keyFor(x, y, w, h)
    if IKST_SafehouseClaim.store().byKey[key] then
        IKST_SafehouseClaim.store().byKey[key] = nil
        IKST_SafehouseClaim.transmit()
        return true
    end
    return false
end

function IKST_SafehouseClaim.syncFromVanilla(sh)
    if not sh then
        return false
    end
    local x, y, w, h, owner = IKST_SafehouseClaim.boundsFromSafehouse(sh)
    if not x or not owner or owner == "" then
        return false
    end
    if IKST_SafehouseClaim.get(x, y, w, h) then
        return false
    end
    local meta = IKST_ClaimPolicy.getSafehouseMeta(x, y, w, h)
    if not meta then
        IKST_ClaimPolicy.recordSafehouseClaim(IKST_Identity.migrateOwnerField(owner), x, y, w, h)
    end
    return IKST_SafehouseClaim.ensureOnClaim(IKST_Identity.migrateOwnerField(owner), x, y, w, h)
end

function IKST_SafehouseClaim.setPermissions(x, y, w, h, scope, username, perms)
    local entry = IKST_SafehouseClaim.get(x, y, w, h)
    if not entry then
        return false, "not claimed"
    end
    IKST_SafehouseClaim.ensureEntryShape(entry)
    scope = tostring(scope or "")
    local ok, err = IKST_ClaimPolicy.canEditPermissionScope(scope, entry.users, username)
    if not ok then
        return false, err
    end
    if scope == IKST_SafehousePermissions.GROUP_EVERYONE
        or scope == IKST_SafehousePermissions.GROUP_MEMBER
        or scope == IKST_SafehousePermissions.GROUP_FACTION then
        entry.groups[scope] = IKST_SafehousePermissions.mergePerms(entry.groups[scope], perms)
        IKST_SafehouseClaim.transmit()
        return true, "group permissions saved"
    end
    if scope == "user" then
        local whitelistKey = IKST_Identity.resolveWhitelistKey(username)
        if not whitelistKey then
            return false, "username required"
        end
        local oldKey = IKST_ClaimPolicy.findUserKey(entry.users, whitelistKey)
        if oldKey and oldKey ~= whitelistKey then
            entry.users[oldKey] = nil
        end
        entry.users[whitelistKey] = IKST_SafehousePermissions.sanitizeUserPerms(
            IKST_SafehousePermissions.mergePerms(entry.users[whitelistKey], perms))
        IKST_SafehouseClaim.transmit()
        return true, "user permissions saved"
    end
    if scope == "remove_user" then
        username = IKST_ClaimPolicy.trimUsername(username)
        local key = IKST_ClaimPolicy.findUserKey(entry.users, username) or username
        entry.users[key] = nil
        IKST_SafehouseClaim.transmit()
        return true, "user removed"
    end
    return false, "invalid permission scope"
end

function IKST_SafehouseClaim.isOwner(entry, playerOrKey)
    if not entry or not playerOrKey then
        return false
    end
    if type(playerOrKey) == "table" and playerOrKey.getUsername then
        return IKST_Identity.playerOwnsKey(playerOrKey, entry.owner)
    end
    return IKST_ClaimPolicy.usernamesEqual(entry.owner, playerOrKey)
end

function IKST_SafehouseClaim.playerOwnerKey(player)
    return IKST_ClaimSocial.accountKey(player)
end

function IKST_SafehouseClaim.playerUsername(player)
    return IKST_ClaimSocial.username(player)
end

function IKST_SafehouseClaim.adminMayBypass(player)
    if not IKST_ClaimPolicy.adminBypass() then
        return false
    end
    return IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player)
end

function IKST_SafehouseClaim.playerMayEdit(entry, player)
    if not entry or not player then
        return false
    end
    if IKST_SafehouseClaim.adminMayBypass(player) then
        return true
    end
    return IKST_SafehouseClaim.isOwner(entry, player)
end

function IKST_SafehouseClaim.canAtCoords(player, x, y, z, action)
    if not player or not action then
        return nil
    end
    local square = nil
    if IKST_Grid and IKST_Grid.getSquare then
        square = IKST_Grid.getSquare(math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), tonumber(z) or 0)
    elseif player.getCurrentSquare then
        square = player:getCurrentSquare()
    end
    if not square then
        return nil
    end
    return IKST_SafehouseClaim.canAtSquare(player, square, action)
end

function IKST_SafehouseClaim.canAtSquare(player, square, action)
    if not player or not square or not action then
        return nil
    end
    local entry, sh = IKST_SafehouseClaim.entryForSquare(square)
    if not entry then
        return nil
    end
    if IKST_SafehouseClaim.isEntryExpired(entry) then
        return false
    end
    if IKST_SafehousePermissions.resolve(entry, player, action, sh) then
        return true
    end
    return false
end

function IKST_SafehouseClaim.refFromArgs(args)
    if not args then
        return nil
    end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local w = tonumber(args.w)
    local h = tonumber(args.h)
    if x == nil or y == nil or not w or not h then
        return nil
    end
    return x, y, w, h
end
