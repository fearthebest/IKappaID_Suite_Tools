-- World Guard server operations.
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Args"
require "IKST_Grid"
require "IKST_Claim"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"
require "IKST_Identity"
require "IKST_WorldOps"
require "IKST_StaffOps"
require "IKST_VehicleClaim"
require "IKST_VehicleUtil"
require "IKST_SafehouseClaim"
require "IKST_SafehousePermissions"
require "IKST_PhunZones"
require "IKST_SafeHouse"
require "IKST_ModDataSync"

IKST_GuardOps = IKST_GuardOps or {}

function IKST_GuardOps.worldRulesData()
    local data = ModData.getOrCreate("IKST_WorldRules")
    if not data.rules then
        data.rules = { disableDestroy = false, disablePickup = false }
    end
    if not data.spriteBlacklist then
        data.spriteBlacklist = {}
    end
    if data.showSafehouseBorders == nil then
        data.showSafehouseBorders = false
    end
    return data
end

function IKST_GuardOps.username(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getDisplayName then
        local name = player:getDisplayName()
        if name and name ~= "" then
            return name
        end
    end
    if player.getDescriptor and player:getDescriptor() and player:getDescriptor().getForename then
        local desc = player:getDescriptor()
        local fore = desc:getForename() or ""
        local sur = desc.getSurname and desc:getSurname() or ""
        local full = string.gsub(fore .. " " .. sur, "^%s*(.-)%s*$", "%1")
        if full ~= "" then
            return full
        end
    end
    return "Player"
end

function IKST_GuardOps.syncCaughtClient(player, caught, x, y, z)
    if not player then
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.catchSync, {
        caught = caught == true,
        x = x,
        y = y,
        z = z,
    })
end

function IKST_GuardOps.setCaught(player, caught)
    if not player then
        return false, "no player"
    end
    local md = player:getModData()
    md.IKST_caught = caught == true
    if md.IKST_caught then
        md.IKST_catchX = player:getX()
        md.IKST_catchY = player:getY()
        md.IKST_catchZ = player:getZ()
    else
        md.IKST_catchX = nil
        md.IKST_catchY = nil
        md.IKST_catchZ = nil
    end
    if player.setBlockMovement then
        player:setBlockMovement(md.IKST_caught)
    end
    IKST_GuardOps.syncCaughtClient(player, md.IKST_caught, md.IKST_catchX, md.IKST_catchY, md.IKST_catchZ)
    return true, caught and "caught" or "released"
end

function IKST_GuardOps.enforceCaughtPosition(player)
    if not player then
        return
    end
    local md = player:getModData()
    if not md.IKST_caught then
        return
    end
    if md.IKST_catchX and md.IKST_catchY then
        if math.abs(player:getX() - md.IKST_catchX) > 0.5 or math.abs(player:getY() - md.IKST_catchY) > 0.5 then
            IKST_StaffOps.teleportPlayer(player, md.IKST_catchX, md.IKST_catchY, md.IKST_catchZ or 0)
        end
    end
end

function IKST_GuardOps.toggleCreative(player)
    if not player or not player.setBuildCheat or not player.isBuildCheat then
        return false, "unavailable"
    end
    local on = not player:isBuildCheat()
    player:setBuildCheat(on)
    return true, on and "creative ON" or "creative OFF"
end

function IKST_GuardOps.toggleUnlimitedAmmo(player)
    if not player or not player.setUnlimitedAmmo or not player.isUnlimitedAmmo then
        return false, "unavailable"
    end
    local on = not player:isUnlimitedAmmo()
    player:setUnlimitedAmmo(on)
    return true, on and "unlimited ammo ON" or "unlimited ammo OFF"
end

function IKST_GuardOps.lightbulbsInRadius(cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local count = 0
    for _, sq in ipairs(squares) do
        local objects = sq:getObjects()
        if objects then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj and obj.getSprite then
                    local sprite = obj:getSprite()
                    local name = sprite and sprite.getName and string.lower(sprite:getName() or "") or ""
                    if string.find(name, "light", 1, true) or string.find(name, "lamp", 1, true) then
                        if obj.setActivated then
                            obj:setActivated(true)
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return true, "lights " .. count
end

function IKST_GuardOps.dumpPlayers(admin)
    local out = {}
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size and list.get then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p then
                out[#out + 1] = {
                    id = p.getOnlineID and p:getOnlineID() or i,
                    name = IKST_StaffOps.playerLabel(p),
                    x = math.floor(p:getX()),
                    y = math.floor(p:getY()),
                    z = p:getZ(),
                }
            end
        end
    elseif admin then
        out[1] = {
            id = admin.getOnlineID and admin:getOnlineID() or 0,
            name = IKST_StaffOps.playerLabel(admin),
            x = math.floor(admin:getX()),
            y = math.floor(admin:getY()),
            z = admin:getZ(),
        }
    end
    return out
end

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
    local x = sh.getX and sh:getX() or 0
    local y = sh.getY and sh:getY() or 0
    local w = sh.getW and sh:getW() or 0
    local h = sh.getH and sh:getH() or 0
    local meta = IKST_ClaimPolicy.getSafehouseMeta(x, y, w, h)
    local entry = IKST_SafehouseClaim.get(x, y, w, h)
    local expiresAt = meta and meta.expiresAt or nil
    if entry and entry.expiresAt then
        expiresAt = entry.expiresAt
    end
    return {
        id = IKST_SafeHouse.id(sh),
        owner = sh.getOwner and sh:getOwner() or "?",
        x = x,
        y = y,
        w = w,
        h = h,
        title = sh.getTitle and sh:getTitle() or "",
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
        local sx = sh.getX and sh:getX() or nil
        local sy = sh.getY and sh:getY() or nil
        local sw = sh.getW and sh:getW() or nil
        local shh = sh.getH and sh:getH() or nil
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

function IKST_GuardOps.filterSafehousesForPlayer(list, username)
    local out = {}
    for _, row in ipairs(list or {}) do
        if IKST_ClaimPolicy.usernamesEqual(row.owner, username) then
            out[#out + 1] = row
        end
    end
    return out
end

function IKST_GuardOps.actorIsAdmin(actor)
    return IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(actor)
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
        local shOwner = sh.getOwner and sh:getOwner() or owner
        if not IKST_ClaimPolicy.usernamesEqual(shOwner, user) then
            return false, "not your safehouse"
        end
    end
    local force = actor and IKST_GuardOps.actorIsAdmin(actor)
    local sx = sh.getX and sh:getX() or x
    local sy = sh.getY and sh:getY() or y
    local sw = sh.getW and sh:getW() or w
    local shh = sh.getH and sh:getH() or h
    if not IKST_GuardOps.removeSafehouseInstance(sh, actor, force) then
        return false, "release failed"
    end
    if sx and sy and sw and shh then
        IKST_GuardOps.clearSafehouseClaimData(sx, sy, sw, shh)
    end
    return true, "released"
end

function IKST_GuardOps.safehouseOwnedByActor(sh, actor)
    if not sh or not actor then
        return false
    end
    local user = IKST_GuardOps.username(actor)
    local owner = sh.getOwner and sh:getOwner() or nil
    return IKST_ClaimPolicy.usernamesEqual(owner, user)
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
    local member = args.member or args.username
    if not member or member == "" then
        return false, "no member name"
    end
    if not sh.addPlayer then
        return false, "addPlayer unavailable"
    end
    sh:addPlayer(member)
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
    local member = args.member or args.username
    if not member or member == "" then
        return false, "no member name"
    end
    if sh.removePlayer then
        sh:removePlayer(member)
        return true, "member removed"
    end
    if sh.removeFromList then
        sh:removeFromList(member)
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
    local user = ownerName
    if not user or user == "" then
        user = IKST_GuardOps.username(admin)
    end
    if not user or user == "" then
        return nil, nil
    end
    local claimPlayer = admin
    if ownerName and ownerName ~= "" and getPlayerFromUsername then
        local found = getPlayerFromUsername(ownerName)
        if found then
            claimPlayer = found
        elseif ownerName ~= IKST_GuardOps.username(admin) then
            claimPlayer = nil
        end
    end
    return user, claimPlayer
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
    local user, claimPlayer = IKST_GuardOps.resolveClaimUser(player, ownerName)
    if not user then
        return false, "no username"
    end
    if IKST_GuardOps.atMaxSafehouseClaims(claimPlayer or user) then
        return false, "max safehouse claims"
    end

    local sh = nil
    if useBuilding then
        if not claimPlayer then
            return false, "player must be online for indoor claim"
        end
        if SafeHouse.canBeSafehouse then
            local reason = SafeHouse.canBeSafehouse(square, claimPlayer)
            if reason and reason ~= "" then
                return false, reason
            end
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
    IKST_SafeHouse.sync(sh)
    local sx = sh.getX and sh:getX() or x
    local sy = sh.getY and sh:getY() or y
    local sw = sh.getW and sh:getW() or 0
    local shh = sh.getH and sh:getH() or 0
    local ownerKey = claimPlayer and IKST_Identity.accountKey(claimPlayer) or IKST_Identity.migrateOwnerField(user)
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

function IKST_GuardOps.restoreSafehouses()
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
    IKST.deliverClientCommand(player, IKST.CMD.safehouseListResult, { safehouses = list })
end

function IKST_GuardOps.sendClaimList(player, list)
    local max = IKST_Access and IKST_Access.claimListMaxSize and IKST_Access.claimListMaxSize() or 200
    if #list > max then
        local trimmed = {}
        for i = 1, max do
            trimmed[i] = list[i]
        end
        list = trimmed
    end
    IKST.deliverClientCommand(player, IKST.CMD.vehicleClaimListResult, { claims = list })
end

function IKST_GuardOps.sendNearbyVehicles(player, list)
    IKST.deliverClientCommand(player, IKST.CMD.vehicleListResult, { vehicles = list })
end

function IKST_GuardOps.handle(command, admin, args)
    args = args or {}
    local ax = math.floor(tonumber(args.x) or (admin and admin:getX()) or 0)
    local ay = math.floor(tonumber(args.y) or (admin and admin:getY()) or 0)
    local az = tonumber(args.z) or (admin and admin:getZ()) or 0
    local radius = IKST.clampRadius(args.radius)

    if command == IKST.CMD.catchTarget or command == IKST.CMD.catchPlayer then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target and args.username and getPlayerFromUsername then
            target = getPlayerFromUsername(args.username)
        end
        if not target then
            return false, "player not found"
        end
        return IKST_GuardOps.setCaught(target, true)
    end

    if command == IKST.CMD.releaseTarget or command == IKST.CMD.releasePlayer then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target and args.username and getPlayerFromUsername then
            target = getPlayerFromUsername(args.username)
        end
        if not target then
            return false, "player not found"
        end
        return IKST_GuardOps.setCaught(target, false)
    end

    if command == IKST.CMD.toggleCreative then
        return IKST_GuardOps.toggleCreative(admin)
    end

    if command == IKST.CMD.toggleUnlimitedAmmo then
        return IKST_GuardOps.toggleUnlimitedAmmo(admin)
    end

    if command == IKST.CMD.lightbulbsArea then
        return IKST_GuardOps.lightbulbsInRadius(ax, ay, az, radius)
    end

    if command == IKST.CMD.dumpPlayers then
        local list = IKST_GuardOps.dumpPlayers(admin)
        IKST.deliverClientCommand(admin, IKST.CMD.dumpPlayersResult, { players = list })
        return true, "dumped " .. #list
    end

    if command == IKST.CMD.safehouseList then
        IKST_GuardOps.purgeExpiredSafehouses()
        local list = IKST_GuardOps.listSafehouses()
        if not IKST_GuardOps.actorIsAdmin(admin) then
            list = IKST_GuardOps.filterSafehousesForPlayer(list, IKST_GuardOps.username(admin))
        end
        IKST_GuardOps.sendSafehouseList(admin, list)
        return true, #list .. " safehouse(s)"
    end

    if command == IKST.CMD.safehouseClaim then
        if not IKST_GuardOps.actorIsAdmin(admin) then
            args.owner = IKST_GuardOps.username(admin)
            local dist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
            if not IKST_Args.actorNearCoord(admin, ax, ay, az, dist) then
                return false, "too far"
            end
        end
        return IKST_GuardOps.claimSafehouse(admin, ax, ay, az, args.size, args.owner, args.claimMode, args.w, args.h)
    end

    if command == IKST.CMD.safehouseRelease then
        return IKST_GuardOps.releaseSafehouse(args.owner, args.x, args.y, args.w, args.h, args.id, admin)
    end

    if command == IKST.CMD.safehouseAddMember then
        return IKST_GuardOps.addSafehouseMember(admin, args)
    end

    if command == IKST.CMD.safehouseRemoveMember then
        return IKST_GuardOps.removeSafehouseMember(admin, args)
    end

    if command == IKST.CMD.safehouseTp then
        return IKST_GuardOps.tpToSafehouse(admin, args.x, args.y, args.w, args.h, args.z)
    end

    if command == IKST.CMD.backupSafehouses then
        return IKST_GuardOps.backupSafehouses()
    end

    if command == IKST.CMD.restoreSafehouses then
        return IKST_GuardOps.restoreSafehouses()
    end

    if command == IKST.CMD.toggleSafehouseBorders then
        local data = IKST_GuardOps.worldRulesData()
        data.showSafehouseBorders = not data.showSafehouseBorders
        IKST.transmitModData(IKST.ModDataKeys.WorldRules)
        IKST.deliverClientCommand(admin, IKST.CMD.safehouseBordersSync, { on = data.showSafehouseBorders })
        return true, data.showSafehouseBorders and "borders ON" or "borders OFF"
    end

    if command == IKST.CMD.vehicleClaim then
        local vid = args.vehicleId
        if not vid and admin then
            vid = IKST_VehicleUtil.nearestId(admin:getX(), admin:getY(), admin:getZ(), IKST.getVehicleNearRadius())
        end
        if not vid then
            return false, "no vehicle nearby — pick one in the list"
        end
        if not IKST_GuardOps.actorIsAdmin(admin) then
            local vidNum = tonumber(vid)
            if vidNum then
                local v = IKST_VehicleUtil.getVehicle(vidNum)
                if not v then
                    return false, "vehicle not found"
                end
                local vz = v.getZ and v:getZ() or 0
                if not IKST_Args.actorNearCoord(admin, v:getX(), v:getY(), vz, IKST.getVehicleNearRadius()) then
                    return false, "too far"
                end
            end
        end
        local ownerKey = IKST_Identity.accountKey(admin)
        if IKST_GuardOps.actorIsAdmin(admin) and args.owner and args.owner ~= "" then
            local found = IKST_Identity.findPlayerByUsername(args.owner)
            if not found then
                found = IKST_Identity.findPlayerByAccountKey(args.owner)
            end
            if found then
                ownerKey = IKST_Identity.accountKey(found)
            else
                ownerKey = IKST_Identity.resolveWhitelistKey(args.owner)
            end
        end
        if not IKST_GuardOps.actorIsAdmin(admin) then
            ownerKey = IKST_Identity.accountKey(admin)
            if IKST.vehicleClaimRequireKeys() then
                local keyV = IKST_VehicleUtil.getVehicle(vid)
                if keyV and not IKST_VehicleUtil.playerHasVehicleKey(admin, keyV) then
                    return false, "need vehicle key to claim"
                end
            end
        end
        if not ownerKey or ownerKey == "" then
            return false, "no owner"
        end
        local meta = { label = args.label or "" }
        local v = IKST_VehicleUtil.getVehicle(vid)
        if v then
            if v.getScriptName then
                meta.script = v:getScriptName() or ""
            end
            meta.x = math.floor(v:getX())
            meta.y = math.floor(v:getY())
            meta.z = v.getZ and v:getZ() or 0
        end
        return IKST_VehicleClaim.claim(vid, ownerKey, meta)
    end

    if command == IKST.CMD.vehicleReleaseClaim then
        local vid = args.vehicleId
        if not vid and admin then
            vid = IKST_VehicleUtil.nearestId(admin:getX(), admin:getY(), admin:getZ(), IKST.getVehicleNearRadius())
        end
        if not vid then
            return false, "no vehicle selected"
        end
        local entry = IKST_VehicleClaim.get(vid)
        if not IKST_GuardOps.actorIsAdmin(admin) then
            if not entry then
                return false, "not claimed"
            end
            if not IKST_VehicleClaim.isOwner(entry, admin) then
                return false, "not your claim"
            end
        end
        return IKST_VehicleClaim.release(vid)
    end

    if command == IKST.CMD.vehicleClaimTransfer then
        if not IKST_GuardOps.actorIsAdmin(admin) then
            return false, "admin only"
        end
        local vid = args.vehicleId
        if not vid and admin then
            vid = IKST_VehicleUtil.nearestId(admin:getX(), admin:getY(), admin:getZ(), IKST.getVehicleNearRadius())
        end
        if not vid then
            return false, "no vehicle selected"
        end
        local newOwner = args.owner
        if newOwner and newOwner ~= "" then
            local found = IKST_Identity.findPlayerByUsername(newOwner)
            if not found then
                found = IKST_Identity.findPlayerByAccountKey(newOwner)
            end
            if found then
                newOwner = IKST_Identity.accountKey(found)
            else
                newOwner = IKST_Identity.resolveWhitelistKey(newOwner)
            end
        end
        return IKST_VehicleClaim.transfer(vid, newOwner)
    end

    if command == IKST.CMD.vehicleClaimSetLabel then
        local vid = args.vehicleId
        if not vid and admin then
            vid = IKST_VehicleUtil.nearestId(admin:getX(), admin:getY(), admin:getZ(), IKST.getVehicleNearRadius())
        end
        if not vid then
            return false, "no vehicle selected"
        end
        local entry = IKST_VehicleClaim.get(vid)
        if not IKST_GuardOps.actorIsAdmin(admin) then
            if not entry or not IKST_VehicleClaim.playerMayEdit(entry, admin) then
                return false, "not your claim"
            end
        end
        return IKST_VehicleClaim.setLabel(vid, args.label)
    end

    if command == IKST.CMD.vehicleClaimSetPerms then
        local vid = args.vehicleId
        if not vid and admin then
            vid = IKST_VehicleUtil.nearestId(admin:getX(), admin:getY(), admin:getZ(), IKST.getVehicleNearRadius())
        end
        if not vid then
            return false, "no vehicle selected"
        end
        local entry = IKST_VehicleClaim.get(vid)
        if not entry then
            return false, "not claimed"
        end
        if not IKST_GuardOps.actorIsAdmin(admin) and not IKST_VehicleClaim.playerMayEdit(entry, admin) then
            return false, "not your claim"
        end
        return IKST_VehicleClaim.setPermissions(vid, args.scope, args.username, args.perms)
    end

    if command == IKST.CMD.safehouseClaimSetPerms then
        local x, y, w, h = IKST_SafehouseClaim.refFromArgs(args)
        if not x and admin then
            local sq = admin:getCurrentSquare()
            local sh = sq and IKST_SafehouseClaim.safehouseAtSquare(sq) or nil
            x, y, w, h = IKST_SafehouseClaim.boundsFromSafehouse(sh)
        end
        if not x then
            return false, "no safehouse selected"
        end
        local entry = IKST_SafehouseClaim.get(x, y, w, h)
        if not entry then
            local sh = IKST_GuardOps.findSafehouseEntry({ x = x, y = y, w = w, h = h }, admin)
            if sh then
                local owner = sh.getOwner and sh:getOwner() or nil
                if owner and owner ~= "" then
                    IKST_SafehouseClaim.ensureOnClaim(IKST_Identity.migrateOwnerField(owner), x, y, w, h)
                    entry = IKST_SafehouseClaim.get(x, y, w, h)
                end
            end
        end
        if not entry then
            return false, "not claimed"
        end
        if not IKST_GuardOps.actorIsAdmin(admin) and not IKST_SafehouseClaim.playerMayEdit(entry, admin) then
            return false, "not your safehouse"
        end
        return IKST_SafehouseClaim.setPermissions(x, y, w, h, args.scope, args.username, args.perms)
    end

    if command == IKST.CMD.vehicleClaimList then
        local list
        local showAll = args.all == true
            and (IKST_GuardOps.actorIsAdmin(admin) or IKST.vehicleShowAllClaims())
        if showAll then
            list = IKST_VehicleClaim.listAll()
        else
            list = IKST_VehicleClaim.listForOwner(IKST_Identity.accountKey(admin))
        end
        IKST_GuardOps.sendClaimList(admin, list)
        return true, #list .. " claim(s)"
    end

    if command == IKST.CMD.vehicleClaimNearby then
        if not IKST_VehicleUtil or not IKST_VehicleUtil.listNearby then
            return false, "vehicle API missing"
        end
        local list = IKST_VehicleUtil.listNearby(ax, ay, az, radius)
        IKST_GuardOps.sendNearbyVehicles(admin, list)
        return true, #list .. " vehicle(s)"
    end

    return false, "unknown guard command"
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(function()
        if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
            return
        end
        IKST_GuardOps.iterSafehouses(function(sh)
            if IKST_SafehouseClaim and IKST_SafehouseClaim.syncFromVanilla then
                IKST_SafehouseClaim.syncFromVanilla(sh)
            end
        end)
    end)
end
