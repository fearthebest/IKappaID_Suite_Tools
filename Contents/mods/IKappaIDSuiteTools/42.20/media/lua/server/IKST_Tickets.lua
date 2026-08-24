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

-- Claim requests use IKST_ClaimRequestQueue (ModData), not vanilla tickets.
function IKST_Tickets.requestClaim(player, args)
    if IKST_ClaimRequestQueue and type(IKST_ClaimRequestQueue.submit) == "function" then
        return IKST_ClaimRequestQueue.submit(player, args)
    end
    return false, "claim request queue unavailable"
end
