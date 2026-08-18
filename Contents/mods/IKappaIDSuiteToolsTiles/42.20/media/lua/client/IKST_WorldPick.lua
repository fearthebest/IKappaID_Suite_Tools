-- Armed cleanup / inspect / command picks (single world-click stack for all jobs).
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
IKST_WorldPick.hoverSquare = nil
IKST_WorldPick.mouseHooked = false
IKST_WorldPick.renderHooked = false
IKST_WorldPick._pickCooldownUntil = 0
IKST_WorldPick._objectClickConsumed = false
IKST_WorldPick._pendingScreenClick = nil
IKST_WorldPick._hoverKey = ""
IKST_WorldPick._blockNotifyUntil = 0
IKST_WorldPick._lastMx = nil
IKST_WorldPick._lastMy = nil
IKST_WorldPick._lastPz = nil
IKST_WorldPick.PICK_COOLDOWN_MS = 350
IKST_WorldPick.BLOCK_NOTIFY_COOLDOWN_MS = 500

function IKST_WorldPick.nowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

function IKST_WorldPick.isPickCooldownActive()
    return IKST_WorldPick.nowMs() < (IKST_WorldPick._pickCooldownUntil or 0)
end

function IKST_WorldPick.isBlockNotifyCooldownActive()
    return IKST_WorldPick.nowMs() < (IKST_WorldPick._blockNotifyUntil or 0)
end

function IKST_WorldPick.setPickCooldown()
    IKST_WorldPick._pickCooldownUntil = IKST_WorldPick.nowMs() + IKST_WorldPick.PICK_COOLDOWN_MS
end

function IKST_WorldPick.clearHover()
    IKST_WorldPick.hoverSquare = nil
    IKST_WorldPick._hoverKey = ""
    IKST_WorldPick._lastMx = nil
    IKST_WorldPick._lastMy = nil
    IKST_WorldPick._lastPz = nil
    if IKST_PreviewOverlay and IKST_PreviewOverlay.invalidateHoverCache then
        IKST_PreviewOverlay.invalidateHoverCache()
    end
end

function IKST_WorldPick.syncHoverPreview()
    local hs = IKST_WorldPick.hoverSquare
    local key = ""
    if hs and type(hs.getX) == "function" and type(hs.getY) == "function" then
        local hz = ""
        if type(hs.getZ) == "function" then
            hz = tostring(hs:getZ())
        end
        key = tostring(hs:getX()) .. "," .. tostring(hs:getY()) .. "," .. hz
    end
    if key == IKST_WorldPick._hoverKey then
        return
    end
    IKST_WorldPick._hoverKey = key
    if IKST_Preview and IKST_Preview.syncForPanel and IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_Preview.syncForPanel(IKST_JobsPanel.instance)
    end
end

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
    local objects = type(square.getObjects) == "function" and square:getObjects()
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

function IKST_WorldPick.isCleanupArmed(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseTools(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    return state and state.armed and state.armedJob == IKST.VIEW.cleanup
end

function IKST_WorldPick.clearCommandPickState(state)
    if not state then
        return
    end
    state.worldPickCommand = nil
    state.worldPickExtra = nil
    state.worldPickOnClick = nil
    state.worldPickAfter = nil
end

function IKST_WorldPick.isCommandPickArmed(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state or state.armed ~= true then
        return false
    end
    if state.armedJob == IKST.VIEW.loot then
        if IKST_Access.canUseLoot and not IKST_Access.canUseLoot(player) then
            return false
        end
    elseif not IKST_Access.canUseTools(player) then
        return false
    end
    return state.worldPickCommand ~= nil
        or (state.worldPickOnClick and type(state.worldPickOnClick) == "function")
end

function IKST_WorldPick.isWorldArmed(player)
    return IKST_WorldPick.isCleanupArmed(player)
        or IKST_WorldPick.isInspectorArmed(player)
        or IKST_WorldPick.isCommandPickArmed(player)
end

function IKST_WorldPick.isArmed(player)
    local state = IKST.getPlayerState(player)
    return state and state.armed
end

-- Same check as vanilla ISBuildingObject: UI under cursor vs world.
function IKST_WorldPick.isMouseOverUI()
    if not UIManager or type(UIManager.getUI) ~= "function" then
        return false
    end
    local uis = UIManager.getUI()
    if not uis or type(uis.size) ~= "function" or type(uis.get) ~= "function" then
        return false
    end
    for i = 1, uis:size() do
        local ui = uis:get(i - 1)
        if ui and type(ui.isMouseOver) == "function" and ui:isMouseOver() then
            return true
        end
    end
    return false
end

function IKST_WorldPick.isMouseOverPanel()
    return IKST_WorldPick.isMouseOverUI()
end

function IKST_WorldPick.clickBlockReason(player)
    if not IKST_WorldPick.isWorldArmed(player) then
        return "not_armed"
    end
    if IKST_WorldPick.isMouseOverUI() then
        return "over_ui"
    end
    if IKST_WorldPick.isPickCooldownActive() then
        return "cooldown"
    end
    return nil
end

function IKST_WorldPick.notifyClickBlock(player, reason)
    if not player or not reason or IKST_WorldPick.isBlockNotifyCooldownActive() then
        return
    end
    -- Over UI: silent so panel / inventory clicks keep working.
    if reason == "over_ui" then
        return
    end
    IKST_WorldPick._blockNotifyUntil = IKST_WorldPick.nowMs() + IKST_WorldPick.BLOCK_NOTIFY_COOLDOWN_MS
    if reason == "not_armed" then
        IKST.notify(player, IKST.text("IGUI_IKST_WorldPick_NotArmed", "Arm a world tool first"), false)
    elseif reason == "cooldown" then
        IKST.notify(player, IKST.text("IGUI_IKST_Loot_Cooldown", "Wait a moment before clicking again"), false)
    end
end

function IKST_WorldPick.applyInspect(player, square)
    if not player or not square or not IKST_WorldPick.isInspectorArmed(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    IKST.dispatchCommand(player, IKST.CMD.inspectSquare, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        audit = state and state.inspectAudit == true,
    })
    return true
end

function IKST_WorldPick.applySquare(player, square, clickedObj)
    if not player or not square or not IKST_WorldPick.isCleanupArmed(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    return IKST_WorldPick.dispatchCleanup(player, square, state, clickedObj)
end

function IKST_WorldPick.getMouseScreenXY()
    if IKST_Grid and IKST_Grid.getMouseScreenXY then
        return IKST_Grid.getMouseScreenXY()
    end
    if type(getMouseX) == "function" and type(getMouseY) == "function" then
        return getMouseX(), getMouseY()
    end
    return nil, nil
end

function IKST_WorldPick.resolveClickSquare(player, screenX, screenY)
    local square = nil
    if screenX ~= nil and screenY ~= nil then
        square = IKST_Grid.squareFromScreen(screenX, screenY, player)
    end
    if not square then
        square = IKST_WorldPick.hoverSquare
    end
    return square
end

function IKST_WorldPick.resolveObjectClickSquare(obj, player, screenX, screenY)
    local square = IKST_Grid.squareFromObject(obj)
    if not square and obj and type(obj.getX) == "function" and type(obj.getY) == "function" and type(obj.getZ) == "function" then
        square = IKST_Grid.getSquare(math.floor(obj:getX()), math.floor(obj:getY()), math.floor(obj:getZ()))
    end
    if not square and IKST_Grid.isRoofObject and IKST_Grid.isRoofObject(obj)
        and type(obj.getX) == "function" and type(obj.getY) == "function" and type(obj.getZ) == "function" then
        square = IKST_Grid.getSquare(math.floor(obj:getX()), math.floor(obj:getY()), math.floor(obj:getZ()))
    end
    if not square then
        square = IKST_WorldPick.hoverSquare
    end
    if not square and screenX ~= nil and screenY ~= nil then
        square = IKST_Grid.squareFromScreen(screenX, screenY, player)
    end
    return square
end

function IKST_WorldPick.applyCommandPick(player, square)
    if not player or not square then
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    local args = {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    }
    if state.worldPickExtra then
        for k, v in pairs(state.worldPickExtra) do
            args[k] = v
        end
    end
    if state.worldPickOnClick and type(state.worldPickOnClick) == "function" then
        state.worldPickOnClick(player, square, args)
    elseif state.worldPickCommand then
        IKST.dispatchCommand(player, state.worldPickCommand, args)
    else
        return false
    end
    if state.worldPickAfter and type(state.worldPickAfter) == "function" then
        state.worldPickAfter(player, square, args)
    end
    return true
end

function IKST_WorldPick.tryPickSquare(player, square, clickedObj)
    if not square then
        return false
    end
    if IKST_WorldPick.isInspectorArmed(player) then
        return IKST_WorldPick.applyInspect(player, square)
    end
    if IKST_WorldPick.isCommandPickArmed(player) then
        return IKST_WorldPick.applyCommandPick(player, square)
    end
    return IKST_WorldPick.applySquare(player, square, clickedObj)
end

function IKST_WorldPick.attemptWorldClick(screenX, screenY)
    local player = IKST_WorldPick.activePlayer
    local block = IKST_WorldPick.clickBlockReason(player)
    if block then
        IKST_WorldPick.notifyClickBlock(player, block)
        return false
    end

    local square = IKST_WorldPick.resolveClickSquare(player, screenX, screenY)
    if not square then
        IKST.notify(player, IKST.text("IGUI_IKST_NoSquare", "No square under cursor"), false)
        return false
    end

    IKST_WorldPick.setPickCooldown()
    return IKST_WorldPick.tryPickSquare(player, square, nil)
end

function IKST_WorldPick.onMouseDown(x, y)
    if IKST_WorldPick._objectClickConsumed then
        return
    end
    if not IKST_WorldPick.isWorldArmed(IKST_WorldPick.activePlayer) then
        return
    end
    if IKST_WorldPick.isMouseOverUI() then
        return
    end
    IKST_WorldPick._pendingScreenClick = { x = x, y = y }
end

function IKST_WorldPick.onObjectLeftMouseDown(obj, x, y)
    local player = IKST_WorldPick.activePlayer
    if not IKST_WorldPick.isWorldArmed(player) then
        return
    end
    IKST_WorldPick._objectClickConsumed = true
    IKST_WorldPick._pendingScreenClick = nil
    local block = IKST_WorldPick.clickBlockReason(player)
    if block then
        IKST_WorldPick.notifyClickBlock(player, block)
        return
    end

    local square = IKST_WorldPick.resolveObjectClickSquare(obj, player, x, y)
    if not square then
        IKST.notify(player, IKST.text("IGUI_IKST_NoSquare", "No square under cursor"), false)
        return
    end
    IKST_WorldPick.setPickCooldown()
    IKST_WorldPick.tryPickSquare(player, square, obj)
end

function IKST_WorldPick.updateHoverSquare(player)
    if IKST_WorldPick.isMouseOverUI() then
        IKST_WorldPick.clearHover()
        return
    end
    local mx, my = IKST_WorldPick.getMouseScreenXY()
    local pz = 0
    if player and type(player.getZ) == "function" then
        pz = math.floor(player:getZ() or 0)
    end
    if mx ~= nil and my ~= nil
        and mx == IKST_WorldPick._lastMx
        and my == IKST_WorldPick._lastMy
        and pz == IKST_WorldPick._lastPz then
        return
    end
    IKST_WorldPick._lastMx = mx
    IKST_WorldPick._lastMy = my
    IKST_WorldPick._lastPz = pz
    if mx ~= nil and my ~= nil then
        IKST_WorldPick.hoverSquare = IKST_Grid.squareFromScreen(mx, my, player)
    else
        IKST_WorldPick.hoverSquare = nil
    end
    IKST_WorldPick.syncHoverPreview()
end

function IKST_WorldPick.onRenderTick()
    local player = IKST.resolvePlayer(IKST_WorldPick.activePlayer or getPlayer())
    if not IKST_WorldPick.isWorldArmed(player) then
        IKST_WorldPick._pendingScreenClick = nil
        IKST_WorldPick._objectClickConsumed = false
        if IKST_WorldPick.hoverSquare or IKST_WorldPick._hoverKey ~= "" then
            IKST_WorldPick.clearHover()
        end
        return
    end
    IKST_WorldPick.updateHoverSquare(player)

    local pending = IKST_WorldPick._pendingScreenClick
    if pending and not IKST_WorldPick._objectClickConsumed then
        IKST_WorldPick._pendingScreenClick = nil
        IKST_WorldPick.attemptWorldClick(pending.x, pending.y)
    else
        IKST_WorldPick._pendingScreenClick = nil
    end
    IKST_WorldPick._objectClickConsumed = false
end

function IKST_WorldPick.ensureRenderHook()
    if IKST_WorldPick.renderHooked then
        return
    end
    if Events and Events.OnRenderTick and Events.OnRenderTick.Add then
        Events.OnRenderTick.Add(IKST_WorldPick.onRenderTick)
        IKST_WorldPick.renderHooked = true
    end
end

function IKST_WorldPick.releaseRenderHook()
    if not IKST_WorldPick.renderHooked then
        return
    end
    if Events and Events.OnRenderTick and Events.OnRenderTick.Remove then
        Events.OnRenderTick.Remove(IKST_WorldPick.onRenderTick)
    end
    IKST_WorldPick.renderHooked = false
end

function IKST_WorldPick.ensureMouseHook()
    if IKST_WorldPick.mouseHooked then
        return
    end
    if Events and Events.OnMouseDown and Events.OnMouseDown.Add then
        Events.OnMouseDown.Add(IKST_WorldPick.onMouseDown)
    end
    if Events and Events.OnObjectLeftMouseButtonDown and Events.OnObjectLeftMouseButtonDown.Add then
        Events.OnObjectLeftMouseButtonDown.Add(IKST_WorldPick.onObjectLeftMouseDown)
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
        if state.armedJob == IKST.VIEW.cleanup or state.armedJob == IKST.VIEW.inspector
            or state.armedJob == IKST.VIEW.guard or state.armedJob == IKST.VIEW.tiles
            or state.armedJob == IKST.VIEW.economy
            or state.armedJob == IKST.VIEW.loot then
            state.armed = false
            state.armedJob = nil
        end
        IKST_WorldPick.clearCommandPickState(state)
    end
    if not IKST_WorldPick.activePlayer then
        IKST_WorldPick.releaseRenderHook()
        IKST_WorldPick._pendingScreenClick = nil
        IKST_WorldPick._objectClickConsumed = false
        IKST_WorldPick.clearHover()
    end
    if IKST_PreviewOverlay then
        IKST_PreviewOverlay.clear()
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_WorldPick.armInspect(player, silent, audit)
    if not player or not IKST_Access.canUseTools(player) then
        return
    end
    IKST_WorldPick.ensureMouseHook()
    IKST_WorldPick.ensureRenderHook()
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(player)
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    state.armed = true
    state.armedJob = IKST.VIEW.inspector
    state.inspectAudit = audit == true
    IKST_WorldPick.clearCommandPickState(state)
    if IKST_HubNav and IKST_HubNav.syncArmedTab then
        IKST_HubNav.syncArmedTab(state, IKST.VIEW.inspector)
    else
        state.job = IKST.VIEW.inspector
    end
    IKST_WorldPick.activePlayer = player
    IKST_WorldPick.batchScope = nil
    IKST_WorldPick.clearHover()
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

-- Single-square staff actions (protect, readonly, economy kit, …): click cursor square, not player feet.
function IKST_WorldPick.armCommand(player, viewJob, command, extra, opts)
    opts = opts or {}
    if not player then
        return
    end
    if viewJob == IKST.VIEW.loot then
        if IKST_Access.canUseLoot and not IKST_Access.canUseLoot(player) then
            if not opts.silent then
                IKST.notify(player, IKST.text("IGUI_IKST_Loot_NoAccess", "Loot repopulate is not available"), false)
            end
            return
        end
    elseif not IKST_Access.canUseTools(player) then
        return
    end
    if not command and (not opts.onClick or type(opts.onClick) ~= "function") then
        return
    end
    IKST_WorldPick.ensureMouseHook()
    IKST_WorldPick.ensureRenderHook()
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(player)
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    state.armed = true
    state.armedJob = viewJob or IKST.VIEW.guard
    state.worldPickCommand = command
    state.worldPickExtra = extra
    state.worldPickOnClick = opts.onClick
    state.worldPickAfter = opts.after
    if IKST_HubNav and IKST_HubNav.syncArmedTab and viewJob then
        IKST_HubNav.syncArmedTab(state, viewJob)
    end
    IKST_WorldPick.activePlayer = player
    IKST_WorldPick.batchScope = nil
    IKST_WorldPick.clearHover()
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
    if IKST_Preview and IKST_Preview.syncForPanel and IKST_JobsPanel.instance then
        IKST_Preview.syncForPanel(IKST_JobsPanel.instance)
    end
    if not opts.silent then
        local notifyKey = opts.notifyKey or "IGUI_IKST_ClickWorld"
        IKST.notify(player, IKST.text(notifyKey, "Click a world square"), true)
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_WorldPick.arm(player, action, scope, silent)
    if not player or not IKST_Access.canUseTools(player) then
        return
    end
    IKST_WorldPick.ensureMouseHook()
    IKST_WorldPick.ensureRenderHook()
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(player)
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    IKST_WorldPick.clearCommandPickState(state)
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
    IKST_WorldPick.clearHover()
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
    if IKST_Preview and IKST_Preview.syncForPanel and IKST_JobsPanel.instance then
        IKST_Preview.syncForPanel(IKST_JobsPanel.instance)
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
