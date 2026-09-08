if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_JobLayout"

-- Soft shell is the only live hub. JobsPanel must never spawn dock UI.
-- SoftTools (IKST_SoftTool_*) own soft body paint via SoftPageHost + IKUI_SoftBody.
-- This file only redirects open/toggle → Hub (legacy callers).
IKST_JobsPanel = IKST_JobsPanel or {}
IKST_JobsPanel.instance = nil

do
    local defW, defH = IKST_JobLayout.defaultSize()
    IKST_JobsPanel.WIDTH = defW
    IKST_JobsPanel.HEIGHT = defH
end
IKST_JobsPanel.MIN_WIDTH = IKST_JobLayout.MIN_WIDTH
IKST_JobsPanel.MIN_HEIGHT = IKST_JobLayout.MIN_HEIGHT

function IKST_JobsPanel.ensure()
    return nil
end

function IKST_JobsPanel.prepareOpen(player)
    if IKST_Hub and type(IKST_Hub.open) == "function" then
        return IKST_Hub.open(player)
    end
    return nil
end

function IKST_JobsPanel.applyOpenView(_panel, _player)
end

function IKST_JobsPanel.open(player)
    if IKST_Hub and type(IKST_Hub.open) == "function" then
        return IKST_Hub.open(player)
    end
end

function IKST_JobsPanel.toggle(player)
    if IKST_Hub and type(IKST_Hub.toggle) == "function" then
        return IKST_Hub.toggle(player)
    end
end

local function onArmedEscapeKey(key)
    if not Keyboard or key ~= Keyboard.KEY_ESCAPE then
        return
    end
    local panel = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
    local hubOpen = IKST_Hub and type(IKST_Hub.isOpenVisible) == "function" and IKST_Hub.isOpenVisible()
    if not hubOpen then
        return
    end
    local player = panel and panel.player or nil
    local state = player and IKST.getPlayerState(player) or nil
    if state and state.armed and state.armedJob then
        if panel and type(panel.stopArmedMode) == "function" then
            panel:stopArmedMode()
        elseif IKST_Hub and type(IKST_Hub.disarmWorldTools) == "function" then
            IKST_Hub.disarmWorldTools(player)
            if type(IKST_Hub.refreshActive) == "function" then
                IKST_Hub.refreshActive()
            end
        end
    end
end

if Events and Events.OnKeyPressed and Events.OnKeyPressed.Add then
    Events.OnKeyPressed.Add(onArmedEscapeKey)
end
