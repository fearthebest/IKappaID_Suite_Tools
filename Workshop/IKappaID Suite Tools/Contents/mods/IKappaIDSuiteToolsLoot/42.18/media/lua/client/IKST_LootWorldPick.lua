if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Grid"
require "IKST_Loot"
require "IKST_LootOps"

IKST_LootWorldPick = IKST_LootWorldPick or {}
IKST_LootWorldPick.activePlayer = nil
IKST_LootWorldPick.mouseHooked = false
IKST_LootWorldPick._pickCooldown = 0
IKST_LootWorldPick._mouseWasDown = false
IKST_LootWorldPick._deferScreenPick = 0
IKST_LootWorldPick._objectClickConsumed = false

function IKST_LootWorldPick.isArmed(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseLoot(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    return state and state.armed and state.armedJob == IKST.VIEW.loot
end

function IKST_LootWorldPick.isMouseOverPanel()
    local panel = IKST_JobsPanel and IKST_JobsPanel.instance
    if not panel or not panel.getIsVisible or not panel:getIsVisible() then
        return false
    end
    if not getMouseX or not getMouseY then
        return false
    end
    local mx = getMouseX()
    local my = getMouseY()
    return mx >= panel:getX() and mx <= panel:getX() + panel.width
        and my >= panel:getY() and my <= panel:getY() + panel.height
end

function IKST_LootWorldPick.dispatchZone(player, square, state)
    if not player or not square or not state then
        return false
    end
    IKST.dispatchCommand(player, IKST.CMD.lootRepopulateZone, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        scope = IKST.getLootScope(state),
        radius = state.cleanupRadius,
    })
    return true
end

function IKST_LootWorldPick.applySquare(player, square)
    if not IKST_LootWorldPick.isArmed(player) or not square then
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    return IKST_LootWorldPick.dispatchZone(player, square, state)
end

function IKST_LootWorldPick.getMouseScreenXY()
    if getMouseXScaled and getMouseYScaled then
        return getMouseXScaled(), getMouseYScaled()
    end
    if getMouseX and getMouseY then
        return getMouseX(), getMouseY()
    end
    return nil, nil
end

function IKST_LootWorldPick.tryPickSquare(player, square, screenX, screenY, fromObject)
    if not fromObject and IKST_LootWorldPick._pickCooldown > 0 then
        return false
    end
    if not square and screenX ~= nil and screenY ~= nil then
        square = IKST_Grid.squareFromScreen(screenX, screenY, player)
    end
    if not square then
        return false
    end
    IKST_LootWorldPick._pickCooldown = 2
    if IKST_LootWorldPick.applySquare(player, square) then
        return true
    end
    IKST_LootWorldPick._pickCooldown = 0
    return false
end

function IKST_LootWorldPick.handleWorldClick(screenX, screenY)
    local player = IKST_LootWorldPick.activePlayer
    if not IKST_LootWorldPick.isArmed(player) then
        return false
    end
    if IKST_LootWorldPick.isMouseOverPanel() then
        return false
    end
    if IKST_LootWorldPick.tryPickSquare(player, nil, screenX, screenY) then
        return true
    end
    IKST.notify(player, IKST.text("IGUI_IKST_NoSquare", "No square under cursor"), false)
    return false
end

function IKST_LootWorldPick.onMouseDown(x, y)
    IKST_LootWorldPick.handleWorldClick(x, y)
end

function IKST_LootWorldPick.onObjectLeftMouseDown(obj, x, y)
    local player = IKST_LootWorldPick.activePlayer
    if not IKST_LootWorldPick.isArmed(player) or IKST_LootWorldPick.isMouseOverPanel() then
        return
    end
    IKST_LootWorldPick._objectClickConsumed = true
    IKST_LootWorldPick._deferScreenPick = 0
    local square = IKST_Grid.squareFromObject(obj)
    if not square and obj.getX and obj.getY and obj.getZ then
        square = IKST_Grid.getSquare(math.floor(obj:getX()), math.floor(obj:getY()), math.floor(obj:getZ()))
    end
    IKST_LootWorldPick.tryPickSquare(player, square, nil, nil, true)
end

function IKST_LootWorldPick.onTick()
    if IKST_LootWorldPick._pickCooldown > 0 then
        IKST_LootWorldPick._pickCooldown = IKST_LootWorldPick._pickCooldown - 1
    end

    local player = IKST.resolvePlayer(IKST_LootWorldPick.activePlayer or getPlayer())
    if not IKST_LootWorldPick.isArmed(player) then
        IKST_LootWorldPick._mouseWasDown = false
        IKST_LootWorldPick._deferScreenPick = 0
        IKST_LootWorldPick._objectClickConsumed = false
        return
    end

    if IKST_LootWorldPick._deferScreenPick > 0 then
        IKST_LootWorldPick._deferScreenPick = IKST_LootWorldPick._deferScreenPick - 1
        if IKST_LootWorldPick._deferScreenPick == 0 and not IKST_LootWorldPick._objectClickConsumed then
            local mx, my = IKST_LootWorldPick.getMouseScreenXY()
            if mx ~= nil and my ~= nil then
                IKST_LootWorldPick.handleWorldClick(mx, my)
            end
        end
        IKST_LootWorldPick._objectClickConsumed = false
    end

    if IKST.isRemoteClient() then
        return
    end

    local down = isMouseButtonDown and isMouseButtonDown(0)
    if down and not IKST_LootWorldPick._mouseWasDown then
        IKST_LootWorldPick._objectClickConsumed = false
        IKST_LootWorldPick._deferScreenPick = 1
    end
    if not down then
        IKST_LootWorldPick._deferScreenPick = 0
        IKST_LootWorldPick._objectClickConsumed = false
    end
    IKST_LootWorldPick._mouseWasDown = down == true
end

function IKST_LootWorldPick.ensureMouseHook()
    if IKST_LootWorldPick.mouseHooked then
        return
    end
    if IKST.isRemoteClient() then
        if Events and Events.OnMouseDown and Events.OnMouseDown.Add then
            Events.OnMouseDown.Add(IKST_LootWorldPick.onMouseDown)
        end
    end
    if Events and Events.OnObjectLeftMouseButtonDown and Events.OnObjectLeftMouseButtonDown.Add then
        Events.OnObjectLeftMouseButtonDown.Add(IKST_LootWorldPick.onObjectLeftMouseDown)
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(IKST_LootWorldPick.onTick)
    end
    IKST_LootWorldPick.mouseHooked = true
end

function IKST_LootWorldPick.disarm(player)
    if not player then
        return
    end
    if IKST_LootWorldPick.activePlayer == player then
        IKST_LootWorldPick.activePlayer = nil
    end
    local state = IKST.getPlayerState(player)
    if state and state.armedJob == IKST.VIEW.loot then
        state.armed = false
        state.armedJob = nil
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_LootWorldPick.arm(player, scope, silent)
    if not player or not IKST_Access.canUseLoot(player) then
        return
    end
    if IKST_WorldPick and IKST_WorldPick.disarm then
        IKST_WorldPick.disarm(player)
    end
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(player)
    end
    IKST_LootWorldPick.ensureMouseHook()
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    if scope then
        state.lootScope = scope
    end
    state.armed = true
    state.armedJob = IKST.VIEW.loot
    if IKST_HubNav and IKST_HubNav.syncArmedTab then
        IKST_HubNav.syncArmedTab(state, IKST.VIEW.loot)
    end
    IKST_LootWorldPick.activePlayer = player
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
    if not silent then
        IKST.notify(player, IKST.text("IGUI_IKST_ClickWorld", "Click a square on the ground"), true)
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_LootWorldPick.ensureMouseHook)
end
IKST_LootWorldPick.ensureMouseHook()
