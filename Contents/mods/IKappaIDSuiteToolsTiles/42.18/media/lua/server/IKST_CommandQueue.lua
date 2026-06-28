if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Lifecycle"

IKST_CommandQueue = IKST_CommandQueue or {}
IKST_CommandQueue.queues = IKST_CommandQueue.queues or {}
IKST_CommandQueue.OPS_PER_TICK = 8
IKST_CommandQueue._tickHooked = false

function IKST_CommandQueue.getKey(player)
    if not player or not player.getOnlineID then
        return "0"
    end
    return tostring(player:getOnlineID())
end

function IKST_CommandQueue.ensureTick()
    if IKST_CommandQueue._tickHooked then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(IKST_CommandQueue.onTick)
        IKST_CommandQueue._tickHooked = true
    end
end

function IKST_CommandQueue.finishJob(q, job)
    if job.onComplete then
        job.onComplete(job.results)
    end
    table.remove(q.pending, 1)
    if q.pending[1] then
        q.pending[1].index = 0
    else
        q.running = false
    end
end

function IKST_CommandQueue.processQueue(key, budget)
    local q = IKST_CommandQueue.queues[key]
    if not q or not q.running or not q.pending[1] then
        return
    end

    while budget > 0 do
        local job = q.pending[1]
        if not job then
            q.running = false
            return
        end

        job.index = job.index + 1
        if job.index > job.total then
            IKST_CommandQueue.finishJob(q, job)
            budget = budget - 1
            if not q.pending[1] then
                return
            end
        else
            local item = job.items[job.index]
            local ok, msg = job.handler(item)
            job.results[#job.results + 1] = { ok = ok, msg = msg, item = item }
            local player = job.player
            if player then
                IKST.deliverClientCommand(player, IKST.CMD.batchProgress, {
                    label = job.label,
                    index = job.index,
                    total = job.total,
                    ok = ok,
                    msg = msg,
                })
            end
            budget = budget - 1
        end
    end
end

function IKST_CommandQueue.onTick()
    if IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
        return
    end
    for key, q in pairs(IKST_CommandQueue.queues) do
        if q.running and q.pending[1] then
            IKST_CommandQueue.processQueue(key, IKST_CommandQueue.OPS_PER_TICK)
        elseif not q.running and q.pending[1] then
            q.running = true
        end
    end
end

function IKST_CommandQueue.enqueue(player, label, items, handler, onComplete)
    local key = IKST_CommandQueue.getKey(player)
    if not IKST_CommandQueue.queues[key] then
        IKST_CommandQueue.queues[key] = { running = false, pending = {} }
    end
    local q = IKST_CommandQueue.queues[key]
    q.pending[#q.pending + 1] = {
        player = player,
        label = label,
        items = items,
        handler = handler,
        onComplete = onComplete,
        index = 0,
        total = items and #items or 0,
        results = {},
    }
    IKST_CommandQueue.ensureTick()
    if not q.running then
        q.running = true
    end
end

function IKST_CommandQueue.clearAll()
    IKST_CommandQueue.queues = {}
end

-- Legacy entry point (starts async processing via OnTick).
function IKST_CommandQueue.pump(player)
    local key = IKST_CommandQueue.getKey(player)
    local q = IKST_CommandQueue.queues[key]
    if q and q.pending[1] and not q.running then
        q.running = true
    end
    IKST_CommandQueue.ensureTick()
end

