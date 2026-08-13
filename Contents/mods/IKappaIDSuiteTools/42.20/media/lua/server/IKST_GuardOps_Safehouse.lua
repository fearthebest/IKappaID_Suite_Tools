-- Safehouse claim helpers (split from IKST_GuardOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Args"
require "IKST_Claim"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"
require "IKST_Identity"
require "IKST_WorldOps"
require "IKST_StaffOps"
require "IKST_SafehouseClaim"
require "IKST_SafehousePermissions"
require "IKST_PhunZones"
require "IKST_SafeHouse"
require "IKST_ModDataSync"
require "IKST_Policy"

IKST_GuardOps = IKST_GuardOps or {}

function IKST_GuardOps.safehouseAt(x, y, z, w, h)
    return IKST_SafeHouse.atRect(x, y, z, w, h)
end

function IKST_GuardOps.iterSafehouses(visitor)
    IKST_SafeHouse.iter(visitor)
end

function IKST_GuardOps.safehouseToTable(sh)
    if not sh then
        return nil
    end
    if IKST_SafehouseClaim and IKST_SafehouseClaim.syncFromVanilla then
        IKST_SafehouseClaim.syncFromVanilla(sh)
    end
    local x = type(sh.getX) == "function" and sh:getX() or 0
    local y = type(sh.getY) == "function" and sh:getY() or 0
    local w = type(sh.getW) == "function" and sh:getW() or 0
    local h = type(sh.getH) == "function" and sh:getH() or 0
    local meta = IKST_ClaimPolicy.getSafehouseMeta(x, y, w, h)
    local entry = IKST_SafehouseClaim.get(x, y, w, h)
    local expiresAt = meta and meta.expiresAt or nil
    if entry and entry.expiresAt then
        expiresAt = entry.expiresAt
    end
    return {
        id = IKST_SafeHouse.onlineId(sh) or IKST_SafeHouse.id(sh),
        owner = type(sh.getOwner) == "function" and sh:getOwner() or "?",
        x = x,
        y = y,
        w = w,
        h = h,
        title = type(sh.getTitle) == "function" and sh:getTitle() or "",
        expiresAt = expiresAt,
        members = IKST_ClaimSocial.membersList(sh),
    }
end

function IKST_GuardOps.clearSafehouseClaimData(x, y, w, h)
    if not x or not y or not w or not h then
        return
    end
    IKST_SafehouseClaim.release(x, y, w, h)
    IKST_ClaimPolicy.safehouseMetaStore()[IKST_ClaimPolicy.safehouseMetaKey(x, y, w, h)] = nil
    if IKST.transmitModData and IKST.ModDataKeys then
        IKST.transmitModData(IKST.ModDataKeys.WorldRules)
        IKST.transmitModData(IKST.ModDataKeys.SafehouseClaim)
    end
end

function IKST_GuardOps.countSafehousesForOwner(ownerOrPlayer)
    if not ownerOrPlayer or ownerOrPlayer == "" then
        return 0
    end
    local ownerName = ownerOrPlayer
    local ownerKey = nil
    if type(ownerOrPlayer) == "table" and ownerOrPlayer.getUsername then
        ownerName = IKST_GuardOps.username(ownerOrPlayer)
        ownerKey = IKST_Identity.accountKey(ownerOrPlayer)
    elseif IKST_Identity.isAccountKey(ownerOrPlayer) then
        ownerKey = ownerOrPlayer
        ownerName = IKST_Identity.labelForKey(ownerKey)
    end
    local count = 0
    IKST_GuardOps.iterSafehouses(function(sh)
        local row = IKST_GuardOps.safehouseToTable(sh)
        if row then
            local match = IKST_ClaimPolicy.usernamesEqual(row.owner, ownerName)
            if not match and ownerKey then
                match = IKST_ClaimPolicy.usernamesEqual(row.owner, ownerKey)
            end
            if match and not IKST_ClaimPolicy.isExpired(row.expiresAt) then
                count = count + 1
            end
        end
    end)
    return count
end

function IKST_GuardOps.atMaxSafehouseClaims(owner)
    local max = IKST_ClaimPolicy.maxSafehouseClaims()
    if max <= 0 then
        return false
    end
    return IKST_GuardOps.countSafehousesForOwner(owner) >= max
end

function IKST_GuardOps.purgeExpiredSafehouses()
    if not SafeHouse then
        return 0
    end
    local removed = 0
    local toRemove = {}
    IKST_GuardOps.iterSafehouses(function(sh)
        local row = IKST_GuardOps.safehouseToTable(sh)
        if row and IKST_ClaimPolicy.isExpired(row.expiresAt) then
            toRemove[#toRemove + 1] = sh
        end
    end)
    for _, sh in ipairs(toRemove) do
        local sx = type(sh.getX) == "function" and sh:getX() or nil
        local sy = type(sh.getY) == "function" and sh:getY() or nil
        local sw = type(sh.getW) == "function" and sh:getW() or nil
        local shh = type(sh.getH) == "function" and sh:getH() or nil
        if IKST_GuardOps.removeSafehouseInstance(sh, nil, true) then
            if sx and sy and sw and shh then
                IKST_GuardOps.clearSafehouseClaimData(sx, sy, sw, shh)
            end
            removed = removed + 1
        end
    end
    if removed > 0 and IKST.transmitModData and IKST.ModDataKeys then
        IKST.transmitModData(IKST.ModDataKeys.WorldRules)
    end
    return removed
end

function IKST_GuardOps.rowIncludesPlayer(row, username, ownerKey)
    if not row then
        return false
    end
    if IKST_ClaimPolicy.usernamesEqual(row.owner, username) then
        return true
    end
    if ownerKey and IKST_ClaimPolicy.usernamesEqual(row.owner, ownerKey) then
        return true
    end
    local members = row.members
    if type(members) ~= "table" then
        return false
    end
    for _, member in ipairs(members) do
        if IKST_ClaimPolicy.usernamesEqual(member, username) then
            return true
        end
        if ownerKey and IKST_ClaimPolicy.usernamesEqual(member, ownerKey) then
            return true
        end
    end
    return false
end

function IKST_GuardOps.filterSafehousesForPlayer(list, playerOrName)
    local username = nil
    local ownerKey = nil
    if playerOrName and type(playerOrName) == "table" and playerOrName.getUsername then
        username = IKST_GuardOps.username(playerOrName)
        if IKST_Identity and IKST_Identity.accountKey then
            ownerKey = IKST_Identity.accountKey(playerOrName)
        end
    else
        username = tostring(playerOrName or "")
    end
    local out = {}
    for _, row in ipairs(list or {}) do
        if IKST_GuardOps.rowIncludesPlayer(row, username, ownerKey) then
            out[#out + 1] = row
        end
    end
    return out
end

function IKST_GuardOps.safehouseRowForViewer(row, viewer)
    if not row then
        return nil
    end
    local out = {
        id = row.id,
        owner = row.owner,
        x = row.x,
        y = row.y,
        w = row.w,
        h = row.h,
        title = row.title or "",
        expiresAt = row.expiresAt,
        members = row.members,
        claimed = true,
    }
    local entry = nil
    if row.x and row.y and row.w and row.h then
        entry = IKST_SafehouseClaim.get(row.x, row.y, row.w, row.h)
    end
    local isOwner = IKST_ClaimPolicy.usernamesEqual(row.owner, IKST_GuardOps.username(viewer))
    if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
        isOwner = isOwner or IKST_SafehouseClaim.isOwner(entry, viewer)
    end
    out.isMine = isOwner
    out.canRelease = IKST_GuardOps.actorIsAdmin(viewer) or isOwner
    out.canEdit = out.canRelease and (
        IKST_GuardOps.actorIsAdmin(viewer)
        or (entry and IKST_SafehouseClaim.playerMayEdit(entry, viewer))
        or isOwner
    )
    out.hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(row.expiresAt or (entry and entry.expiresAt))
    out.respawnAllowed = IKST_ClaimPolicy.safehouseRespawnAllowed()
    out.respawnOn = false
    out.canRespawn = false
    if out.respawnAllowed then
        local sh = IKST_GuardOps.findSafehouseEntry({
            x = row.x, y = row.y, w = row.w, h = row.h, id = row.id, owner = row.owner,
        }, viewer)
        if sh and IKST_GuardOps.playerMaySetRespawn(sh, viewer) then
            out.canRespawn = true
            local uname = IKST_GuardOps.username(viewer)
            if uname and type(sh.isRespawnInSafehouse) == "function" then
                out.respawnOn = sh:isRespawnInSafehouse(uname) == true
            end
        end
    end
    return out
end

function IKST_GuardOps.afterSafehouseClaimMutation(actor, action, x, y, w, h)
    if not action or x == nil or y == nil or not w or not h then
        return
    end
    local mirrorArgs = {
        action = action,
        x = x,
        y = y,
        w = w,
        h = h,
    }
    if action == "set" then
        local entry = IKST_SafehouseClaim.get(x, y, w, h)
        if entry then
            mirrorArgs.entry = IKST_SafehouseClaim.copyEntryPlain(entry)
        end
    end
    IKST_GuardOps.broadcastSafehouseClaimMirror(actor, mirrorArgs)
end

function IKST_GuardOps.broadcastSafehouseClaimMirror(actor, mirrorArgs)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST_StaffOps or not IKST_StaffOps.forEachOnline then
        return
    end
    IKST_StaffOps.forEachOnline(function(p)
        IKST.deliverClientCommand(p, IKST.CMD.safehouseClaimMirror, mirrorArgs or {})
    end)
end

function IKST_GuardOps.finishSafehouseClaimCommand(actor, ok, msg, x, y, w, h, action)
    if ok and x and action then
        IKST_GuardOps.afterSafehouseClaimMutation(actor, action, x, y, w, h)
    end
    return ok, msg
end


function IKST_GuardOps.removeSafehouseInstance(sh, actor, force)
    return IKST_SafeHouse.remove(sh, actor, force)
end

function IKST_GuardOps.findSafehouseEntry(entry, actor)
    return IKST_SafeHouse.find(entry, actor)
end

function IKST_GuardOps.listSafehouses()
    local out = {}
    IKST_GuardOps.iterSafehouses(function(sh)
        out[#out + 1] = IKST_GuardOps.safehouseToTable(sh)
    end)
    return out
end

function IKST_GuardOps.releaseSafehouse(owner, x, y, w, h, id, actor)
    if not SafeHouse then
        return false, "no SafeHouse API"
    end
    local sh = IKST_GuardOps.findSafehouseEntry({ owner = owner, x = x, y = y, w = w, h = h, id = id }, actor)
    if not sh then
        return false, "not found"
    end
    if actor and not IKST_GuardOps.actorIsAdmin(actor) then
        local user = IKST_GuardOps.username(actor)
        local shOwner = type(sh.getOwner) == "function" and sh:getOwner() or owner
        if not IKST_ClaimPolicy.usernamesEqual(shOwner, user) then
            return false, "not your safehouse"
        end
    end
    local force = actor and IKST_GuardOps.actorIsAdmin(actor)
    local sx = type(sh.getX) == "function" and sh:getX() or x
    local sy = type(sh.getY) == "function" and sh:getY() or y
    local sw = type(sh.getW) == "function" and sh:getW() or w
    local shh = type(sh.getH) == "function" and sh:getH() or h
    local blocked, blockReason = IKST_GuardOps.claimLocationPolicyBlocked(actor, sx, sy, actor and type(actor.getZ) == "function" and actor:getZ() or 0)
    if blocked then
        return false, blockReason or "not_your_claim"
    end
    local shOnlineId = type(sh.getOnlineID) == "function" and sh:getOnlineID() or nil
    if not IKST_GuardOps.removeSafehouseInstance(sh, actor, force) then
        return false, "release failed"
    end
    if sx and sy and sw and shh then
        IKST_GuardOps.clearSafehouseClaimData(sx, sy, sw, shh)
    end
    IKST_GuardOps.broadcastSafehouseChange(actor, {
        action = "remove",
        removedOnlineId = shOnlineId,
        x = sx,
        y = sy,
        w = sw,
        h = shh,
    })
    return true, "released"
end

function IKST_GuardOps.safehouseOwnedByActor(sh, actor)
    if not sh or not actor then
        return false
    end
    local user = IKST_GuardOps.username(actor)
    local owner = type(sh.getOwner) == "function" and sh:getOwner() or nil
    return IKST_ClaimPolicy.usernamesEqual(owner, user)
end

function IKST_GuardOps.playerMaySetRespawn(sh, actor)
    if not sh or not actor then
        return false
    end
    if not IKST_ClaimPolicy.safehouseRespawnAllowed() then
        return false
    end
    if IKST_GuardOps.actorIsAdmin(actor) then
        return true
    end
    if IKST_GuardOps.safehouseOwnedByActor(sh, actor) then
        return true
    end
    if type(sh.isOwner) == "function" and sh:isOwner(actor) == true then
        return true
    end
    if type(sh.playerAllowed) == "function" and sh:playerAllowed(actor) == true then
        return true
    end
    local user = IKST_GuardOps.username(actor)
    local members = IKST_ClaimSocial.membersList(sh)
    for _, member in ipairs(members) do
        if IKST_ClaimPolicy.usernamesEqual(member, user) then
            return true
        end
    end
    return false
end

function IKST_GuardOps.setSafehouseRespawn(actor, args)
    if not IKST_ClaimPolicy.safehouseRespawnAllowed() then
        return false, "safehouse respawn disabled"
    end
    local sh = IKST_GuardOps.findSafehouseEntry(args, actor)
    if not sh then
        return false, "safehouse not found"
    end
    if not IKST_GuardOps.playerMaySetRespawn(sh, actor) then
        return false, "not your safehouse"
    end
    local on = IKST_Args.readBool(args and args.on)
    if on == nil then
        return false, "respawn flag required"
    end
    if type(sh.setRespawnInSafehouse) ~= "function" then
        return false, "respawn unavailable"
    end
    local username = IKST_GuardOps.username(actor)
    if not username or username == "" then
        return false, "no username"
    end
    sh:setRespawnInSafehouse(on, username)
    if type(sh.syncSafehouse) == "function" then
        sh:syncSafehouse()
    end
    IKST_SafeHouse.afterMutation(sh, actor)
    return true, on and "respawn on" or "respawn off"
end

function IKST_GuardOps.addSafehouseMember(actor, args)
    local sh = IKST_GuardOps.findSafehouseEntry(args, actor)
    if not sh then
        return false, "safehouse not found"
    end
    if not IKST_GuardOps.actorIsAdmin(actor) then
        local x, y, w, h = IKST_SafehouseClaim.boundsFromSafehouse(sh)
        if x then
            local entry = IKST_SafehouseClaim.get(x, y, w, h)
            if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
                if not IKST_SafehousePermissions.resolve(entry, actor, "invite", sh) then
                    return false, "no invite permission"
                end
            elseif not IKST_GuardOps.safehouseOwnedByActor(sh, actor) then
                return false, "not your safehouse"
            end
        elseif not IKST_GuardOps.safehouseOwnedByActor(sh, actor) then
            return false, "not your safehouse"
        end
    end
    local member = IKST_Args.readUsername(args, "member") or IKST_Args.readUsername(args, "username")
    if not member then
        return false, "no member name"
    end
    if not sh.addPlayer then
        return false, "addPlayer unavailable"
    end
    sh:addPlayer(member)
    local memberPlayer = nil
    if getPlayerFromUsername then
        memberPlayer = getPlayerFromUsername(member)
    end
    IKST_SafeHouse.afterMutation(sh, memberPlayer or actor)
    return true, "member added"
end

function IKST_GuardOps.removeSafehouseMember(actor, args)
    local sh = IKST_GuardOps.findSafehouseEntry(args, actor)
    if not sh then
        return false, "safehouse not found"
    end
    if not IKST_GuardOps.actorIsAdmin(actor) and not IKST_GuardOps.safehouseOwnedByActor(sh, actor) then
        return false, "not your safehouse"
    end
    local member = IKST_Args.readUsername(args, "member") or IKST_Args.readUsername(args, "username")
    if not member then
        return false, "no member name"
    end
    local memberPlayer = nil
    if getPlayerFromUsername then
        memberPlayer = getPlayerFromUsername(member)
    end
    if sh.removePlayer then
        sh:removePlayer(member)
        IKST_SafeHouse.afterMutation(sh, memberPlayer or actor)
        return true, "member removed"
    end
    if sh.removeFromList then
        sh:removeFromList(member)
        IKST_SafeHouse.afterMutation(sh, memberPlayer or actor)
        return true, "member removed"
    end
    return false, "removePlayer unavailable"
end

function IKST_GuardOps.claimBounds(cx, cy, size, w, h)
    if w ~= nil or h ~= nil then
        return IKST_Claim.claimBoundsRect(cx, cy, w, h)
    end
    return IKST_Claim.claimBounds(cx, cy, size)
end

function IKST_GuardOps.squareHasBuilding(square)
    return IKST_Claim.squareHasBuilding(square)
end

function IKST_GuardOps.addSafeHouseRect(x, y, w, h, user)
    return IKST_SafeHouse.addRect(x, y, w, h, user)
end

function IKST_GuardOps.tpToSafehouse(admin, x, y, w, h, z)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    w = math.floor(tonumber(w) or 1)
    h = math.floor(tonumber(h) or 1)
    z = tonumber(z) or 0
    if w < 1 then
        w = 1
    end
    if h < 1 then
        h = 1
    end
    local tx = x + math.floor(w / 2)
    local ty = y + math.floor(h / 2)
    IKST_StaffOps.teleportPlayer(admin, tx, ty, z)
    return true, "teleported"
end

function IKST_GuardOps.resolveClaimUser(admin, ownerName)
    local claimPlayer = admin
    if ownerName and ownerName ~= "" then
        local found = IKST_Identity.findPlayerByUsername(ownerName)
        if not found and IKST_Identity.isAccountKey(ownerName) then
            found = IKST_Identity.findPlayerByAccountKey(ownerName)
        end
        if found then
            claimPlayer = found
        elseif ownerName ~= IKST_GuardOps.username(admin) then
            claimPlayer = nil
        end
    end
    local vanillaUser = nil
    local ownerKey = nil
    if claimPlayer then
        ownerKey = IKST_Identity.accountKey(claimPlayer)
        vanillaUser = IKST_Identity.username(claimPlayer)
    elseif ownerName and ownerName ~= "" then
        ownerKey = IKST_Identity.migrateOwnerField(ownerName)
        if IKST_Identity.isAccountKey(ownerName) then
            vanillaUser = IKST_Identity.labelForKey(ownerName)
        else
            vanillaUser = ownerName
        end
    else
        ownerKey = IKST_Identity.accountKey(admin)
        vanillaUser = IKST_GuardOps.username(admin)
    end
    if not vanillaUser or vanillaUser == "" then
        vanillaUser = ownerName or IKST_GuardOps.username(admin)
    end
    return vanillaUser, claimPlayer, ownerKey
end

function IKST_GuardOps.claimSafehouse(player, x, y, z, size, ownerName, claimMode, w, h)
    if not player or not SafeHouse or not SafeHouse.addSafeHouse then
        return false, "no SafeHouse API"
    end
    x = math.floor(tonumber(x) or player:getX())
    y = math.floor(tonumber(y) or player:getY())
    z = tonumber(z) or player:getZ()
    local square = IKST_WorldOps.getSquare(x, y, z)
    if not square then
        return false, "invalid square"
    end
    local blocked, blockReason = IKST_GuardOps.claimLocationPolicyBlocked(player, x, y, z)
    if blocked then
        return false, blockReason or "not_your_claim"
    end
    local claimX, claimY, claimW, claimH = IKST_GuardOps.claimBounds(x, y, size, w, h)
    claimMode = IKST_Claim.resolveClaimMode(x, y, z, claimMode)
    local useBuilding = claimMode == IKST_Claim.MODE.building and IKST_GuardOps.squareHasBuilding(square)
    if not useBuilding then
        local allowed, blockMsg = IKST_PhunZones.claimAllowed(claimX, claimY, z, claimW, claimH, square)
        if not allowed then
            return false, blockMsg or "claim blocked"
        end
    elseif IKST_PhunZones.pointBlocksSafehouse(x, y, square) then
        return false, IKST_PhunZones.blockMessage()
    end
    if SafeHouse.getSafeHouse then
        local existing = SafeHouse.getSafeHouse(square)
        if existing then
            return false, "safehouse already here"
        end
    end
    local user, claimPlayer, ownerKey = IKST_GuardOps.resolveClaimUser(player, ownerName)
    if not user or user == "" or not ownerKey or ownerKey == "" then
        return false, "no username"
    end
    local requireResidential = not IKST_GuardOps.actorIsAdmin(player)
    if IKST_GuardOps.actorIsAdmin(player) and ownerName and ownerName ~= "" then
        if not (claimPlayer and IKST_GuardOps.actorIsAdmin(claimPlayer)) then
            requireResidential = true
        end
    end
    if requireResidential then
        local building = nil
        if type(square.getBuilding) == "function" then
            building = square:getBuilding()
        end
        if not IKST_Claim.isResidentialBuilding(building) then
            return false, "residential buildings only"
        end
        useBuilding = true
    end
    if IKST_GuardOps.atMaxSafehouseClaims(claimPlayer or user) then
        return false, "max safehouse claims"
    end

    local allowed, blockReason = IKST_GuardOps.enforceVanillaClaimRules(player, square, claimPlayer)
    if not allowed then
        return false, blockReason or "claim blocked"
    end

    local sh = nil
    if useBuilding then
        if not claimPlayer then
            return false, "player must be online for indoor claim"
        end
        sh = IKST_SafeHouse.addBuilding(square, claimPlayer)
    else
        local claimX, claimY, claimW, claimH = IKST_GuardOps.claimBounds(x, y, size, w, h)
        local existing = IKST_GuardOps.safehouseAt(claimX, claimY, z, claimW, claimH)
        if existing then
            return false, "safehouse already here"
        end
        sh = IKST_GuardOps.addSafeHouseRect(claimX, claimY, claimW, claimH, user)
        if not sh then
            return false, "rect claim failed — try Whole building or another spot"
        end
    end

    if not sh then
        return false, "claim failed"
    end
    local row = IKST_GuardOps.safehouseToTable(sh)
    IKST_SafeHouse.afterMutation(sh, claimPlayer or player, {
        action = "add",
        onlineId = row and row.id or nil,
        owner = row and row.owner or user,
        title = row and row.title or "",
        x = row and row.x or x,
        y = row and row.y or y,
        w = row and row.w or 0,
        h = row and row.h or 0,
    })
    local sx = type(sh.getX) == "function" and sh:getX() or x
    local sy = type(sh.getY) == "function" and sh:getY() or y
    local sw = type(sh.getW) == "function" and sh:getW() or 0
    local shh = type(sh.getH) == "function" and sh:getH() or 0
    IKST_ClaimPolicy.recordSafehouseClaim(ownerKey, sx, sy, sw, shh)
    IKST_SafehouseClaim.ensureOnClaim(ownerKey, sx, sy, sw, shh)
    local ownerNote = (ownerName and ownerName ~= "" and ownerName ~= IKST_GuardOps.username(player)) and (" for " .. user) or ""
    return true, "safehouse claimed" .. ownerNote .. " " .. sw .. "x" .. shh .. " @ " .. sx .. "," .. sy
end

function IKST_GuardOps.backupSafehouses()
    local backup = {}
    IKST_GuardOps.iterSafehouses(function(sh)
        backup[#backup + 1] = IKST_GuardOps.safehouseToTable(sh)
    end)
    IKST_GuardOps.worldRulesData().safehouseBackup = backup
    return true, "backed up " .. #backup
end

function IKST_GuardOps.restoreSafehouses(actor)
    local backup = IKST_GuardOps.worldRulesData().safehouseBackup
    if not backup or #backup == 0 then
        return false, "no backup"
    end
    if not SafeHouse or not SafeHouse.addSafeHouse then
        return false, "no SafeHouse API"
    end
    local restored = 0
    for _, entry in ipairs(backup) do
        if entry.owner and entry.x and entry.y then
            local sh = IKST_GuardOps.addSafeHouseRect(entry.x, entry.y, entry.w or 10, entry.h or 10, entry.owner)
            if sh and entry.title and entry.title ~= "" and sh.setTitle then
                sh:setTitle(entry.title)
            end
            if sh then
                restored = restored + 1
            end
        end
    end
    if restored > 0 then
        IKST_SafeHouse.sync()
        if actor then
            IKST_GuardOps.broadcastSafehouseChange(actor)
        end
    end
    return true, "restored " .. restored
end

function IKST_GuardOps.sendSafehouseList(player, list)
    local max = IKST_Access and IKST_Access.claimListMaxSize and IKST_Access.claimListMaxSize() or 200
    if #list > max then
        local trimmed = {}
        for i = 1, max do
            trimmed[i] = list[i]
        end
        list = trimmed
    end
    local rows = {}
    for _, item in ipairs(list) do
        if item and item.canRelease ~= nil then
            rows[#rows + 1] = item
        elseif item then
            rows[#rows + 1] = IKST_GuardOps.safehouseRowForViewer(item, player)
        end
    end
    IKST.deliverClientCommand(player, IKST.CMD.safehouseListResult, { safehouses = rows })
end

function IKST_GuardOps.broadcastSafehouseChange(actor, syncInfo)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST_StaffOps or not IKST_StaffOps.forEachOnline then
        return
    end
    IKST_GuardOps.purgeExpiredSafehouses()
    local list = IKST_GuardOps.listSafehouses()
    local refreshArgs = {}
    if type(syncInfo) == "number" then
        refreshArgs.action = "remove"
        refreshArgs.removedOnlineId = syncInfo
    elseif type(syncInfo) == "table" then
        refreshArgs.action = syncInfo.action
        if syncInfo.action == "remove" or syncInfo.removedOnlineId then
            refreshArgs.action = "remove"
            refreshArgs.removedOnlineId = syncInfo.removedOnlineId or syncInfo.onlineId
            refreshArgs.x = syncInfo.x
            refreshArgs.y = syncInfo.y
            refreshArgs.w = syncInfo.w
            refreshArgs.h = syncInfo.h
        elseif syncInfo.action == "add" then
            refreshArgs.onlineId = syncInfo.onlineId
            refreshArgs.owner = syncInfo.owner
            refreshArgs.title = syncInfo.title
            refreshArgs.x = syncInfo.x
            refreshArgs.y = syncInfo.y
            refreshArgs.w = syncInfo.w
            refreshArgs.h = syncInfo.h
        end
    end
    local mirrorArgs = nil
    if type(syncInfo) == "table" and syncInfo.x and syncInfo.y and syncInfo.w and syncInfo.h then
        if syncInfo.action == "remove" then
            mirrorArgs = {
                action = "remove",
                x = syncInfo.x,
                y = syncInfo.y,
                w = syncInfo.w,
                h = syncInfo.h,
            }
        elseif syncInfo.action == "add" or syncInfo.action == "set" then
            mirrorArgs = {
                action = "set",
                x = syncInfo.x,
                y = syncInfo.y,
                w = syncInfo.w,
                h = syncInfo.h,
            }
            local entry = IKST_SafehouseClaim.get(syncInfo.x, syncInfo.y, syncInfo.w, syncInfo.h)
            if entry then
                mirrorArgs.entry = IKST_SafehouseClaim.copyEntryPlain(entry)
            end
        end
    end
    IKST_StaffOps.forEachOnline(function(p)
        local filtered = list
        if not IKST_GuardOps.actorIsAdmin(p) then
            filtered = IKST_GuardOps.filterSafehousesForPlayer(list, p)
        end
        IKST_GuardOps.sendSafehouseList(p, filtered)
        IKST.deliverClientCommand(p, IKST.CMD.safehouseClientRefresh, refreshArgs)
        if mirrorArgs then
            IKST.deliverClientCommand(p, IKST.CMD.safehouseClaimMirror, mirrorArgs)
        end
    end)
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        local detail = "count=" .. tostring(#list)
        if refreshArgs.action then
            detail = detail .. " action=" .. tostring(refreshArgs.action)
        end
        if refreshArgs.removedOnlineId then
            detail = detail .. " removed=" .. tostring(refreshArgs.removedOnlineId)
        end
        if refreshArgs.onlineId then
            detail = detail .. " added=" .. tostring(refreshArgs.onlineId)
        end
        if refreshArgs.x then
            detail = detail .. " @" .. tostring(refreshArgs.x) .. "," .. tostring(refreshArgs.y)
        end
        IKST_Debug.logEffect("safehouse", "broadcast", detail, actor)
    end
end

function IKST_GuardOps.notifySafehouseClaimResult(player, ok, message, extra)
    if not player or not IKST.deliverClientCommand then
        return
    end
    local payload = {
        ok = ok == true,
        message = tostring(message or ""),
    }
    if extra then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end
    IKST.deliverClientCommand(player, IKST.CMD.safehouseClaimResult, payload)
end

function IKST_GuardOps.enforceVanillaClaimRules(player, square, claimPlayer)
    if IKST_GuardOps.actorIsAdmin(player) then
        return true, nil
    end
    local checkPlayer = claimPlayer or player
    if not checkPlayer then
        return false, "player must be online to claim"
    end
    if SafeHouse.allowSafeHouse and SafeHouse.allowSafeHouse(checkPlayer) == false then
        return false, "not allowed to claim yet"
    end
    if SafeHouse.canBeSafehouse and square then
        local reason = SafeHouse.canBeSafehouse(square, checkPlayer)
        if reason and reason ~= "" then
            return false, reason
        end
    end
    return true, nil
end
