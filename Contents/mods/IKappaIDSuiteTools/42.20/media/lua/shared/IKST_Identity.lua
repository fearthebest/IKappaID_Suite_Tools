-- Stable player identity (Steam ID / SP local id) for claims, economy, and permissions.
-- Never use display name or username alone as authority in MP.

require "IKST_Shared"

IKST_Identity = IKST_Identity or {}

IKST_Identity.PREFIX_STEAM = "steam:"
IKST_Identity.PREFIX_LOCAL = "local:"
IKST_Identity.PREFIX_LEGACY = "user:"

IKST_Identity.MD_PLAYER_ID = "IKST_accountId"
IKST_Identity.MD_OWNER_KEY = "IKST_ownerKey"
IKST_Identity.MD_CARD_SERIAL = "IKST_cardSerial"


local function trim(s)
    if not s then
        return ""
    end
    return tostring(s):match("^%s*(.-)%s*$") or ""
end

function IKST_Identity.isAccountKey(value)
    local s = tostring(value or "")
    if s == "" then
        return false
    end
    return string.sub(s, 1, #IKST_Identity.PREFIX_STEAM) == IKST_Identity.PREFIX_STEAM
        or string.sub(s, 1, #IKST_Identity.PREFIX_LOCAL) == IKST_Identity.PREFIX_LOCAL
        or string.sub(s, 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY
end

function IKST_Identity.legacyKey(username)
    username = trim(username)
    if username == "" then
        return nil
    end
    return IKST_Identity.PREFIX_LEGACY .. string.lower(username)
end

function IKST_Identity.newLocalId()
    local n = ZombRand and ZombRand(100000000, 999999999) or 0
    local t = getTimeInMillis and getTimeInMillis() or 0
    return tostring(n) .. "-" .. tostring(t)
end

function IKST_Identity.steamId(player)
    if not player or not player.getSteamID then
        return nil
    end
    local id = player:getSteamID()
    if not id or id == "" or id == "0" then
        return nil
    end
    return tostring(id)
end

function IKST_Identity.username(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local u = player:getUsername()
        if u and u ~= "" then
            return u
        end
    end
    return nil
end

function IKST_Identity.displayLabel(player)
    local u = IKST_Identity.username(player)
    if u and u ~= "" then
        return u
    end
    if player and player.getOnlineID then
        return "Player " .. tostring(player:getOnlineID())
    end
    return "player"
end

function IKST_Identity.ensureLocalPlayerId(player)
    if not player or not player.getModData then
        return nil
    end
    local md = player:getModData()
    if not md then
        return nil
    end
    local id = md[IKST_Identity.MD_PLAYER_ID]
    if not id or id == "" then
        id = IKST_Identity.newLocalId()
        md[IKST_Identity.MD_PLAYER_ID] = id
        if player.transmitModData then
            player:transmitModData()
        end
    end
    return tostring(id)
end

function IKST_Identity.accountKey(player)
    if not player then
        return "local:anonymous"
    end
    local steam = IKST_Identity.steamId(player)
    if steam then
        return IKST_Identity.PREFIX_STEAM .. steam
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        local u = IKST_Identity.username(player)
        if u and u ~= "" then
            return IKST_Identity.legacyKey(u)
        end
        return "local:anonymous"
    end
    local localId = IKST_Identity.ensureLocalPlayerId(player)
    if localId and localId ~= "" then
        return IKST_Identity.PREFIX_LOCAL .. localId
    end
    return "local:anonymous"
end

function IKST_Identity.keysEqual(a, b)
    if not a or not b then
        return false
    end
    if tostring(a) == tostring(b) then
        return true
    end
    local sa = tostring(a)
    local sb = tostring(b)
    if string.sub(sa, 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY
        and string.sub(sb, 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY then
        return string.lower(string.sub(sa, #IKST_Identity.PREFIX_LEGACY + 1))
            == string.lower(string.sub(sb, #IKST_Identity.PREFIX_LEGACY + 1))
    end
    if not IKST_Identity.isAccountKey(sa) and not IKST_Identity.isAccountKey(sb) then
        return string.lower(sa) == string.lower(sb)
    end
    return false
end

function IKST_Identity.playerOwnsKey(player, storedKey)
    if not player or not storedKey or storedKey == "" then
        return false
    end
    local key = IKST_Identity.accountKey(player)
    if IKST_Identity.keysEqual(key, storedKey) then
        return true
    end
    local uname = IKST_Identity.username(player)
    if not uname or uname == "" then
        return false
    end
    if not IKST_Identity.isAccountKey(storedKey) then
        return string.lower(tostring(storedKey)) == string.lower(uname)
    end
    if string.sub(tostring(storedKey), 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY then
        local legacy = string.sub(tostring(storedKey), #IKST_Identity.PREFIX_LEGACY + 1)
        return string.lower(uname) == string.lower(legacy)
    end
    if string.sub(tostring(storedKey), 1, #IKST_Identity.PREFIX_STEAM) == IKST_Identity.PREFIX_STEAM then
        local mapped = IKST_Identity.keyForLegacyName(uname)
        if mapped and IKST_Identity.keysEqual(mapped, storedKey) then
            return true
        end
    end
    return false
end

function IKST_Identity.labelForKey(key)
    if not key or key == "" then
        return "?"
    end
    local online = IKST_Identity.findPlayerByAccountKey(key)
    if online then
        return IKST_Identity.displayLabel(online)
    end
    if string.sub(tostring(key), 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY then
        return string.sub(tostring(key), #IKST_Identity.PREFIX_LEGACY + 1)
    end
    if string.sub(tostring(key), 1, #IKST_Identity.PREFIX_STEAM) == IKST_Identity.PREFIX_STEAM then
        return string.sub(tostring(key), #IKST_Identity.PREFIX_STEAM + 1)
    end
    if string.sub(tostring(key), 1, #IKST_Identity.PREFIX_LOCAL) == IKST_Identity.PREFIX_LOCAL then
        return "SP " .. string.sub(tostring(key), #IKST_Identity.PREFIX_LOCAL + 1)
    end
    return tostring(key)
end

function IKST_Identity.iterOnlinePlayers(visitor)
    if not visitor then
        return
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size and list.get then
        for i = 0, list:size() - 1 do
            visitor(list:get(i))
        end
        return
    end
    if getSpecificPlayer then
        local p = getSpecificPlayer(0)
        if p then
            visitor(p)
        end
    end
end

function IKST_Identity.findPlayerByUsername(username)
    username = trim(username)
    if username == "" then
        return nil
    end
    local found = nil
    IKST_Identity.iterOnlinePlayers(function(p)
        if found then
            return
        end
        local u = IKST_Identity.username(p)
        if u and string.lower(u) == string.lower(username) then
            found = p
        end
    end)
    return found
end

function IKST_Identity.findPlayerByAccountKey(key)
    if not key or key == "" then
        return nil
    end
    local found = nil
    IKST_Identity.iterOnlinePlayers(function(p)
        if found then
            return
        end
        if IKST_Identity.playerOwnsKey(p, key) then
            found = p
        end
    end)
    return found
end

function IKST_Identity.resolveWhitelistKey(nameOrKey)
    nameOrKey = trim(nameOrKey)
    if nameOrKey == "" then
        return nil
    end
    if IKST_Identity.isAccountKey(nameOrKey) then
        return nameOrKey
    end
    local online = IKST_Identity.findPlayerByUsername(nameOrKey)
    if online then
        return IKST_Identity.accountKey(online)
    end
    return IKST_Identity.legacyKey(nameOrKey)
end

function IKST_Identity.findUserPerms(users, player)
    if not users or not player then
        return nil, nil
    end
    local key = IKST_Identity.accountKey(player)
    if key and users[key] then
        return users[key], key
    end
    for storedKey, perms in pairs(users) do
        if IKST_Identity.playerOwnsKey(player, storedKey) then
            return perms, storedKey
        end
    end
    return nil, nil
end

function IKST_Identity.findUserKey(users, nameOrKey)
    if not users or not nameOrKey or nameOrKey == "" then
        return nil
    end
    if users[nameOrKey] ~= nil then
        return nameOrKey
    end
    local resolved = IKST_Identity.resolveWhitelistKey(nameOrKey)
    if resolved and users[resolved] ~= nil then
        return resolved
    end
    local lower = string.lower(tostring(nameOrKey))
    for key in pairs(users) do
        if string.lower(tostring(key)) == lower then
            return key
        end
        if IKST_Identity.keysEqual(key, resolved) then
            return key
        end
    end
    return nil
end

function IKST_Identity.identityMapStore()
    if not ModData or not ModData.getOrCreate then
        return nil
    end
    local data = ModData.getOrCreate("IKST_Identity")
    if not data.nameToKey then
        data.nameToKey = {}
    end
    return data
end

function IKST_Identity.registerPlayerMapping(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local store = IKST_Identity.identityMapStore()
    if not store then
        return
    end
    local u = IKST_Identity.username(player)
    local key = IKST_Identity.accountKey(player)
    if u and u ~= "" and key then
        store.nameToKey[string.lower(u)] = key
    end
end

function IKST_Identity.keyForLegacyName(name)
    name = trim(name)
    if name == "" then
        return nil
    end
    local store = IKST_Identity.identityMapStore()
    if store and store.nameToKey then
        local mapped = store.nameToKey[string.lower(name)]
        if mapped and mapped ~= "" then
            return mapped
        end
    end
    local online = IKST_Identity.findPlayerByUsername(name)
    if online then
        return IKST_Identity.accountKey(online)
    end
    return IKST_Identity.legacyKey(name)
end

function IKST_Identity.migrateOwnerField(owner)
    if not owner or owner == "" then
        return owner
    end
    if IKST_Identity.isAccountKey(owner) then
        return owner
    end
    local mapped = IKST_Identity.keyForLegacyName(owner)
    return mapped or IKST_Identity.legacyKey(owner)
end

function IKST_Identity.migratePlayerOnConnect(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    IKST_Identity.registerPlayerMapping(player)
    local key = IKST_Identity.accountKey(player)
    local uname = IKST_Identity.username(player)

    if IKST_EconomyIdentity and IKST_EconomyIdentity.migratePlayerAccounts then
        IKST_EconomyIdentity.migratePlayerAccounts(player, key, uname)
    end
    if IKST_VehicleClaim and IKST_VehicleClaim.store then
        local data = IKST_VehicleClaim.store()
        if data and data.byId then
            for _, entry in pairs(data.byId) do
                if entry and entry.owner then
                    local owns = IKST_Identity.playerOwnsKey(player, entry.owner)
                    if not owns and uname and not IKST_Identity.isAccountKey(entry.owner) then
                        owns = string.lower(tostring(entry.owner)) == string.lower(uname)
                    end
                    if owns and key and key ~= "" and not IKST_Identity.keysEqual(entry.owner, key) then
                        local oldOwner = entry.owner
                        entry.owner = key
                        if IKST_VehicleClaim.removeFromOwnerList and IKST_VehicleClaim.addToOwnerList then
                            IKST_VehicleClaim.removeFromOwnerList(oldOwner, tostring(entry.id))
                            IKST_VehicleClaim.addToOwnerList(key, tostring(entry.id))
                        end
                    end
                end
            end
            if IKST_VehicleClaim.transmit then
                IKST_VehicleClaim.transmit()
            end
        end
    end

    if IKST_SafehouseClaim and IKST_SafehouseClaim.store then
        local shData = IKST_SafehouseClaim.store()
        if shData and shData.byKey then
            for _, entry in pairs(shData.byKey) do
                if entry and entry.owner then
                    local owns = IKST_Identity.playerOwnsKey(player, entry.owner)
                    if not owns and uname and not IKST_Identity.isAccountKey(entry.owner) then
                        owns = string.lower(tostring(entry.owner)) == string.lower(uname)
                    end
                    if owns and key and key ~= "" and not IKST_Identity.keysEqual(entry.owner, key) then
                        entry.owner = key
                    end
                end
            end
            if IKST_SafehouseClaim.transmit then
                IKST_SafehouseClaim.transmit()
            end
        end
    end

    if IKST_ClaimPolicy and IKST_ClaimPolicy.safehouseMetaStore then
        local meta = IKST_ClaimPolicy.safehouseMetaStore()
        for _, row in pairs(meta) do
            if row and row.owner and not IKST_Identity.isAccountKey(row.owner) then
                if IKST_Identity.playerOwnsKey(player, row.owner)
                    or (uname and string.lower(tostring(row.owner)) == string.lower(uname)) then
                    row.owner = key
                end
            end
        end
        if IKST.transmitModData and IKST.ModDataKeys then
            IKST.transmitModData(IKST.ModDataKeys.WorldRules)
        end
    end
end
