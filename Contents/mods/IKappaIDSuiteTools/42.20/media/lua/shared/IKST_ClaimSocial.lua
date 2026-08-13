-- Safehouse / faction helpers for claim permissions (server + client read).

require "IKST_Shared"
require "IKST_ClaimPolicy"

IKST_ClaimSocial = IKST_ClaimSocial or {}

function IKST_ClaimSocial.accountKey(player)
    if IKST_Identity and IKST_Identity.accountKey then
        return IKST_Identity.accountKey(player)
    end
    return IKST_ClaimSocial.username(player)
end

function IKST_ClaimSocial.username(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    return nil
end

function IKST_ClaimSocial.iterSafehouses(visitor)
    if not SafeHouse or not SafeHouse.getSafehouseList or not visitor then
        return
    end
    local list = SafeHouse.getSafehouseList()
    if not list then
        return
    end
    if list.size and list.get then
        for i = 0, list:size() - 1 do
            visitor(list:get(i))
        end
        return
    end
    if type(list) == "table" then
        for _, sh in ipairs(list) do
            visitor(sh)
        end
    end
end

function IKST_ClaimSocial.safehouseOwner(sh)
    if not sh or not sh.getOwner then
        return nil
    end
    return sh:getOwner()
end

function IKST_ClaimSocial.safehouseHasMember(sh, username)
    if not sh or not username or username == "" or not sh.getPlayers then
        return false
    end
    local players = sh:getPlayers()
    if not players then
        return false
    end
    if players.size and players.get then
        for i = 0, players:size() - 1 do
            local member = players:get(i)
            if member and IKST_ClaimPolicy.usernamesEqual(member, username) then
                return true
            end
        end
        return false
    end
    if type(players) == "table" then
        for _, member in ipairs(players) do
            if IKST_ClaimPolicy.usernamesEqual(member, username) then
                return true
            end
        end
    end
    return false
end

function IKST_ClaimSocial.userInSafehouseOwnedBy(user, ownerKey)
    if not user or not ownerKey or ownerKey == "" then
        return false
    end
    local ownerName = IKST_Identity and IKST_Identity.labelForKey(ownerKey) or ownerKey
    local found = false
    IKST_ClaimSocial.iterSafehouses(function(sh)
        if found then
            return
        end
        local shOwner = IKST_ClaimSocial.safehouseOwner(sh)
        if IKST_ClaimPolicy.usernamesEqual(shOwner, ownerName)
            and IKST_ClaimSocial.safehouseHasMember(sh, user) then
            found = true
        end
    end)
    return found
end

function IKST_ClaimSocial.sameFaction(user, ownerKey)
    if not Faction or not Faction.getPlayerFaction or not user or not ownerKey then
        return false
    end
    local ownerName = IKST_Identity and IKST_Identity.labelForKey(ownerKey) or ownerKey
    local userFaction = Faction.getPlayerFaction(user)
    local ownerFaction = Faction.getPlayerFaction(ownerName)
    if not userFaction or not ownerFaction then
        return false
    end
    return userFaction == ownerFaction
end

function IKST_ClaimSocial.membersList(sh)
    local out = {}
    if not sh or not sh.getPlayers then
        return out
    end
    local players = sh:getPlayers()
    if players and players.size and players.get then
        for i = 0, players:size() - 1 do
            local member = players:get(i)
            if member and member ~= "" then
                out[#out + 1] = tostring(member)
            end
        end
    elseif type(players) == "table" then
        for _, member in ipairs(players) do
            if member and member ~= "" then
                out[#out + 1] = tostring(member)
            end
        end
    end
    return out
end
