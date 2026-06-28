-- Gate IKST world mutations until the map has finished loading (OnGameStart / server ready).

require "IKST_Shared"

IKST_Lifecycle = IKST_Lifecycle or {}
IKST_Lifecycle.worldReady = false

function IKST_Lifecycle.probeWorldReady()
    if getCell then
        local cell = getCell()
        if cell then
            return true
        end
    end
    if getWorld then
        local world = getWorld()
        if world and world.getCell then
            local cell = world:getCell()
            if cell then
                return true
            end
        end
    end
    return false
end

function IKST_Lifecycle.isWorldReady()
    if IKST_Lifecycle.worldReady == true then
        return true
    end
    if IKST_Lifecycle.probeWorldReady() then
        IKST_Lifecycle.worldReady = true
        return true
    end
    return false
end

local function markWorldReady()
    IKST_Lifecycle.worldReady = true
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
    markWorldReady()
end

local function onServerStarted()
    markWorldReady()
end

if Events then
    if Events.OnPreMapLoad and Events.OnPreMapLoad.Add then
        Events.OnPreMapLoad.Add(onPreMapLoad)
    end
    if Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(onGameStart)
    end
    if Events.OnServerStarted and Events.OnServerStarted.Add then
        Events.OnServerStarted.Add(onServerStarted)
    end
end

if IKST_Lifecycle.probeWorldReady() then
    markWorldReady()
end
