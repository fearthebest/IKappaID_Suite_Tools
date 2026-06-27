-- Gate IKST world mutations until the map has finished loading (OnGameStart).

require "IKST_Shared"

IKST_Lifecycle = IKST_Lifecycle or {}
IKST_Lifecycle.worldReady = false

function IKST_Lifecycle.isWorldReady()
    return IKST_Lifecycle.worldReady == true
end

local function onPreMapLoad()
    IKST_Lifecycle.worldReady = false
    if IKST_CommandQueue and IKST_CommandQueue.clearAll then
        IKST_CommandQueue.clearAll()
    end
    if IKST_TilesWorldOps and IKST_TilesWorldOps.endBatch then
        IKST_TilesWorldOps.endBatch()
    end
end

local function onGameStart()
    IKST_Lifecycle.worldReady = true
end

if Events then
    if Events.OnPreMapLoad and Events.OnPreMapLoad.Add then
        Events.OnPreMapLoad.Add(onPreMapLoad)
    end
    if Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(onGameStart)
    end
end
