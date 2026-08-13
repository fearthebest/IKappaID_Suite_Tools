-- Vanilla MP kick / ban. Do not invent a custom ban file.
-- Wiki: https://pzwiki.net/wiki/Admin_commands (/kickuser, /banuser, /banid)
-- JavaDocs: GameServer.kick, GameServer.getConnectionFromPlayer,
-- ServerWorldDatabase.banUser / banSteamID, IsoPlayer.getSteamID,
-- SteamUtils.convertSteamIDToString
-- No IP ban (vanilla /banuser -ip) — shared NATs; ask before adding.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Identity"
require "IKST_StaffOps"
require "IKST_Access"

IKST_AdminOps = IKST_AdminOps or {}

local REASON_MAX = 64

local function trimReason(args, fallback)
    local r = args and args.reason
    if r == nil then
        return fallback
    end
    r = tostring(r)
    r = string.gsub(r, "^%s*(.-)%s*$", "%1")
    if r == "" then
        return fallback
    end
    if #r > REASON_MAX then
        r = string.sub(r, 1, REASON_MAX)
    end
    return r
end

local function samePlayer(a, b)
    if not a or not b then
        return false
    end
    if type(a.getOnlineID) == "function" and type(b.getOnlineID) == "function" then
        return a:getOnlineID() == b:getOnlineID()
    end
    return a == b
end

local function steamIdString(player)
    if not player or type(player.getSteamID) ~= "function" then
        return nil
    end
    if not SteamUtils or type(SteamUtils.convertSteamIDToString) ~= "function" then
        return nil
    end
    local s = SteamUtils.convertSteamIDToString(player:getSteamID())
    if not s or s == "" or s == "0" then
        return nil
    end
    if type(SteamUtils.isValidSteamID) == "function" and not SteamUtils.isValidSteamID(s) then
        return nil
    end
    return s
end

local function connectionFor(player)
    if not GameServer or type(GameServer.getConnectionFromPlayer) ~= "function" then
        return nil
    end
    return GameServer.getConnectionFromPlayer(player)
end

local function resolveTarget(args)
    if not IKST_StaffOps or type(IKST_StaffOps.findPlayerByOnlineID) ~= "function" then
        return nil
    end
    return IKST_StaffOps.findPlayerByOnlineID(args and args.target)
end

function IKST_AdminOps.kickPlayer(actor, target, reason)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false, "multiplayer only"
    end
    if not target then
        return false, "target offline"
    end
    if samePlayer(actor, target) then
        return false, "cannot kick yourself"
    end
    if IKST_Access and type(IKST_Access.isAdmin) == "function" and IKST_Access.isAdmin(target) then
        return false, "cannot kick admin"
    end
    if not GameServer or type(GameServer.kick) ~= "function" then
        return false, "kick unavailable"
    end
    local conn = connectionFor(target)
    if not conn then
        return false, "no connection"
    end
    GameServer.kick(conn, "UI_Policy_Kick", reason or "Kicked by admin")
    local label = "player"
    if IKST_Identity and type(IKST_Identity.displayLabel) == "function" then
        label = IKST_Identity.displayLabel(target) or label
    end
    return true, "Kicked " .. label
end

function IKST_AdminOps.banPlayer(actor, target, reason)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false, "multiplayer only"
    end
    if not target then
        return false, "target offline"
    end
    if samePlayer(actor, target) then
        return false, "cannot ban yourself"
    end
    if IKST_Access and type(IKST_Access.isAdmin) == "function" and IKST_Access.isAdmin(target) then
        return false, "cannot ban admin"
    end
    local username = nil
    if IKST_Identity and type(IKST_Identity.username) == "function" then
        username = IKST_Identity.username(target)
    end
    if not username or username == "" then
        return false, "no username"
    end
    local db = ServerWorldDatabase and ServerWorldDatabase.instance
    if not db or type(db.banUser) ~= "function" then
        return false, "ban unavailable"
    end
    reason = reason or "Banned by admin"
    db:banUser(username, true)
    local steam = steamIdString(target)
    if steam and type(db.banSteamID) == "function" then
        db:banSteamID(steam, reason, true)
    end
    local conn = connectionFor(target)
    if conn and GameServer and type(GameServer.kick) == "function" then
        GameServer.kick(conn, "UI_Policy_Ban", reason)
    end
    return true, "Banned " .. username
end

function IKST_AdminOps.handle(command, player, args)
    args = args or {}
    if command == IKST.CMD.kickPlayer then
        return IKST_AdminOps.kickPlayer(player, resolveTarget(args), trimReason(args, "Kicked by admin"))
    end
    if command == IKST.CMD.banPlayer then
        return IKST_AdminOps.banPlayer(player, resolveTarget(args), trimReason(args, "Banned by admin"))
    end
    return false, "unknown command"
end
