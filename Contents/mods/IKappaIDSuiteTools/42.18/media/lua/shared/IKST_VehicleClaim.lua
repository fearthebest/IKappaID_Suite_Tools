-- Vehicle ownership claims (server-authoritative ModData).

require "IKST_Shared"
require "IKST_Authority"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"
require "IKST_VehiclePermissions"
require "IKST_ModDataSync"
require "IKST_Access"

IKST_VehicleClaim = IKST_VehicleClaim or {}

function IKST_VehicleClaim.store()
    local data = ModData.getOrCreate("IKST_VehicleClaim")
    data.byId = data.byId or {}
    data.byOwner = data.byOwner or {}
    return data
end

function IKST_VehicleClaim.get(vehicleId)
    if vehicleId == nil then
        return nil
    end
    return IKST_VehicleClaim.store().byId[tostring(vehicleId)]
end

function IKST_VehicleClaim.maxClaimsForOwner()
    if IKST_ClaimPolicy and IKST_ClaimPolicy.maxVehicleClaims then
        return IKST_ClaimPolicy.maxVehicleClaims()
    end
    return 3
end

function IKST_VehicleClaim.ownerCount(username)
    if not username then
        return 0
    end
    IKST_VehicleClaim.purgeExpired()
    local listKey = IKST_VehicleClaim.ownerListKey(username)
    local list = listKey and IKST_VehicleClaim.store().byOwner[listKey]
    if not list then
        return 0
    end
    return #list
end

function IKST_VehicleClaim.ownerListKey(username)
    if not username or username == "" then
        return nil
    end
    local data = IKST_VehicleClaim.store()
    for key in pairs(data.byOwner) do
        if IKST_ClaimPolicy.usernamesEqual(key, username) then
            return key
        end
    end
    return IKST_ClaimPolicy.trimUsername(username)
end

function IKST_VehicleClaim.removeFromOwnerList(username, vehicleKey)
    local listKey = IKST_VehicleClaim.ownerListKey(username)
    local list = listKey and IKST_VehicleClaim.store().byOwner[listKey]
    if not list then
        return
    end
    for i, id in ipairs(list) do
        if id == vehicleKey then
            table.remove(list, i)
            break
        end
    end
    if #list == 0 then
        IKST_VehicleClaim.store().byOwner[listKey] = nil
    end
end

function IKST_VehicleClaim.addToOwnerList(username, vehicleKey)
    if not username or username == "" then
        return
    end
    local listKey = IKST_VehicleClaim.ownerListKey(username)
    local data = IKST_VehicleClaim.store()
    data.byOwner[listKey] = data.byOwner[listKey] or {}
    local list = data.byOwner[listKey]
    for _, id in ipairs(list) do
        if id == vehicleKey then
            return
        end
    end
    list[#list + 1] = vehicleKey
end

function IKST_VehicleClaim.transmit()
    if IKST.transmitModData and IKST.ModDataKeys then
        IKST.transmitModData(IKST.ModDataKeys.VehicleClaim)
    end
end

function IKST_VehicleClaim.isEntryExpired(entry)
    return entry and IKST_ClaimPolicy.isExpired(entry.expiresAt)
end

function IKST_VehicleClaim.purgeExpired()
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return 0
    end
    local data = IKST_VehicleClaim.store()
    local removed = {}
    for k, entry in pairs(data.byId) do
        if IKST_VehicleClaim.isEntryExpired(entry) then
            removed[#removed + 1] = k
        end
    end
    for _, k in ipairs(removed) do
        local entry = data.byId[k]
        data.byId[k] = nil
        if entry and entry.owner then
            IKST_VehicleClaim.removeFromOwnerList(entry.owner, k)
        end
    end
    if #removed > 0 then
        IKST_VehicleClaim.transmit()
    end
    return #removed
end

function IKST_VehicleClaim.atMaxClaims(username)
    local max = IKST_VehicleClaim.maxClaimsForOwner()
    if max <= 0 then
        return false
    end
    return IKST_VehicleClaim.ownerCount(username) >= max
end

function IKST_VehicleClaim.ensureEntryShape(entry)
    entry.groups = entry.groups or IKST_VehiclePermissions.defaultGroups()
    entry.users = entry.users or {}
    if not entry.groups.everyone then
        entry.groups.everyone = IKST_VehiclePermissions.guestPermsFromSandbox()
    end
    if not entry.groups.safehouse then
        entry.groups.safehouse = IKST_VehiclePermissions.defaultGroups().safehouse
    end
    if not entry.groups.faction then
        entry.groups.faction = IKST_VehiclePermissions.defaultGroups().faction
    end
    return entry
end

function IKST_VehicleClaim.claim(vehicleId, ownerKey, meta)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    IKST_VehicleClaim.purgeExpired()
    if not vehicleId then
        return false, "no vehicle selected"
    end
    ownerKey = ownerKey or ""
    if ownerKey == "" then
        return false, "no owner"
    end
    if not IKST_Identity.isAccountKey(ownerKey) then
        ownerKey = IKST_Identity.migrateOwnerField(ownerKey)
    end
    local k = tostring(vehicleId)
    if IKST_VehicleClaim.get(k) then
        return false, "already claimed"
    end
    if IKST_VehicleClaim.atMaxClaims(ownerKey) then
        return false, "max vehicle claims"
    end
    meta = meta or {}
    local entry = {
        id = tonumber(vehicleId) or vehicleId,
        owner = ownerKey,
        label = meta.label or "",
        script = meta.script or "",
        x = meta.x,
        y = meta.y,
        z = meta.z,
        groups = IKST_VehiclePermissions.defaultGroups(),
        users = {},
        claimedAt = IKST_ClaimPolicy.nowHours(),
        expiresAt = IKST_ClaimPolicy.expiresAtFromNow(),
    }
    IKST_VehicleClaim.ensureEntryShape(entry)
    local data = IKST_VehicleClaim.store()
    data.byId[k] = entry
    IKST_VehicleClaim.addToOwnerList(ownerKey, k)
    IKST_VehicleClaim.transmit()
    return true, "claimed"
end

function IKST_VehicleClaim.release(vehicleId)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    local k = tostring(vehicleId)
    local entry = IKST_VehicleClaim.get(k)
    if not entry then
        return false, "not claimed"
    end
    local data = IKST_VehicleClaim.store()
    data.byId[k] = nil
    IKST_VehicleClaim.removeFromOwnerList(entry.owner, k)
    IKST_VehicleClaim.transmit()
    return true, "released"
end

-- After admin relocate respawns the vehicle with a new engine id, keep the claim row.
function IKST_VehicleClaim.remapVehicleId(oldId, newId, coords)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false
    end
    if oldId == nil or newId == nil then
        return false
    end
    local oldKey = tostring(oldId)
    local newKey = tostring(newId)
    if oldKey == newKey then
        return true
    end
    local entry = IKST_VehicleClaim.get(oldKey)
    if not entry then
        return false
    end
    local data = IKST_VehicleClaim.store()
    entry.id = tonumber(newId) or newId
    if coords then
        entry.x = coords.x
        entry.y = coords.y
        entry.z = coords.z
    end
    data.byId[oldKey] = nil
    data.byId[newKey] = entry
    IKST_VehicleClaim.removeFromOwnerList(entry.owner, oldKey)
    IKST_VehicleClaim.addToOwnerList(entry.owner, newKey)
    IKST_VehicleClaim.transmit()
    return true
end

function IKST_VehicleClaim.transfer(vehicleId, newOwner)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not newOwner or newOwner == "" then
        return false, "no new owner"
    end
    if not IKST_Identity.isAccountKey(newOwner) then
        newOwner = IKST_Identity.migrateOwnerField(newOwner)
    end
    IKST_VehicleClaim.purgeExpired()
    local k = tostring(vehicleId)
    local entry = IKST_VehicleClaim.get(k)
    if not entry then
        return false, "not claimed"
    end
    if entry and IKST_ClaimPolicy.usernamesEqual(entry.owner, newOwner) then
        return false, "same owner"
    end
    if IKST_VehicleClaim.atMaxClaims(newOwner) then
        return false, "max claims"
    end
    local oldOwner = entry.owner
    entry.owner = newOwner
    IKST_VehicleClaim.removeFromOwnerList(oldOwner, k)
    IKST_VehicleClaim.addToOwnerList(entry.owner, k)
    IKST_VehicleClaim.transmit()
    return true, "transferred"
end

function IKST_VehicleClaim.setLabel(vehicleId, label)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    local entry = IKST_VehicleClaim.get(vehicleId)
    if not entry then
        return false, "not claimed"
    end
    entry.label = label or ""
    IKST_VehicleClaim.transmit()
    return true, "label set"
end

function IKST_VehicleClaim.setPermissions(vehicleId, scope, username, perms)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    local entry = IKST_VehicleClaim.get(vehicleId)
    if not entry then
        return false, "not claimed"
    end
    IKST_VehicleClaim.ensureEntryShape(entry)
    scope = tostring(scope or "")
    local ok, err = IKST_ClaimPolicy.canEditPermissionScope(scope, entry.users, username)
    if not ok then
        return false, err
    end
    if scope == IKST_VehiclePermissions.GROUP_EVERYONE
        or scope == IKST_VehiclePermissions.GROUP_SAFEHOUSE
        or scope == IKST_VehiclePermissions.GROUP_FACTION then
        entry.groups[scope] = IKST_VehiclePermissions.mergePerms(entry.groups[scope], perms)
        IKST_VehicleClaim.transmit()
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
        entry.users[whitelistKey] = IKST_VehiclePermissions.sanitizeUserPerms(
            IKST_VehiclePermissions.mergePerms(entry.users[whitelistKey], perms))
        IKST_VehicleClaim.transmit()
        return true, "user permissions saved"
    end
    if scope == "remove_user" then
        username = IKST_ClaimPolicy.trimUsername(username)
        local key = IKST_ClaimPolicy.findUserKey(entry.users, username) or username
        entry.users[key] = nil
        IKST_VehicleClaim.transmit()
        return true, "user removed"
    end
    return false, "invalid permission scope"
end

function IKST_VehicleClaim.isOwner(entry, playerOrKey)
    if not entry or not playerOrKey then
        return false
    end
    if type(playerOrKey) == "table" and playerOrKey.getUsername then
        return IKST_Identity.playerOwnsKey(playerOrKey, entry.owner)
    end
    return IKST_ClaimPolicy.usernamesEqual(entry.owner, playerOrKey)
end

-- True when this vehicle id is on the player's server owner list (listForOwner index).
function IKST_VehicleClaim.playerListedClaim(player, vehicleId)
    if not player or vehicleId == nil then
        return false
    end
    if not IKST_Identity or type(IKST_Identity.accountKey) ~= "function" then
        return false
    end
    local ownerKey = IKST_Identity.accountKey(player)
    local listKey = IKST_VehicleClaim.ownerListKey(ownerKey)
    local list = listKey and IKST_VehicleClaim.store().byOwner[listKey]
    if not list then
        return false
    end
    local want = tostring(vehicleId)
    for _, id in ipairs(list) do
        if tostring(id) == want then
            return true
        end
    end
    return false
end

function IKST_VehicleClaim.playerMayRelease(entry, player, vehicleId)
    if not player then
        return false
    end
    if IKST_VehicleClaim.adminMayBypass(player) then
        return true
    end
    if not entry then
        return false
    end
    if IKST_VehicleClaim.playerMayEdit(entry, player) then
        return true
    end
    if vehicleId ~= nil and IKST_VehicleClaim.playerListedClaim(player, vehicleId) then
        return true
    end
    return false
end

function IKST_VehicleClaim.playerOwnerKey(player)
    return IKST_ClaimSocial.accountKey(player)
end

function IKST_VehicleClaim.playerUsername(player)
    return IKST_ClaimSocial.username(player)
end

function IKST_VehicleClaim.adminMayBypass(player)
    if not IKST_ClaimPolicy.adminBypass() then
        return false
    end
    return IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player)
end

function IKST_VehicleClaim.canUseVehicle(player, vehicle, action)
    if not player or not vehicle or not action then
        return true
    end
    local vid = vehicle.getId and vehicle:getId() or nil
    if vid == nil then
        return true
    end
    local entry = IKST_VehicleClaim.get(vid)
    if not entry or IKST_VehicleClaim.isEntryExpired(entry) then
        if IKST_Authority and IKST_Authority.mpClientEnforcementActive and IKST_Authority.mpClientEnforcementActive() then
            if IKST_VehicleClaimClient and not IKST_VehicleClaimClient.listBootstrapped then
                return false
            end
            if IKST_VehicleClaimClient and IKST_VehicleClaimClient.rowForVehicle then
                local row = IKST_VehicleClaimClient.rowForVehicle(vid)
                if row and row.claimed == true then
                    return false
                end
            end
        end
        return true
    end
    return IKST_VehiclePermissions.resolve(entry, player, action)
end

function IKST_VehicleClaim.isClaimedByOther(vehicleId, playerOrKey)
    local entry = IKST_VehicleClaim.get(vehicleId)
    if not entry or IKST_VehicleClaim.isEntryExpired(entry) then
        return false
    end
    if not playerOrKey then
        return true
    end
    return not IKST_VehicleClaim.isOwner(entry, playerOrKey)
end

function IKST_VehicleClaim.listForOwner(ownerKey)
    IKST_VehicleClaim.purgeExpired()
    local out = {}
    local listKey = IKST_VehicleClaim.ownerListKey(ownerKey)
    local list = listKey and IKST_VehicleClaim.store().byOwner[listKey]
    if not list then
        return out
    end
    for _, id in ipairs(list) do
        local entry = IKST_VehicleClaim.get(id)
        if entry then
            out[#out + 1] = entry
        end
    end
    return out
end

function IKST_VehicleClaim.listAll()
    IKST_VehicleClaim.purgeExpired()
    local out = {}
    for _, entry in pairs(IKST_VehicleClaim.store().byId) do
        out[#out + 1] = entry
    end
    return out
end

function IKST_VehicleClaim.entryForDisplay(vehicleId)
    local entry = IKST_VehicleClaim.get(vehicleId)
    if not entry then
        return nil
    end
    if IKST_Authority and IKST_Authority.guardServerMutate() then
        IKST_VehicleClaim.ensureEntryShape(entry)
        return entry
    end
    local plain = IKST_VehicleClaim.copyEntryPlain(entry)
    IKST_VehicleClaim.ensureEntryShape(plain)
    return plain
end

function IKST_VehicleClaim.copyEntryPlain(entry)
    if not entry then
        return nil
    end
    local out = {
        id = entry.id,
        owner = entry.owner,
        label = entry.label or "",
        script = entry.script or "",
        x = entry.x,
        y = entry.y,
        z = entry.z,
        claimedAt = entry.claimedAt,
        expiresAt = entry.expiresAt,
        groups = {},
        users = {},
    }
    if entry.groups then
        for key, value in pairs(entry.groups) do
            out.groups[key] = value
        end
    end
    if entry.users then
        for key, value in pairs(entry.users) do
            out.users[key] = value
        end
    end
    return out
end

function IKST_VehicleClaim.claimLabel(entry)
    if not entry then
        return ""
    end
    local ownerLabel = (IKST_Identity and IKST_Identity.labelForKey and IKST_Identity.labelForKey(entry.owner)) or entry.owner
    local s = "[" .. tostring(ownerLabel or "?")
    if entry.label and entry.label ~= "" then
        s = s .. ": " .. entry.label
    elseif entry.script and entry.script ~= "" then
        s = s .. ": " .. entry.script
    end
    if entry.expiresAt then
        s = s .. " exp:" .. tostring(math.floor(entry.expiresAt))
    end
    return s .. "]"
end

function IKST_VehicleClaim.vehicleFromContainer(container)
    if not container or not container.getParent then
        return nil
    end
    local parent = container:getParent()
    if not parent then
        return nil
    end
    if parent.getVehicle and parent:getVehicle() then
        return parent:getVehicle()
    end
    if instanceof and instanceof(parent, "BaseVehicle") then
        return parent
    end
    return nil
end

function IKST_VehicleClaim.transferAllowed(item, srcContainer, destContainer, player)
    if not player then
        return true
    end
    local function check(container)
        local vehicle = IKST_VehicleClaim.vehicleFromContainer(container)
        if vehicle and not IKST_VehicleClaim.canUseVehicle(player, vehicle, "loot") then
            return false
        end
        return true
    end
    if srcContainer and not check(srcContainer) then
        return false
    end
    if destContainer and not check(destContainer) then
        return false
    end
    return true
end

function IKST_VehicleClaim.playerMayEdit(entry, player)
    if not entry or not player then
        return false
    end
    if IKST_VehicleClaim.adminMayBypass(player) then
        return true
    end
    return IKST_VehicleClaim.isOwner(entry, player)
end
