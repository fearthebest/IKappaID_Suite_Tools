-- Client JVM: queue outbound admin commands (module-first sendClientCommand for B42 SP).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Debug"

IKST_ClientNet = IKST_ClientNet or {}
IKST_ClientNet._pending = {}
IKST_ClientNet._gapTicks = 2
IKST_ClientNet._waitTicks = 0
IKST_ClientNet._tickHooked = false

-- Time/weather must not sit behind claim pings / list refreshes in the outbound queue.
IKST_ClientNet.PRIORITY = {
    setTime = true,
    setWeather = true,
    clearWeather = true,
}

function IKST_ClientNet.sendNow(player, command, args)
    if not player or not command or not sendClientCommand then
        return false
    end
    if IKST_Debug and IKST_Debug.logNet then
        IKST_Debug.logNet("client->server", command, player, args, "send-now")
    end
    sendClientCommand(player, IKST.MODULE, command, args or {})
    return true
end

function IKST_ClientNet.push(player, command, args)
    player = IKST.resolvePlayer(player)
    args = args or {}
    if command and IKST_ClientNet.PRIORITY[command] then
        IKST_ClientNet.sendNow(player, command, args)
        return
    end
    IKST_ClientNet._pending[#IKST_ClientNet._pending + 1] = {
        player = player,
        command = command,
        args = args,
    }
    IKST_ClientNet.ensureTick()
    IKST_ClientNet.pump()
end

function IKST_ClientNet.pump()
    if IKST_ClientNet._waitTicks > 0 or #IKST_ClientNet._pending == 0 then
        return
    end
    local job = table.remove(IKST_ClientNet._pending, 1)
    if not job or not job.player or not job.command then
        return
    end
    IKST_ClientNet.sendNow(job.player, job.command, job.args)
    IKST_ClientNet._waitTicks = IKST_ClientNet._gapTicks
end

function IKST_ClientNet.releaseTick()
    if not IKST_ClientNet._tickHooked then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(IKST_ClientNet.onTick)
    end
    IKST_ClientNet._tickHooked = false
end

function IKST_ClientNet.onTick()
    if IKST_ClientNet._waitTicks > 0 then
        IKST_ClientNet._waitTicks = IKST_ClientNet._waitTicks - 1
    end
    IKST_ClientNet.pump()
    if #IKST_ClientNet._pending == 0 and IKST_ClientNet._waitTicks <= 0 then
        IKST_ClientNet.releaseTick()
    end
end

function IKST_ClientNet.ensureTick()
    if IKST_ClientNet._tickHooked or not Events or not Events.OnTick then
        return
    end
    Events.OnTick.Add(IKST_ClientNet.onTick)
    IKST_ClientNet._tickHooked = true
end

function IKST.enqueueClientCommand(player, command, args)
    IKST_ClientNet.push(player, command, args)
end
