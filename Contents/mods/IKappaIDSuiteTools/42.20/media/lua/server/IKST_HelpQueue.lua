-- Thin player->staff help request queue (server ModData).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Authority"
require "IKST_Args"
require "IKST_Identity"

IKST_HelpQueue = IKST_HelpQueue or {}
IKST_HelpQueue.KEY = "IKST_HelpQueue"
IKST_HelpQueue.MAX = 40

function IKST_HelpQueue.store()
    local data = ModData.getOrCreate(IKST_HelpQueue.KEY)
    data.pending = data.pending or {}
    return data
end

function IKST_HelpQueue.submit(player, message)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not player then
        return false, "no player"
    end
    message = tostring(message or "")
    message = string.gsub(message, "^%s*(.-)%s*$", "%1")
    if message == "" then
        message = "Help requested"
    end
    if #message > 120 then
        message = string.sub(message, 1, 120)
    end
    local data = IKST_HelpQueue.store()
    local user = type(player.getUsername) == "function" and player:getUsername() or "?"
    -- One open request per player.
    for i = #data.pending, 1, -1 do
        if data.pending[i].user == user then
            table.remove(data.pending, i)
        end
    end
    data.pending[#data.pending + 1] = {
        id = tostring(getTimestampMs and getTimestampMs() or (getTimeInMillis and getTimeInMillis() or 0)) .. ":" .. user,
        user = user,
        message = message,
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = player:getZ() or 0,
        t = getTimestampMs and getTimestampMs() or 0,
    }
    while #data.pending > IKST_HelpQueue.MAX do
        table.remove(data.pending, 1)
    end
    if IKST_StaffHistory then
        IKST_StaffHistory.record(player, "help", message, true)
    end
    return true, "help request sent"
end

function IKST_HelpQueue.list()
    return IKST_HelpQueue.store().pending or {}
end

function IKST_HelpQueue.resolve(staff, requestId)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    requestId = tostring(requestId or "")
    local data = IKST_HelpQueue.store()
    for i = #data.pending, 1, -1 do
        if data.pending[i].id == requestId then
            table.remove(data.pending, i)
            if IKST_StaffHistory and staff then
                IKST_StaffHistory.record(staff, "help", "resolved " .. requestId, true)
            end
            return true, "resolved"
        end
    end
    return false, "not found"
end
