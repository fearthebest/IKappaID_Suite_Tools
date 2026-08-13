-- Vanilla server tickets (ServerWorldDatabase.addTicket).
-- Wiki/JavaDocs: addTicket(author, message, ticketID). Vanilla client uses ticketID -1.
-- Staff review stays vanilla F1 See Tickets (ISAdminTicketsUI.getTickets(nil)).
-- Labels are stamped on the server only. Never call safehouseClaim from a request.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Authority"
require "IKST_Identity"
require "IKST_Args"
require "IKST_Access"
require "IKST_Claim"

IKST_Tickets = IKST_Tickets or {}

local MESSAGE_MAX = 512
local COORD_ABS_MAX = 100000

IKST_Tickets.LABELS = {
    report = true,
    dispute = true,
    ["claim-request"] = true,
    delivery = true,
    bounty = true,
}

local function coordInRange(n)
    return n ~= nil and n > -COORD_ABS_MAX and n < COORD_ABS_MAX
end

function IKST_Tickets.submit(player, message, label)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false, "multiplayer only"
    end
    if not player then
        return false, "no player"
    end
    local author = nil
    if IKST_Identity and type(IKST_Identity.username) == "function" then
        author = IKST_Identity.username(player)
    end
    if not author or author == "" then
        return false, "no username"
    end
    if label ~= nil then
        label = tostring(label)
        if not IKST_Tickets.LABELS[label] then
            return false, "bad label"
        end
    end
    message = tostring(message or "")
    message = string.gsub(message, "^%s*(.-)%s*$", "%1")
    if message == "" then
        return false, "enter a message"
    end
    if #message > MESSAGE_MAX then
        message = string.sub(message, 1, MESSAGE_MAX)
    end
    local x = math.floor(player:getX())
    local y = math.floor(player:getY())
    local z = player:getZ() or 0
    local tag = ""
    if label then
        tag = "[" .. label .. "] "
    end
    local body = string.format("%s[%d,%d,%d] %s", tag, x, y, z, message)
    local db = ServerWorldDatabase and ServerWorldDatabase.instance
    if not db or type(db.addTicket) ~= "function" then
        return false, "tickets unavailable"
    end
    db:addTicket(author, body, -1)
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "ticket", message, true)
    end
    return true, "ticket sent"
end

-- Derive an axis-aligned zone from two corners and file a staff ticket.
-- Does not create a safehouse. Admin must claim after review.
function IKST_Tickets.requestClaim(player, args)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not player then
        return false, "no player"
    end
    local x1 = IKST_Args.readCoord(args, "x1")
    local y1 = IKST_Args.readCoord(args, "y1")
    local z1 = IKST_Args.readCoord(args, "z1")
    local x2 = IKST_Args.readCoord(args, "x2")
    local y2 = IKST_Args.readCoord(args, "y2")
    local z2 = IKST_Args.readCoord(args, "z2")
    if not coordInRange(x1) or not coordInRange(y1) or z1 == nil
        or not coordInRange(x2) or not coordInRange(y2) or z2 == nil then
        return false, "need both corners"
    end
    if z1 < -1 or z1 > 32 or z2 < -1 or z2 > 32 then
        return false, "need both corners"
    end
    local dist = 8
    if IKST_Access and type(IKST_Access.sandboxInt) == "function" then
        dist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
    end
    if not IKST_Args.actorNearCoord(player, x2, y2, z2, dist) then
        return false, "stand at the end corner"
    end
    local ok, err, x, y, w, h = IKST_Claim.playerResidentialRect(x1, y1, z1, x2, y2, z2)
    if not ok then
        return false, err or "residential buildings only"
    end
    local msg = string.format(
        "residential A(%d,%d,%d) B(%d,%d,%d) house %d,%d %dx%d - admin must claim; not auto-approved",
        x1, y1, z1, x2, y2, z2, x, y, w, h
    )
    return IKST_Tickets.submit(player, msg, "claim-request")
end
