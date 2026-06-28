if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_PaintCursorClass"

IKST_PaintCursorManager = IKST_PaintCursorManager or {}

function IKST_PaintCursorManager.disarm(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    local cell = getCell and getCell()
    if cell and cell.setDrag then
        cell:setDrag(nil, player:getPlayerNum())
    end
    local state = IKST.getPlayerState(player)
    if state then
        state.armed = false
        state.armedJob = nil
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_PaintCursorManager.arm(player, mode)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    if not IKST_Access.canUseTools(player) then
        IKST.notify(player, "Admin access required", false)
        return
    end
    if not IKST.ensurePaintCursor() then
        IKST.notify(player, "Paint tool failed to load", false)
        return
    end
    if IKST_WorldPick and IKST_WorldPick.disarm then
        IKST_WorldPick.disarm(player)
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    state.painterMode = mode
    state.armed = true
    state.armedJob = IKST.VIEW.painter
    state.job = IKST.VIEW.painter
    if not IKST_PaintCursorManager.cursor then
        IKST_PaintCursorManager.cursor = IKST_PaintCursor:new(player, mode)
    else
        IKST_PaintCursorManager.cursor.character = player
        IKST_PaintCursorManager.cursor:setMode(mode)
    end
    if getCell and getCell().setDrag then
        getCell():setDrag(IKST_PaintCursorManager.cursor, player:getPlayerNum())
    end
    IKST.notify(player, IKST.text("IGUI_IKST_ClickWorld", "Click a world square"), true)
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
    IKST_PaintCursorManager.syncSprite(player)
end

function IKST_PaintCursorManager.syncSprite(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    local cursor = IKST_PaintCursorManager.cursor
    if not cursor or not cursor.setSprite then
        return
    end
    local state = IKST.getPlayerState(player)
    local mode = state and state.painterMode
    if mode ~= IKST.PAINTER_MODES.paint and mode ~= IKST.PAINTER_MODES.replace then
        return
    end
    local pick = state.currentPick
    if not pick or not pick.sprite then
        return
    end
    cursor:setSprite(pick.sprite)
    if cursor.setNorthSprite then
        cursor:setNorthSprite(pick.sprite)
    end
end

function IKST_PaintCursorManager.setPick(player, sprite)
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    state.currentPick = { sprite = sprite, facing = "N", kind = "tile" }
    IKST.pushRecentSprite(player, state.currentPick)
    IKST_PaintCursorManager.syncSprite(player)
end
