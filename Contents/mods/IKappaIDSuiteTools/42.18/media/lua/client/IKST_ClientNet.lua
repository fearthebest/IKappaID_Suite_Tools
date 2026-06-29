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

function IKST_ClientNet.push(player, command, args)
    IKST_ClientNet._pending[#IKST_ClientNet._pending + 1] = {
        player = IKST.resolvePlayer(player),
        command = command,
        args = args or {},
    }
    IKST_ClientNet.ensureTick()
    IKST_ClientNet.pump()
end

function IKST_ClientNet.pump()
    if IKST_ClientNet._waitTicks > 0 or #IKST_ClientNet._pending == 0 then
        return
    end
    local job = table.remove(IKST_ClientNet._pending, 1)
    if not job or not job.player or not job.command or not sendClientCommand then
        return
    end
    -- Remote MP client JVM: player-first sendClientCommand.
    if IKST_Debug and IKST_Debug.logNet then
        IKST_Debug.logNet("client->server", job.command, job.player, job.args, "send")
    end
    sendClientCommand(job.player, IKST.MODULE, job.command, job.args)
    IKST_ClientNet._waitTicks = IKST_ClientNet._gapTicks
end

function IKST_ClientNet.onTick()
    if IKST_ClientNet._waitTicks > 0 then
        IKST_ClientNet._waitTicks = IKST_ClientNet._waitTicks - 1
    end
    IKST_ClientNet.pump()
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

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_ClientNet.ensureTick)
end
IKST_ClientNet.ensureTick()
