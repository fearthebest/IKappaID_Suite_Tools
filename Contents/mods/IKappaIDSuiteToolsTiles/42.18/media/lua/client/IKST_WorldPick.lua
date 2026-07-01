-- Armed cleanup: world click via OnTick (integrated SP) + mouse events (remote client JVM).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Lifecycle"
require "IKST_Access"
require "IKST_Grid"
require "IKST_PreviewOverlay"
require "IKST_HubNav"

IKST_WorldPick = IKST_WorldPick or {}
IKST_WorldPick.activePlayer = nil
IKST_WorldPick.batchScope = nil
IKST_WorldPick.mouseHooked = false
IKST_WorldPick._pickCooldown = 0
IKST_WorldPick._mouseWasDown = false
IKST_WorldPick._deferScreenPick = 0
IKST_WorldPick._objectClickConsumed = false

function IKST_WorldPick.modeToCommand(mode)
    return IKST.actionToCommand(mode)
end

function IKST_WorldPick.objectIndexOnSquare(square, obj)
    if not square or not obj then
        return nil
    end
    if obj.getObjectIndex then
        local index = obj:getObjectIndex()
        if index ~= nil then
            return index
        end
    end
    local objects = square.getObjects and square:getObjects()
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        if objects:get(i) == obj then
            return i
        end
    end
    return nil
end

function IKST_WorldPick.dispatchCleanup(player, square, state, clickedObj)
    local action = IKST.getCleanupAction(state)
    local scope = IKST.getCleanupScope(state)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    if scope == IKST.CLEANUP_SCOPES.cube then
        IKST.dispatchCommand(player, IKST.CMD.cleanupCube, {
            x = x, y = y, z = z,
            halfExtent = state.cleanupCubeHalf,
            mode = action,
        })
        IKST_WorldPick.disarm(player)
        return true
    end
    if scope == IKST.CLEANUP_SCOPES.radius then
        IKST.dispatchCommand(player, IKST.CMD.cleanupRadius, {
            x = x, y = y, z = z,
            radius = state.cleanupRadius,
            mode = action,
        })
        IKST_WorldPick.disarm(player)
        return true
    end
    if scope == IKST.CLEANUP_SCOPES.room then
        IKST.dispatchCommand(player, IKST.CMD.cleanupRoom, {
            x = x, y = y, z = z, mode = action,
        })
        IKST_WorldPick.disarm(player)
        return true
    end
    if scope == IKST.CLEANUP_SCOPES.building then
        IKST.dispatchCommand(player, IKST.CMD.cleanupBuilding, {
            x = x, y = y, z = z, mode = action,
        })
        IKST_WorldPick.disarm(player)
        return true
    end
    if action == IKST.CLEANUP_MODES.vegetation and scope == IKST.CLEANUP_SCOPES.single then
        IKST.dispatchCommand(player, IKST.CMD.cleanupObject, {
            x = x, y = y, z = z,
            mode = action,
        })
        return true
    end
    if action == IKST.CLEANUP_MODES.vegetation then
        IKST.dispatchCommand(player, IKST.CMD.cleanupCube, {
            x = x, y = y, z = z,
            halfExtent = 0,
            mode = action,
        })
        return true
    end
    local payload = {
        x = x, y = y, z = z,
    }
    if clickedObj and scope == IKST.CLEANUP_SCOPES.single then
        local objectIndex = IKST_WorldPick.objectIndexOnSquare(square, clickedObj)
        if objectIndex ~= nil then
            payload.objectIndex = objectIndex
        end
    end
    IKST.dispatchCommand(player, IKST.actionToCommand(action), payload)
    return true
end

function IKST_WorldPick.isInspectorArmed(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseTools(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    return state and state.armed and state.armedJob == IKST.VIEW.inspector
end

function IKST_WorldPick.isWorldArmed(player)
    return IKST_WorldPick.isCleanupArmed(player) or IKST_WorldPick.isInspectorArmed(player)
end

function IKST_WorldPick.applyInspect(player, square)
    if not player or not square or not IKST_WorldPick.isInspectorArmed(player) then
        return false
    end
    IKST.dispatchCommand(player, IKST.CMD.inspectSquare, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    })
    return true
end

function IKST_WorldPick.tryInspectSquare(player, square, screenX, screenY, fromObject)
    if not fromObject and IKST_WorldPick._pickCooldown > 0 then
        return false
    end
    if not square and screenX ~= nil and screenY ~= nil then
        square = IKST_Grid.squareFromScreen(screenX, screenY, player)
    end
    if not square then
        return false
    end
    IKST_WorldPick._pickCooldown = 2
    if IKST_WorldPick.applyInspect(player, square) then
        return true
    end
    IKST_WorldPick._pickCooldown = 0
    return false
end

function IKST_WorldPick.isCleanupArmed(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseTools(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    return state and state.armed and state.armedJob == IKST.VIEW.cleanup
end

function IKST_WorldPick.isMouseOverPanel()
    local panel = IKST_JobsPanel and IKST_JobsPanel.instance
    if not panel or not panel.getIsVisible or not panel:getIsVisible() then
        return false
    end
    if not getMouseX or not getMouseY then
        return false
    end
    local mx = getMouseX()
    local my = getMouseY()
    local px = panel:getX()
    local py = panel:getY()
    return mx >= px and mx <= px + panel.width and my >= py and my <= py + panel.height
end

function IKST_WorldPick.applySquare(player, square, clickedObj)
    if not player or not square or not IKST_Access.canUseTools(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state or not state.armed or state.armedJob ~= IKST.VIEW.cleanup then
        return false
    end
    return IKST_WorldPick.dispatchCleanup(player, square, state, clickedObj)
end

function IKST_WorldPick.tryPickSquare(player, square, screenX, screenY, fromObject, clickedObj)
    if not fromObject and IKST_WorldPick._pickCooldown > 0 then
        return false
    end
    if not square and screenX ~= nil and screenY ~= nil then
        square = IKST_Grid.squareFromScreen(screenX, screenY, player)
    end
    if not square then
        return false
    end
    IKST_WorldPick._pickCooldown = 2
    if IKST_WorldPick.applySquare(player, square, clickedObj) then
        return true
    end
    IKST_WorldPick._pickCooldown = 0
    return false
end

function IKST_WorldPick.getMouseScreenXY()
    if getMouseXScaled and getMouseYScaled then
        return getMouseXScaled(), getMouseYScaled()
    end
    if getMouseX and getMouseY then
        return getMouseX(), getMouseY()
    end
    return nil, nil
end

function IKST_WorldPick.shouldShowHoverPreview(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    if IKST_WorldPick.isCleanupArmed(player) then
        return true
    end
    local state = IKST.getPlayerState(player)
    return state and state.job == IKST.VIEW.cleanup
end

function IKST_WorldPick.updateHoverPreview(player)
    if not IKST_PreviewOverlay then
        return
    end
    player = IKST.resolvePlayer(player or IKST_WorldPick.activePlayer)
    if not player or not IKST_WorldPick.shouldShowHoverPreview(player) then
        IKST_PreviewOverlay.clearHover()
        return
    end
    if IKST_WorldPick.isMouseOverPanel() then
        IKST_PreviewOverlay.clearHover()
        return
    end
    local mx, my = IKST_WorldPick.getMouseScreenXY()
    if mx == nil or my == nil then
        IKST_PreviewOverlay.clearHover()
        return
    end
    local square = IKST_Grid.squareFromScreen(mx, my, player)
    if not square then
        IKST_PreviewOverlay.clearHover()
        return
    end
    local state = IKST.getPlayerState(player)
    IKST_PreviewOverlay.setCleanupPreview(square, state, IKST_WorldPick.batchScope)
end

function IKST_WorldPick.handleWorldClick(screenX, screenY)
    local player = IKST_WorldPick.activePlayer
    if not IKST_WorldPick.isWorldArmed(player) then
        return false
    end
    if IKST_WorldPick.isMouseOverPanel() then
        return false
    end
    if IKST_WorldPick.isInspectorArmed(player) then
        if IKST_WorldPick.tryInspectSquare(player, nil, screenX, screenY) then
            return true
        end
        IKST.notify(player, IKST.text("IGUI_IKST_NoSquare", "No square under cursor"), false)
        return false
    end
    if IKST_WorldPick.tryPickSquare(player, nil, screenX, screenY) then
        return true
    end
    IKST.notify(player, IKST.text("IGUI_IKST_NoSquare", "No square under cursor"), false)
    return false
end

function IKST_WorldPick.onMouseDown(x, y)
    -- OnObjectLeftMouseButtonDown already dispatched for this click; skip second fire on MP clients.
    if IKST_WorldPick._objectClickConsumed then
        IKST_WorldPick._objectClickConsumed = false
        return
    end
    IKST_WorldPick.handleWorldClick(x, y)
end

function IKST_WorldPick.onObjectLeftMouseDown(obj, x, y)
    local player = IKST_WorldPick.activePlayer
    if not IKST_WorldPick.isWorldArmed(player) or IKST_WorldPick.isMouseOverPanel() then
        return
    end
    IKST_WorldPick._objectClickConsumed = true
    IKST_WorldPick._deferScreenPick = 0
    local square = IKST_Grid.squareFromObject(obj)
    if not square and IKST_Grid.isRoofObject(obj) and obj.getX and obj.getY and obj.getZ then
        square = IKST_Grid.getSquare(math.floor(obj:getX()), math.floor(obj:getY()), math.floor(obj:getZ()))
    end
    if IKST_WorldPick.isInspectorArmed(player) then
        IKST_WorldPick.tryInspectSquare(player, square, nil, nil, true)
    else
        IKST_WorldPick.tryPickSquare(player, square, nil, nil, true, obj)
    end
end

function IKST_WorldPick.onRenderTick()
    local player = IKST.resolvePlayer(IKST_WorldPick.activePlayer or getPlayer())
    if IKST_WorldPick.shouldShowHoverPreview(player) then
        IKST_WorldPick.updateHoverPreview(player)
    elseif IKST_PreviewOverlay then
        IKST_PreviewOverlay.clearHover()
    end
end

function IKST_WorldPick.onTick()
    if IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
        IKST_WorldPick._mouseWasDown = false
        IKST_WorldPick._deferScreenPick = 0
        IKST_WorldPick._objectClickConsumed = false
        return
    end
    if IKST_WorldPick._pickCooldown > 0 then
        IKST_WorldPick._pickCooldown = IKST_WorldPick._pickCooldown - 1
    end

    local player = IKST.resolvePlayer(IKST_WorldPick.activePlayer or getPlayer())
    if not IKST_WorldPick.isWorldArmed(player) then
        IKST_WorldPick._mouseWasDown = false
        IKST_WorldPick._deferScreenPick = 0
        IKST_WorldPick._objectClickConsumed = false
        return
    end

    if IKST_WorldPick._deferScreenPick > 0 then
        IKST_WorldPick._deferScreenPick = IKST_WorldPick._deferScreenPick - 1
        if IKST_WorldPick._deferScreenPick == 0 and not IKST_WorldPick._objectClickConsumed then
            local mx, my = IKST_WorldPick.getMouseScreenXY()
            if mx ~= nil and my ~= nil then
                IKST_WorldPick.handleWorldClick(mx, my)
            end
        end
        IKST_WorldPick._objectClickConsumed = false
    end

    if IKST.isRemoteClient() then
        return
    end

    local down = isMouseButtonDown and isMouseButtonDown(0)
    if down and not IKST_WorldPick._mouseWasDown then
        IKST_WorldPick._objectClickConsumed = false
        IKST_WorldPick._deferScreenPick = 1
    end
    if not down then
        IKST_WorldPick._deferScreenPick = 0
        IKST_WorldPick._objectClickConsumed = false
    end
    IKST_WorldPick._mouseWasDown = down == true
end

function IKST_WorldPick.ensureMouseHook()
    if IKST_WorldPick.mouseHooked then
        return
    end
    if IKST.isRemoteClient() then
        if Events and Events.OnMouseDown and Events.OnMouseDown.Add then
            Events.OnMouseDown.Add(IKST_WorldPick.onMouseDown)
        end
    end
    if Events and Events.OnObjectLeftMouseButtonDown and Events.OnObjectLeftMouseButtonDown.Add then
        Events.OnObjectLeftMouseButtonDown.Add(IKST_WorldPick.onObjectLeftMouseDown)
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(IKST_WorldPick.onTick)
    end
    if Events and Events.OnRenderTick and Events.OnRenderTick.Add then
        Events.OnRenderTick.Add(IKST_WorldPick.onRenderTick)
    end
    IKST_WorldPick.mouseHooked = true
end

function IKST_WorldPick.disarm(player)
    if not player then
        return
    end
    if IKST_WorldPick.activePlayer == player then
        IKST_WorldPick.activePlayer = nil
        IKST_WorldPick.batchScope = nil
    end
    local state = IKST.getPlayerState(player)
    if state then
        state.armed = false
        state.armedJob = nil
    end
    if IKST_PreviewOverlay then
        IKST_PreviewOverlay.clear()
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_WorldPick.armInspect(player, silent)
    if not player or not IKST_Access.canUseTools(player) then
        return
    end
    IKST_WorldPick.ensureMouseHook()
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(player)
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    state.armed = true
    state.armedJob = IKST.VIEW.inspector
    if IKST_HubNav and IKST_HubNav.syncArmedTab then
        IKST_HubNav.syncArmedTab(state, IKST.VIEW.inspector)
    else
        state.job = IKST.VIEW.inspector
    end
    IKST_WorldPick.activePlayer = player
    IKST_WorldPick.batchScope = nil
    if IKST_PreviewOverlay then
        IKST_PreviewOverlay.clear()
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
    if not silent then
        IKST.notify(player, IKST.text("IGUI_IKST_ClickWorld", "Click a world square"), true)
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_WorldPick.arm(player, action, scope, silent)
    if not player or not IKST_Access.canUseTools(player) then
        return
    end
    if IKST_LootWorldPick and IKST_LootWorldPick.disarm then
        IKST_LootWorldPick.disarm(player)
    end
    IKST_WorldPick.ensureMouseHook()
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(player)
    end
    local state = IKST.getPlayerState(player)
    local nextAction = action or IKST.getCleanupAction(state)
    local nextScope = scope or IKST.getCleanupScope(state)
    local same = state.armed
        and state.armedJob == IKST.VIEW.cleanup
        and state.cleanupAction == nextAction
        and state.cleanupScope == nextScope
    state.cleanupAction = nextAction
    state.cleanupScope = nextScope
    state.cleanupMode = state.cleanupAction
    state.armed = true
    state.armedJob = IKST.VIEW.cleanup
    if IKST_HubNav and IKST_HubNav.syncArmedTab then
        IKST_HubNav.syncArmedTab(state, IKST.VIEW.cleanup)
    else
        state.job = IKST.VIEW.cleanup
    end
    IKST_WorldPick.activePlayer = player
    IKST_WorldPick.batchScope = nil
    if IKST_PreviewOverlay then
        IKST_PreviewOverlay.clear()
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
    if not silent and not same then
        IKST.notify(player, IKST.text("IGUI_IKST_ClickWorld", "Click a world square"), true)
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_WorldPick.armBatch(player, scope, radius)
    local state = IKST.getPlayerState(player)
    if state and radius then
        state.cleanupRadius = radius
    end
    IKST_WorldPick.arm(player, IKST.getCleanupAction(state), scope)
end

function IKST_WorldPick.isArmed(player)
    local state = IKST.getPlayerState(player)
    return state and state.armed
end

IKST_ToolCursorManager = IKST_WorldPick

local function disarmAllPlayersOnLoad()
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then
                IKST_WorldPick.disarm(player)
            end
        end
        return
    end
    local player = getPlayer and getPlayer()
    if player then
        IKST_WorldPick.disarm(player)
    end
end

if Events and Events.OnPreMapLoad and Events.OnPreMapLoad.Add then
    Events.OnPreMapLoad.Add(disarmAllPlayersOnLoad)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_WorldPick.ensureMouseHook)
    Events.OnGameStart.Add(disarmAllPlayersOnLoad)
end
IKST_WorldPick.ensureMouseHook()
