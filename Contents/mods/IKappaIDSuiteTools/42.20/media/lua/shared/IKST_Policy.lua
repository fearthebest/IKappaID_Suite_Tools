-- Mod-wide gate schema: session role (SP / host / remote) + location (tile protect + claims).
-- Plugins pass an action string ("loot", "tiles", "vehicles", ...) for sandbox and bypass rules.

require "IKST_Shared"

IKST_Policy = IKST_Policy or {}

IKST_Policy.SESSION = {
    sp = "sp",
    host = "host",
    remote = "remote",
}

function IKST_Policy.sandboxBool(key, fallback)
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteTools
    local v = sv and sv[key]
    if v == nil then
        return fallback == true
    end
    return v == true
end

function IKST_Policy.lootSandboxBool(key, fallback)
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsLoot
    local v = sv and sv[key]
    if v == nil then
        return fallback == true
    end
    return v == true
end

function IKST_Policy.tilesSandboxBool(key, fallback)
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    local v = sv and sv[key]
    if v == nil then
        return fallback == true
    end
    return v == true
end

function IKST_Policy.isHostPlayer(player)
    if not player then
        return false
    end
    if IKST.isCoopHostPlayer and IKST.isCoopHostPlayer(player) then
        return true
    end
    if type(player.isLocalPlayer) == "function" and player:isLocalPlayer() then
        if type(isCoopHost) == "function" and isCoopHost() then
            return true
        end
    end
    return false
end

-- JVM role (client display / SP). On server command handling use sessionRoleForPlayer(player).
function IKST_Policy.sessionRole()
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return IKST_Policy.SESSION.sp
    end
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        return IKST_Policy.SESSION.remote
    end
    return IKST_Policy.SESSION.host
end

function IKST_Policy.sessionRoleForPlayer(player)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return IKST_Policy.SESSION.sp
    end
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        return IKST_Policy.SESSION.remote
    end
    if IKST.isListenHostClient and IKST.isListenHostClient() then
        return IKST_Policy.SESSION.host
    end
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        if IKST_Policy.isHostPlayer(player) then
            return IKST_Policy.SESSION.host
        end
        return IKST_Policy.SESSION.remote
    end
    return IKST_Policy.SESSION.host
end

-- Map plugin action strings to safehouse permission keys.
function IKST_Policy.claimPermissionAction(action)
    if action == "loot" then
        return "loot"
    end
    if action == "economy" or action == "claim" then
        return "build"
    end
    return "destroy"
end

-- SP never requires claim permission. MP: core, loot, or tiles sandbox may enable it.
function IKST_Policy.respectClaims(action)
    if IKST_Policy.sessionRole() == IKST_Policy.SESSION.sp then
        return false
    end
    if IKST_Policy.sandboxBool("StaffRespectSafehouseClaims", false) then
        return true
    end
    if action == "loot" and IKST_Policy.lootSandboxBool("LootRespectSafehouseClaims", false) then
        return true
    end
    if action == "tiles" and IKST_Policy.tilesSandboxBool("ProtectClaimedSafehouses", false) then
        return true
    end
    return false
end

function IKST_Policy.ensureAccess()
    if not IKST_Access then
        require "IKST_Access"
    end
end

function IKST_Policy.ensureClaimPolicy()
    if not IKST_ClaimPolicy then
        require "IKST_ClaimPolicy"
    end
end

function IKST_Policy.staffTileBypass(player, action)
    if not player or not action then
        return false
    end
    IKST_Policy.ensureAccess()
    -- Staff loot tool must refill protected/readonly admin squares (protect is for players).
    if action == "loot" and IKST_Access.canUseLoot and IKST_Access.canUseLoot(player) then
        return true
    end
    if action == "tiles" and IKST_Access.canUseStaffTools and IKST_Access.canUseStaffTools(player) then
        return true
    end
    if action == "vehicles" and IKST_Access.canUseStaffTools and IKST_Access.canUseStaffTools(player) then
        return true
    end
    return false
end

function IKST_Policy.staffClaimBypass(player)
    if not player then
        return false
    end
    IKST_Policy.ensureAccess()
    IKST_Policy.ensureClaimPolicy()
    if IKST_Access.canUseTools and IKST_Access.canUseTools(player)
        and IKST_ClaimPolicy.adminBypass and IKST_ClaimPolicy.adminBypass() then
        return true
    end
    return false
end

function IKST_Policy.tileBlockReason(x, y, z, player, action)
    if IKST_Policy.staffTileBypass(player, action) then
        return nil
    end
    if IKST.Plugins and IKST.Plugins.isActive("tiles") and not IKST_TileProtect then
        require "IKST_TileProtect"
    end
    if not IKST_TileProtect then
        return nil
    end
    if IKST_TileProtect.isTileProtected(x, y, z) then
        return "tile protected"
    end
    if IKST_TileProtect.isReadonly(x, y, z) then
        return "tile_readonly"
    end
    return nil
end

function IKST_Policy.tileLocationBlocked(x, y, z, player, action)
    return IKST_Policy.tileBlockReason(x, y, z, player, action) ~= nil
end

function IKST_Policy.claimLocationBlocked(player, square, action)
    if not IKST_Policy.respectClaims(action) then
        return false
    end
    if IKST_Policy.staffClaimBypass(player) then
        return false
    end
    if not square then
        return false
    end
    if not IKST_SafehouseClaim then
        require "IKST_SafehouseClaim"
    end
    if not IKST_SafehouseClaim or type(IKST_SafehouseClaim.entryForSquare) ~= "function" then
        return false
    end
    local entry = select(1, IKST_SafehouseClaim.entryForSquare(square))
    if not entry then
        return false
    end
    if type(IKST_SafehouseClaim.isEntryExpired) == "function"
        and IKST_SafehouseClaim.isEntryExpired(entry) then
        return false
    end
    if type(IKST_SafehouseClaim.canAtSquare) ~= "function" then
        return true
    end
    local permAction = IKST_Policy.claimPermissionAction(action)
    if IKST_SafehouseClaim.canAtSquare(player, square, permAction) == true then
        return false
    end
    return true
end

function IKST_Policy.logDenial(player, action, reason, x, y, z)
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and type(IKST_Debug.logAction) == "function" then
        IKST_Debug.logAction("policy", tostring(action), player,
            "deny=" .. tostring(reason) .. " at " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
    end
end

function IKST_Policy.formatDenyMessage(code)
    local msg = tostring(code or "")
    if msg == "not_your_claim" then
        return IKST.text("IGUI_IKST_Policy_NotYourClaim", "That location is inside another player's claimed safe area")
    end
    if msg == "tile_readonly" then
        return IKST.text("IGUI_IKST_Policy_TileReadonly", "That square has storage lock (readonly) on")
    end
    if msg == "tile protected" then
        return IKST.text("IGUI_IKST_Policy_TileProtected", "That square is tile-protected")
    end
    if msg == "square protected" or msg == "claim protected" then
        return IKST.text("IGUI_IKST_Policy_SquareProtected", "That square is protected or readonly")
    end
    if msg == "too_far" or msg == "too far" or msg == "too far to paint" then
        return IKST.text("IGUI_IKST_Policy_TooFar", "Too far from that location")
    end
    if msg == "admin only" then
        return IKST.text("IGUI_IKST_Policy_AdminOnly", "Admin only")
    end
    if msg == "cannot kick admin" then
        return IKST.text("IGUI_IKST_Admin_CannotKickAdmin", "Cannot kick another admin")
    end
    if msg == "cannot ban admin" then
        return IKST.text("IGUI_IKST_Admin_CannotBanAdmin", "Cannot ban another admin")
    end
    if msg == "invalid square" or msg == "bad square" or msg == "no_square" then
        return IKST.text("IGUI_IKST_NoSquare", "No square under cursor")
    end
    if msg == "server only" then
        return IKST.text("IGUI_IKST_ServerOnly", "Server only")
    end
    if msg == "rate_limit" then
        return IKST.text("IGUI_IKST_Policy_RateLimit", "Too many requests - wait a moment")
    end
    if msg == "world_loading" then
        return IKST.text("IGUI_IKST_Policy_WorldLoading", "World is still loading")
    end
    if msg == "vehicle_claimed" or msg == "vehicle protected" or msg == "vehicle claimed" then
        return IKST.text("IGUI_IKST_Policy_VehicleClaimed", "That vehicle is protected or claimed")
    end
    if msg == "player_placed" then
        return IKST.text("IGUI_IKST_Loot_PlayerPlaced", "That container was placed or moved by a player")
    end
    if msg == "vehicle not found" then
        return IKST.text("IGUI_IKST_Policy_VehicleNotFound", "Vehicle not found")
    end
    return nil
end

-- Returns allowed, reasonCode (nil when allowed).
function IKST_Policy.locationAllowed(player, square, action)
    if not square then
        return false, "no_square"
    end
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    local blockReason = IKST_Policy.tileBlockReason(x, y, z, player, action)
    if blockReason then
        IKST_Policy.logDenial(player, action, blockReason, x, y, z)
        return false, blockReason
    end
    if IKST_Policy.claimLocationBlocked(player, square, action) then
        IKST_Policy.logDenial(player, action, "not_your_claim", x, y, z)
        return false, "not_your_claim"
    end
    return true, nil
end

function IKST_Policy.locationAllowedAtCoord(player, x, y, z, action)
    if not IKST_Grid then
        require "IKST_Grid"
    end
    local square = IKST_Grid and IKST_Grid.getSquare(math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), tonumber(z) or 0)
    return IKST_Policy.locationAllowed(player, square, action)
end

IKST.sessionRole = IKST_Policy.sessionRole
IKST.sessionRoleForPlayer = IKST_Policy.sessionRoleForPlayer
