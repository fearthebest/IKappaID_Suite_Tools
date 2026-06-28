if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_JobsPanel"
require "IKST_Access"

IKST_AdminChat = IKST_AdminChat or {}

local function utilityChat(player, which, args)
    local on = args[1] ~= "off"
    if IKST.setUtilityExplicit(which, on) then
        IKST.notifyUtilityToggle(player, which, on)
    end
end

IKST_AdminChat.COMMANDS = {
    { cmds = { "catch" }, fn = function(player, args)
        IKST.dispatchCommand(player, IKST.CMD.catchPlayer, { username = args[1] })
    end },
    { cmds = { "release" }, fn = function(player, args)
        IKST.dispatchCommand(player, IKST.CMD.releasePlayer, { username = args[1] })
    end },
    { cmds = { "power", "serverpower" }, fn = function(player, args)
        utilityChat(player, "power", args)
    end },
    { cmds = { "water", "serverwater" }, fn = function(player, args)
        utilityChat(player, "water", args)
    end },
    { cmds = { "killallzombies" }, fn = function(player, args)
        IKST.dispatchCommand(player, IKST.CMD.threatCull, {
            x = math.floor(player:getX()), y = math.floor(player:getY()), z = player:getZ(),
            radius = IKST.RADIUS_PRESETS.L,
            maxPerTick = tonumber(args[1]) or 200,
        })
    end },
    { cmds = { "creative" }, fn = function(player, args)
        if args[1] == "on" or args[1] == "off" then
            -- force state via toggle if mismatch
        end
        IKST.dispatchCommand(player, IKST.CMD.toggleCreative, {})
    end },
    { cmds = { "backup" }, fn = function(player)
        IKST.dispatchCommand(player, IKST.CMD.backupSafehouses, {})
    end },
    { cmds = { "restore" }, fn = function(player)
        IKST.dispatchCommand(player, IKST.CMD.restoreSafehouses, {})
    end },
    { cmds = { "ikst", "suite" }, fn = function(player)
        IKST_JobsPanel.open(player)
    end },
}

function IKST_AdminChat.splitArgs(text)
    local parts = {}
    for part in string.gmatch(text, "%S+") do
        parts[#parts + 1] = part
    end
    return parts
end

function IKST_AdminChat.tryHandle(player, text)
    if not text or text:sub(1, 1) ~= "/" then
        return false
    end
    if not player then
        return false
    end
    local body = text:sub(2)
    local parts = IKST_AdminChat.splitArgs(body)
    if #parts == 0 then
        return false
    end
    local cmd = string.lower(parts[1])
    table.remove(parts, 1)
    for _, entry in ipairs(IKST_AdminChat.COMMANDS) do
        for _, name in ipairs(entry.cmds) do
            if cmd == name then
                if name == "water" or name == "serverwater" or name == "power" or name == "serverpower" then
                    if not IKST_Access.canToggleUtilities(player) then
                        return false
                    end
                elseif not IKST_Access.canUseTools(player) then
                    return false
                end
                entry.fn(player, parts)
                return true
            end
        end
    end
    return false
end

function IKST_AdminChat.onAddMessage(message, tabId)
    local player = getPlayer and getPlayer() or nil
    if not player or type(message) ~= "string" then
        return
    end
    if IKST_AdminChat.tryHandle(player, message) then
        return true
    end
    return false
end

function IKST_AdminChat.wrapSend()
    if IKST_AdminChat.wrapped or not ISChat or not ISChat.sendMessage then
        return
    end
    IKST_AdminChat.wrapped = true
    local vanilla = ISChat.sendMessage
    ISChat.sendMessage = function(self, message, ...)
        local player = getPlayer and getPlayer() or nil
        if player and IKST_AdminChat.tryHandle(player, message) then
            return
        end
        return vanilla(self, message, ...)
    end
end

function IKST_AdminChat.init()
    if not ISChat then
        return
    end
    IKST_AdminChat.wrapSend()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if ISChat then
            IKST_AdminChat.init()
            return
        end
        if Events.OnTick then
            local hooked
            local function waitForChat()
                if hooked or ISChat then
                    if not hooked and ISChat then
                        hooked = true
                        IKST_AdminChat.init()
                    end
                    if hooked and Events.OnTick then
                        Events.OnTick.Remove(waitForChat)
                    end
                end
            end
            Events.OnTick.Add(waitForChat)
        end
    end)
end
