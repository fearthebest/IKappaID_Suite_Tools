-- Sandbox-driven limits and MP permissions for vehicle / safehouse claims.

require "IKST_Shared"
require "IKST_Identity"
require "IKST_Access"

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

function IKST_ClaimPolicy.legacySelfService()
    return IKST_ClaimPolicy.sandboxBool("ClaimPlayerSelfService", false)
end

function IKST_ClaimPolicy.houseSelfServiceEnabled()
    local sv = IKST_ClaimPolicy.sandbox()
    if sv and sv.ClaimHouseSelfService ~= nil then
        return sv.ClaimHouseSelfService == true
    end
    return IKST_ClaimPolicy.legacySelfService()
end

function IKST_ClaimPolicy.houseRequestEnabled()
    local sv = IKST_ClaimPolicy.sandbox()
    if sv and sv.ClaimHouseRequestEnabled ~= nil then
        return sv.ClaimHouseRequestEnabled == true
    end
    if sv and sv.ClaimPlayerSelfService ~= nil then
        return sv.ClaimPlayerSelfService ~= true
    end
    return true
end

function IKST_ClaimPolicy.vehicleSelfServiceEnabled()
    local sv = IKST_ClaimPolicy.sandbox()
    if sv and sv.ClaimVehicleSelfService ~= nil then
        return sv.ClaimVehicleSelfService == true
    end
    return IKST_ClaimPolicy.legacySelfService()
end

function IKST_ClaimPolicy.vehicleRequestEnabled()
    local sv = IKST_ClaimPolicy.sandbox()
    if sv and sv.ClaimVehicleRequestEnabled ~= nil then
        return sv.ClaimVehicleRequestEnabled == true
    end
    return false
end

-- Any player claim path enabled (self-service or request).
function IKST_ClaimPolicy.playerClaimsEnabled()
    return IKST_ClaimPolicy.houseSelfServiceEnabled()
        or IKST_ClaimPolicy.vehicleSelfServiceEnabled()
        or IKST_ClaimPolicy.houseRequestEnabled()
        or IKST_ClaimPolicy.vehicleRequestEnabled()
end

-- SP: respect sandbox claim modes per save. Host is admin for tools, not auto direct-claim.
function IKST_ClaimPolicy.useSandboxClaimModes()
    return IKST_Access and type(IKST_Access.isSinglePlayer) == "function"
        and IKST_Access.isSinglePlayer()
end

function IKST_ClaimPolicy.staffMayClaim(player)
    return IKST_Access and type(IKST_Access.canUseStaffTools) == "function"
        and IKST_Access.canUseStaffTools(player)
end

-- Game admin with ClaimAdminBypass (matches server actorIsAdmin + adminMayBypass).
function IKST_ClaimPolicy.adminMayCreateClaim(player)
    if not player then
        return false
    end
    if not IKST_ClaimPolicy.adminBypass() then
        return false
    end
    if IKST_Access and type(IKST_Access.canUseTools) == "function" then
        return IKST_Access.canUseTools(player) == true
    end
    return false
end

function IKST_ClaimPolicy.mayCreateSafehouseClaim(player)
    if not IKST_ClaimPolicy.useSandboxClaimModes() then
        if IKST_ClaimPolicy.staffMayClaim(player) then
            return true
        end
        if IKST_ClaimPolicy.adminMayCreateClaim(player) then
            return true
        end
    end
    return IKST_ClaimPolicy.houseSelfServiceEnabled()
end

function IKST_ClaimPolicy.mayRequestSafehouseClaim(player)
    if IKST_ClaimPolicy.useSandboxClaimModes() then
        return IKST_ClaimPolicy.houseRequestEnabled()
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false
    end
    if IKST_ClaimPolicy.staffMayClaim(player) then
        return true
    end
    return IKST_ClaimPolicy.houseRequestEnabled()
end

function IKST_ClaimPolicy.mayCreateVehicleClaim(player)
    if not IKST_ClaimPolicy.useSandboxClaimModes() then
        if IKST_ClaimPolicy.staffMayClaim(player) then
            return true
        end
        if IKST_ClaimPolicy.adminMayCreateClaim(player) then
            return true
        end
    end
    return IKST_ClaimPolicy.vehicleSelfServiceEnabled()
end

function IKST_ClaimPolicy.mayRequestVehicleClaim(player)
    if IKST_ClaimPolicy.useSandboxClaimModes() then
        return IKST_ClaimPolicy.vehicleRequestEnabled()
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false
    end
    if IKST_ClaimPolicy.staffMayClaim(player) then
        return true
    end
    return IKST_ClaimPolicy.vehicleRequestEnabled()
end

-- Request UI when player cannot self-claim (staff with direct-claim skip request buttons).
function IKST_ClaimPolicy.mayShowSafehouseClaimRequest(player)
    return IKST_ClaimPolicy.mayRequestSafehouseClaim(player)
        and not IKST_ClaimPolicy.mayCreateSafehouseClaim(player)
end

function IKST_ClaimPolicy.mayShowVehicleClaimRequest(player)
    return IKST_ClaimPolicy.mayRequestVehicleClaim(player)
        and not IKST_ClaimPolicy.mayCreateVehicleClaim(player)
end

-- Prefer mayCreateSafehouseClaim / mayCreateVehicleClaim at call sites.
function IKST_ClaimPolicy.mayCreateClaim(player)
    return IKST_ClaimPolicy.mayCreateSafehouseClaim(player)
        or IKST_ClaimPolicy.mayCreateVehicleClaim(player)
end

-- Vanilla server option SafehouseAllowRespawn (not IKST sandbox).
function IKST_ClaimPolicy.safehouseRespawnAllowed()
    if type(getServerOptions) ~= "function" then
        return false
    end
    local opts = getServerOptions()
    if not opts then
        return false
    end
    if type(opts.getBoolean) == "function" then
        return opts:getBoolean("SafehouseAllowRespawn") == true
    end
    if type(opts.getOptionByName) == "function" then
        local opt = opts:getOptionByName("SafehouseAllowRespawn")
        if opt and type(opt.getValue) == "function" then
            return opt:getValue() == true
        end
    end
    return false
end

function IKST_ClaimPolicy.maxVehicleClaims()
    return IKST_ClaimPolicy.sandboxInt("MaxVehicleClaims", 3, 0, 50)
end

function IKST_ClaimPolicy.maxSafehouseClaims()
    return IKST_ClaimPolicy.sandboxInt("MaxSafehouseClaims", 1, 0, 20)
end

-- Real-life calendar days (wall clock), not in-game world days.
local SECONDS_PER_DAY = 86400
-- World-age hours never reach unix epoch; stamps below this are pre-calendar legacy.
local LEGACY_STAMP_MAX = 1000000

function IKST_ClaimPolicy.claimDurationDays()
    return IKST_ClaimPolicy.sandboxInt("ClaimDurationDays", 0, 0, 365)
end

function IKST_ClaimPolicy.claimDurationSeconds()
    local days = IKST_ClaimPolicy.claimDurationDays()
    if days <= 0 then
        return 0
    end
    return days * SECONDS_PER_DAY
end

-- Hours-of-real-time alias for callers that still ask for "hours".
function IKST_ClaimPolicy.claimDurationHours()
    return IKST_ClaimPolicy.claimDurationSeconds() / 3600
end

-- Real-life days without owner activity before the claim expires. 0 = off.
function IKST_ClaimPolicy.inactivityDays()
    return IKST_ClaimPolicy.sandboxInt("ClaimInactivityDays", 14, 0, 365)
end

function IKST_ClaimPolicy.inactivitySeconds()
    local days = IKST_ClaimPolicy.inactivityDays()
    if days <= 0 then
        return 0
    end
    return days * SECONDS_PER_DAY
end

function IKST_ClaimPolicy.inactivityHours()
    return IKST_ClaimPolicy.inactivitySeconds() / 3600
end

function IKST_ClaimPolicy.vehicleRequireSeat()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleRequireSeat", true)
end

function IKST_ClaimPolicy.vehicleRequireEngine()
    return IKST_ClaimPolicy.sandboxBool("ClaimVehicleRequireEngine", false)
end

function IKST_ClaimPolicy.vehicleRequireKeys()
    if IKST_ClaimPolicy.sandboxBool("ClaimVehicleRequireKeys", false) then
        return true
    end
    if IKST and type(IKST.vehicleClaimRequireKeys) == "function" then
        return IKST.vehicleClaimRequireKeys() == true
    end
    return false
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
    if type(usernameOrPlayer) == "table" and type(usernameOrPlayer.getUsername) == "function" then
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

-- Wall-clock unix seconds (real-life calendar). Not world-age hours.
function IKST_ClaimPolicy.nowUnix()
    if os and type(os.time) == "function" then
        local t = tonumber(os.time())
        if t and t > 0 then
            return t
        end
    end
    if type(getTimestamp) == "function" then
        local t = tonumber(getTimestamp())
        if t and t > 0 then
            return t
        end
    end
    return 0
end

-- Legacy alias: value is unix seconds (same unit as claimedAt / expiresAt).
function IKST_ClaimPolicy.nowHours()
    return IKST_ClaimPolicy.nowUnix()
end

function IKST_ClaimPolicy.isLegacyStamp(value)
    local n = tonumber(value)
    return n ~= nil and n > 0 and n < LEGACY_STAMP_MAX
end

-- Old saves used world-age hours. Reset those stamps onto the calendar clock.
function IKST_ClaimPolicy.migrateEntryClock(entry)
    if not entry then
        return false
    end
    if not (IKST_ClaimPolicy.isLegacyStamp(entry.claimedAt)
        or IKST_ClaimPolicy.isLegacyStamp(entry.lastActiveAt)
        or IKST_ClaimPolicy.isLegacyStamp(entry.expiresAt)) then
        return false
    end
    local now = IKST_ClaimPolicy.nowUnix()
    entry.claimedAt = now
    entry.lastActiveAt = now
    entry.expiresAt = IKST_ClaimPolicy.computeExpiresAt(entry)
    return true
end

-- Fixed lease from claimedAt and/or inactivity from lastActiveAt. Whichever ends first.
-- All stamps are real-life unix seconds.
function IKST_ClaimPolicy.computeExpiresAt(entry)
    if not entry then
        return nil
    end
    local now = IKST_ClaimPolicy.nowUnix()
    local claimedAt = tonumber(entry.claimedAt) or now
    local lastActive = tonumber(entry.lastActiveAt) or claimedAt
    local fixedSec = IKST_ClaimPolicy.claimDurationSeconds()
    local inactiveSec = IKST_ClaimPolicy.inactivitySeconds()
    local fixedExp = nil
    local inactiveExp = nil
    if fixedSec > 0 then
        fixedExp = claimedAt + fixedSec
    end
    if inactiveSec > 0 then
        inactiveExp = lastActive + inactiveSec
    end
    if fixedExp and inactiveExp then
        if fixedExp < inactiveExp then
            return fixedExp
        end
        return inactiveExp
    end
    return fixedExp or inactiveExp
end

function IKST_ClaimPolicy.initClaimTimes(entry)
    if not entry then
        return nil
    end
    IKST_ClaimPolicy.migrateEntryClock(entry)
    local now = IKST_ClaimPolicy.nowUnix()
    entry.claimedAt = tonumber(entry.claimedAt) or now
    entry.lastActiveAt = tonumber(entry.lastActiveAt) or entry.claimedAt
    entry.expiresAt = IKST_ClaimPolicy.computeExpiresAt(entry)
    return entry
end

-- Refresh activity clock. Only writes when at least one real hour passed (keeps traffic low).
function IKST_ClaimPolicy.touchActivity(entry, force)
    if not entry then
        return false
    end
    if IKST_ClaimPolicy.inactivitySeconds() <= 0 then
        return false
    end
    IKST_ClaimPolicy.migrateEntryClock(entry)
    local now = IKST_ClaimPolicy.nowUnix()
    local last = tonumber(entry.lastActiveAt) or 0
    if not force and (now - last) < 3600 then
        return false
    end
    entry.lastActiveAt = now
    if not entry.claimedAt then
        entry.claimedAt = now
    end
    entry.expiresAt = IKST_ClaimPolicy.computeExpiresAt(entry)
    return true
end

function IKST_ClaimPolicy.expiresAtFromNow()
    return IKST_ClaimPolicy.computeExpiresAt({
        claimedAt = IKST_ClaimPolicy.nowUnix(),
        lastActiveAt = IKST_ClaimPolicy.nowUnix(),
    })
end

function IKST_ClaimPolicy.isExpired(expiresAt)
    if expiresAt == nil then
        return false
    end
    if IKST_ClaimPolicy.isLegacyStamp(expiresAt) then
        return true
    end
    return IKST_ClaimPolicy.nowUnix() >= tonumber(expiresAt)
end

-- Remaining time in real-life hours (for UI / snapshots).
function IKST_ClaimPolicy.hoursRemaining(expiresAt)
    if expiresAt == nil then
        return nil
    end
    if IKST_ClaimPolicy.isLegacyStamp(expiresAt) then
        return 0
    end
    local remainSec = tonumber(expiresAt) - IKST_ClaimPolicy.nowUnix()
    if remainSec <= 0 then
        return 0
    end
    return remainSec / 3600
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

-- Map short server codes to plain player/admin text (existing UI shows args.message as-is).
function IKST_ClaimPolicy.friendlyMessage(message)
    if message == nil or message == "" then
        return ""
    end
    local key = tostring(message)
    if string.find(key, "rect claim failed", 1, true) == 1 then
        return "Could not claim that rectangle. Try Whole building or another spot."
    end
    local map = {
        ["server only"] = "That action must run on the server.",
        ["no vehicle selected"] = "No vehicle selected.",
        ["no vehicle nearby - pick one in the list"] = "No vehicle nearby. Stand closer or pick one in the list.",
        ["no owner"] = "No owner found.",
        ["no new owner"] = "Enter a new owner.",
        ["already claimed"] = "That vehicle is already claimed.",
        ["max vehicle claims"] = "You already have the maximum number of vehicle claims.",
        ["max claims"] = "That player already has the maximum number of claims.",
        ["max safehouse claims"] = "You already have the maximum number of house claims.",
        ["vehicle identity missing"] = "Could not identify that vehicle. Try again.",
        ["not claimed"] = "That is not claimed.",
        ["not your claim"] = "That claim is not yours.",
        ["not your safehouse"] = "That safehouse is not yours.",
        ["same owner"] = "That player already owns it.",
        ["staff must approve claims"] = "Players cannot claim freely. Ask staff, or turn on the matching self-service sandbox option.",
        ["house claim requests disabled"] = "House claim requests are disabled on this server.",
        ["vehicle claim requests disabled"] = "Vehicle claim requests are disabled on this server.",
        ["house self-claim disabled"] = "House self-claim is disabled on this server.",
        ["vehicle self-claim disabled"] = "Vehicle self-claim is disabled on this server.",
        ["too far"] = "Too far away.",
        ["need vehicle key to claim"] = "You need the vehicle key to claim it.",
        ["sit in the vehicle to claim it"] = "Sit in the vehicle to claim it.",
        ["start the engine to claim"] = "Start the engine to claim this vehicle.",
        ["admin only"] = "Staff only.",
        ["username required"] = "Enter a player name.",
        ["claimed"] = "Vehicle claimed.",
        ["released"] = "Claim released.",
        ["transferred"] = "Claim transferred.",
        ["safehouse already here"] = "This area is already claimed.",
        ["invalid square"] = "Stand on a valid square to claim.",
        ["residential buildings only"] = "Only residential buildings can be claimed this way.",
        ["claim on road"] = "That claim covers a road. Move it off the street.",
        ["too close to safehouse"] = "Too close to another safehouse. Leave space for others.",
        ["claim too small"] = "Claim area is too small.",
        ["claim too large"] = "Claim area is too large.",
        ["claim must be square"] = "Claim must be roughly square on this server.",
        ["borders updated"] = "Claim request borders updated.",
        ["vehicle request has no land borders"] = "Vehicle requests have no land borders.",
        ["player must be online for indoor claim"] = "That player must be online for an indoor claim.",
        ["player must be online to claim"] = "You must be online to claim.",
        ["not allowed to claim yet"] = "You are not allowed to claim a safehouse yet.",
        ["not found"] = "Safehouse not found.",
        ["claim failed"] = "Claim failed. Try another spot or Whole building.",
        ["release failed"] = "Could not release that safehouse.",
        ["no SafeHouse API"] = "Safehouse system is not available.",
        ["no username"] = "Enter a player name.",
        ["no member name"] = "Enter a member name.",
        ["no backup"] = "No safehouse backup found.",
        ["safehouse claimed"] = "Safehouse claimed.",
        ["safehouse not found"] = "Safehouse not found.",
        ["no invite permission"] = "You cannot invite people to this safehouse.",
        ["rect claim failed - try Whole building or another spot"] = "Could not claim that rectangle. Try Whole building or another spot.",
        ["addPlayer unavailable"] = "Cannot add that member right now.",
        ["removePlayer unavailable"] = "Cannot remove that member right now.",
        ["safehouse respawn disabled"] = "Safehouse respawn is turned off.",
        ["respawn flag required"] = "Respawn setting is missing.",
        ["respawn unavailable"] = "Respawn is not available here.",
        ["group permissions saved"] = "Group permissions saved.",
        ["user permissions saved"] = "Player permissions saved.",
        ["user removed"] = "Player removed from claim.",
        ["label set"] = "Label updated.",
        ["invalid permission scope"] = "Invalid permission scope.",
    }
    return map[key] or key
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
    local meta = {
        owner = owner,
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
        w = math.floor(tonumber(w) or 0),
        h = math.floor(tonumber(h) or 0),
    }
    IKST_ClaimPolicy.initClaimTimes(meta)
    IKST_ClaimPolicy.safehouseMetaStore()[key] = meta
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
    local inactive = IKST_ClaimPolicy.inactivityDays()
    local vText = maxV > 0 and tostring(maxV) or IKST.text("IGUI_IKST_Claim_Unlimited", "unlimited")
    local sText = maxS > 0 and tostring(maxS) or IKST.text("IGUI_IKST_Claim_Unlimited", "unlimited")
    local dText = days > 0
        and (tostring(days) .. " " .. IKST.text("IGUI_IKST_Claim_Days", "days"))
        or IKST.text("IGUI_IKST_Claim_NoExpiry", "no expiry")
    if inactive > 0 then
        dText = dText .. " / " .. tostring(inactive) .. "d idle"
    end
    local fmt = IKST.text("IGUI_IKST_Claim_LimitsFmt", "Vehicles: {1}  Safehouses: {2}  Duration: {3}")
    fmt = string.gsub(fmt, "{1}", vText)
    fmt = string.gsub(fmt, "{2}", sText)
    fmt = string.gsub(fmt, "{3}", dText)
    return fmt
end
