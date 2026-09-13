-- House claim request zone: same paint as walk A→B.
-- Walk and staff preview keep the zone solid by refreshing
-- addAreaHighlightForPlayer in a HUD prerender (not OnTick).
-- Deny/cancel reverse that paint (same rect, alpha 0) then stop.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "IKST_Shared"
require "IKST_Claim"
require "IKappaID_UI/IKUI_Chrome"
require "IKappaID_UI/IKUI_Config"

IKST_ClaimRequestDraw = IKST_ClaimRequestDraw or {}

local FILL_R, FILL_G, FILL_B, FILL_A = 0.20, 0.75, 0.95, 0.28
local BAD_R, BAD_G, BAD_B, BAD_A = 0.95, 0.35, 0.25, 0.32
local STAFF_R, STAFF_G, STAFF_B, STAFF_A = 0.95, 0.55, 0.15, 0.35

local function playerNum(player)
    if not player or type(player.getPlayerNum) ~= "function" then
        return 0
    end
    return player:getPlayerNum() or 0
end

local function playerZ(player)
    if player and type(player.getCurrentSquare) == "function" then
        local sq = player:getCurrentSquare()
        if sq and type(sq.getZ) == "function" then
            return math.floor(sq:getZ() or 0)
        end
    end
    if player and type(player.getZ) == "function" then
        return math.floor(player:getZ() or 0)
    end
    return 0
end

local function playerCorner(player)
    if not player then
        return nil
    end
    local x, y = 0, 0
    if type(player.getX) == "function" then
        x = math.floor(player:getX() or 0)
    end
    if type(player.getY) == "function" then
        y = math.floor(player:getY() or 0)
    end
    return { x = x, y = y, z = playerZ(player) }
end

local function clearPreviewOverlay()
    if IKST_PreviewOverlay and type(IKST_PreviewOverlay.clearJob) == "function" then
        IKST_PreviewOverlay.clearJob()
    end
end

local function setWorldMenuBlocked(blocked)
    if not ISWorldObjectContextMenu then
        return
    end
    ISWorldObjectContextMenu.disableWorldMenu = blocked == true
end

local function clickIsOnOtherUI(panel)
    if not UIManager or type(UIManager.getUI) ~= "function" then
        return false
    end
    local uis = UIManager.getUI()
    if not uis or type(uis.size) ~= "function" then
        return false
    end
    local n = uis:size()
    for i = 0, n - 1 do
        local ui = uis:get(i)
        if ui and ui ~= panel and type(ui.isMouseOver) == "function" and ui:isMouseOver() then
            return true
        end
    end
    return false
end

local function worldSquareAtScreen(player, screenX, screenY)
    if not player then
        return nil
    end
    local pn = playerNum(player)
    local z = playerZ(player)
    if type(screenToIsoX) ~= "function" or type(screenToIsoY) ~= "function" then
        return nil
    end
    local worldX = math.floor(screenToIsoX(pn, screenX, screenY, z))
    local worldY = math.floor(screenToIsoY(pn, screenX, screenY, z))
    local square = nil
    if getCell and type(getCell) == "function" then
        local cell = getCell()
        if cell and type(cell.getGridSquare) == "function" then
            square = cell:getGridSquare(worldX, worldY, z)
        end
    end
    return {
        square = square,
        x = worldX,
        y = worldY,
        z = z,
    }
end

local function writeDrawState(state, a, b)
    if not state or not a or not b then
        return nil
    end
    local x, y, w, h = IKST_Claim.rectFromCorners(a.x, a.y, b.x, b.y)
    local sameFloor = (a.z or 0) == (b.z or 0)
    local reason = nil
    if not sameFloor then
        reason = "floor"
    elseif w < IKST_Claim.MIN_DIM or h < IKST_Claim.MIN_DIM then
        reason = "too_small"
    elseif w > IKST_Claim.MAX_DIM or h > IKST_Claim.MAX_DIM then
        reason = "too_large"
    end
    local draw = {
        w = w,
        h = h,
        ok = reason == nil,
        reason = reason,
        x = x,
        y = y,
        z = a.z or b.z,
    }
    state.claimReqDraw = draw
    return draw
end

-- Same call walk uses to grow the zone; alpha 0 replaces that last paint.
local function paintArea(player, x, y, w, h, z, r, g, b, a)
    if type(addAreaHighlightForPlayer) ~= "function" then
        return
    end
    addAreaHighlightForPlayer(
        playerNum(player),
        math.floor(tonumber(x) or 0),
        math.floor(tonumber(y) or 0),
        math.floor(tonumber(x) or 0) + math.max(0, math.floor(tonumber(w) or 0)),
        math.floor(tonumber(y) or 0) + math.max(0, math.floor(tonumber(h) or 0)),
        math.floor(tonumber(z) or 0),
        r, g, b, a
    )
end

local function rememberPaint(x, y, w, h, z)
    IKST_ClaimRequestDraw._lastPaint = {
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
        w = math.max(0, math.floor(tonumber(w) or 0)),
        h = math.max(0, math.floor(tonumber(h) or 0)),
        z = math.floor(tonumber(z) or 0),
    }
end

local function rectFromState(state)
    if state and state.claimReqDraw and state.claimReqDraw.x ~= nil and state.claimReqDraw.y ~= nil then
        return {
            x = state.claimReqDraw.x,
            y = state.claimReqDraw.y,
            w = state.claimReqDraw.w or 0,
            h = state.claimReqDraw.h or 0,
            z = state.claimReqDraw.z or 0,
        }
    end
    return IKST_ClaimRequestDraw._lastPaint
end

-- Walk grows A→B. Refuse collapses that same rect back to nothing.
local function reverseWalkHighlight(player, rect)
    if not rect then
        return
    end
    paintArea(player, rect.x, rect.y, rect.w, rect.h, rect.z, 0, 0, 0, 0)
    paintArea(player, rect.x, rect.y, 0, 0, rect.z, 0, 0, 0, 0)
end

local function dropDraftSelection()
    if not IKST_Hub or type(IKST_Hub.activeJobPanel) ~= "function" then
        return
    end
    local panel = IKST_Hub.activeJobPanel()
    if not panel then
        return
    end
    local sel = panel.guardSelectedSH
    if sel and (sel.draft == true or sel.pending == true) then
        panel.guardSelectedSH = nil
    end
    return panel
end

function IKST_ClaimRequestDraw.isActive(player)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    return state ~= nil and (state.claimReqSelecting == true or state.claimReqA ~= nil)
end

function IKST_ClaimRequestDraw.clear(player)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    local last = rectFromState(state)
    if state then
        state.claimReqA = nil
        state.claimReqB = nil
        state.claimReqDraw = nil
        state.claimReqSelecting = nil
        state.claimReqMode = nil
    end
    setWorldMenuBlocked(false)
    IKST_ClaimRequestDraw._onReady = nil
    IKST_ClaimRequestDraw._waitingConfirm = false
    if IKST_ClaimRequestDraw._hud and (not player or IKST_ClaimRequestDraw._hud.player == player) then
        IKST_ClaimRequestDraw._hud:removeFromUIManager()
        IKST_ClaimRequestDraw._hud = nil
    end
    reverseWalkHighlight(player, last)
    IKST_ClaimRequestDraw._lastPaint = nil
    dropDraftSelection()
    clearPreviewOverlay()
end

function IKST_ClaimRequestDraw.isWalkMode(player)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    return state ~= nil and state.claimReqMode == "walk"
end

function IKST_ClaimRequestDraw.start(player, opts)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    if not state then
        return
    end
    opts = opts or {}
    local want = "drag"
    if opts.mode == "walk" then
        want = "walk"
    end
    if type(opts.onReady) == "function" then
        IKST_ClaimRequestDraw._onReady = opts.onReady
    end
    -- Never run walk and drag at once. Switching methods resets corners.
    clearPreviewOverlay()
    if state.claimReqSelecting and state.claimReqMode == want then
        IKST_ClaimRequestDraw.ensureHud(player)
        return
    end
    if state.claimReqSelecting and state.claimReqMode ~= want then
        state.claimReqA = nil
        state.claimReqB = nil
        state.claimReqDraw = { w = 0, h = 0, ok = false }
        IKST_ClaimRequestDraw._waitingConfirm = false
        setWorldMenuBlocked(false)
    end
    state.claimReqSelecting = true
    state.claimReqMode = want
    if want == "walk" then
        local corner = playerCorner(player)
        if corner then
            state.claimReqA = corner
            state.claimReqB = { x = corner.x, y = corner.y, z = corner.z }
            writeDrawState(state, state.claimReqA, state.claimReqB)
        else
            state.claimReqA = nil
            state.claimReqB = nil
            state.claimReqDraw = { w = 0, h = 0, ok = false }
        end
    else
        state.claimReqA = nil
        state.claimReqB = nil
        state.claimReqDraw = { w = 0, h = 0, ok = false }
    end
    IKST_ClaimRequestDraw._waitingConfirm = false
    IKST_ClaimRequestDraw.ensureHud(player)
end

local StaffPrevHud = ISPanelJoypad:derive("IKST_ClaimStaffPrevHud")

function StaffPrevHud:new(player)
    local o = ISPanelJoypad.new(self, 0, 0, 1, 1)
    o.player = player
    o.background = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

function StaffPrevHud:prerender()
    IKST_ClaimRequestDraw.paintStaffPreview(self.player)
end

local function ensureStaffHud(player)
    local hud = IKST_ClaimRequestDraw._staffHud
    if hud and hud.player == player then
        return
    end
    if hud then
        hud:removeFromUIManager()
        IKST_ClaimRequestDraw._staffHud = nil
    end
    if not player then
        return
    end
    hud = StaffPrevHud:new(player)
    hud:initialise()
    hud:instantiate()
    hud:addToUIManager()
    IKST_ClaimRequestDraw._staffHud = hud
end

function IKST_ClaimRequestDraw.clearStaffPreview()
    local preview = IKST_ClaimRequestDraw._staffPreview
    local hud = IKST_ClaimRequestDraw._staffHud
    local player = hud and hud.player
    IKST_ClaimRequestDraw._staffPreview = nil
    if hud then
        hud:removeFromUIManager()
        IKST_ClaimRequestDraw._staffHud = nil
    end
    if not player and type(getPlayer) == "function" then
        player = getPlayer()
    end
    reverseWalkHighlight(player, preview)
end

function IKST_ClaimRequestDraw.setStaffPreview(rect, player)
    if type(rect) ~= "table" or rect.x == nil or rect.y == nil then
        IKST_ClaimRequestDraw.clearStaffPreview()
        return
    end
    local w = math.max(1, math.floor(tonumber(rect.w) or 1))
    local h = math.max(1, math.floor(tonumber(rect.h) or 1))
    IKST_ClaimRequestDraw._staffPreview = {
        x = math.floor(tonumber(rect.x) or 0),
        y = math.floor(tonumber(rect.y) or 0),
        z = math.floor(tonumber(rect.z) or 0),
        w = w,
        h = h,
    }
    if not player and type(getPlayer) == "function" then
        player = getPlayer()
    end
    ensureStaffHud(player)
end

function IKST_ClaimRequestDraw.paintStaffPreview(player)
    local preview = IKST_ClaimRequestDraw._staffPreview
    if not preview or not player then
        return
    end
    paintArea(player, preview.x, preview.y, preview.w, preview.h, preview.z, STAFF_R, STAFF_G, STAFF_B, STAFF_A)
end

local ClaimReqHud = ISPanelJoypad:derive("IKST_ClaimReqHud")

function ClaimReqHud:new(player)
    local core = getCore and getCore() or nil
    local sw = core and core:getScreenWidth() or 800
    local sh = core and core:getScreenHeight() or 600
    local pad = 16
    if IKUI_Config and type(IKUI_Config.s) == "function" then
        pad = IKUI_Config.s(16)
    end
    local fontH = 14
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.getFontHeight) == "function" then
            fontH = tm:getFontHeight(UIFont.Small) or fontH
        end
    end
    local btnH = math.max(28, fontH + 10)
    local width = 380
    local height = pad + fontH + 6 + fontH + 8 + fontH + pad + btnH + pad
    local x = math.floor((sw - width) / 2)
    local y = math.max(8, sh - height - 96)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = playerNum(player)
    o.background = false
    o.moveWithMouse = true
    o._pad = pad
    o._btnH = btnH
    o._fontH = fontH
    o._dragging = false
    if IKUI_Chrome and type(IKUI_Chrome.applyPanelColors) == "function" then
        IKUI_Chrome.applyPanelColors(o)
    else
        o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    end
    return o
end

function ClaimReqHud:initialise()
    ISPanelJoypad.initialise(self)
    local pad = self._pad or 16
    local btnH = self._btnH or 28
    local btnW = 128
    local send = ISButton:new(
        pad,
        self.height - pad - btnH,
        btnW,
        btnH,
        IKST.text("IGUI_IKST_ClaimTile_MarkEnd", "Send to staff"),
        self,
        ClaimReqHud.onSend
    )
    send.internal = "SEND"
    send.anchorTop = false
    send.anchorBottom = true
    send:initialise()
    send:instantiate()
    if IKUI_Chrome and type(IKUI_Chrome.stylePrimaryButton) == "function" then
        IKUI_Chrome.stylePrimaryButton(send)
    end
    send.enable = false
    self:addChild(send)
    self.send = send
    local cancel = ISButton:new(
        self.width - pad - btnW,
        self.height - pad - btnH,
        btnW,
        btnH,
        IKST.text("IGUI_IKST_Cancel", "Cancel"),
        self,
        ClaimReqHud.onCancel
    )
    cancel.internal = "CANCEL"
    cancel.anchorTop = false
    cancel.anchorBottom = true
    cancel.anchorLeft = false
    cancel.anchorRight = true
    cancel:initialise()
    cancel:instantiate()
    if IKUI_Chrome and type(IKUI_Chrome.styleDangerButton) == "function" then
        IKUI_Chrome.styleDangerButton(cancel)
    elseif type(cancel.enableCancelColor) == "function" then
        cancel:enableCancelColor()
    end
    self:addChild(cancel)
    self.cancel = cancel
end

function ClaimReqHud:onCancel()
    IKST_ClaimRequestDraw.clear(self.player)
    local p = self.player
    if p then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_Cancelled", "Claim request cancelled."), true)
    end
end

function ClaimReqHud:onSend()
    self:submitIfReady()
end

function IKST_ClaimRequestDraw.releaseConfirmLock()
    IKST_ClaimRequestDraw._waitingConfirm = false
    local hud = IKST_ClaimRequestDraw._hud
    if hud and hud.send then
        hud.send.enable = true
    end
end

function ClaimReqHud:hudText()
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    local draw = state and state.claimReqDraw
    local walk = state and state.claimReqMode == "walk"
    if not state or not state.claimReqA then
        if walk then
            return IKST.text("IGUI_IKST_ClaimReq_WalkToB",
                "Walk to the opposite corner. The zone is from where you started to where you stand.")
        end
        return IKST.text("IGUI_IKST_ClaimReq_DragHint",
            "Drag on the world to mark the zone. Running will not move it.")
    end
    if draw and draw.ok then
        local readyHint = IKST.text("IGUI_IKST_ClaimReq_PressB", "Send to staff when ready")
        if not walk then
            readyHint = IKST.text("IGUI_IKST_ClaimReq_ReleaseToSend", "Release to send to staff")
        end
        return IKST.text("IGUI_IKST_ClaimReq_Drawing", "Drawing claim zone")
            .. ": " .. tostring(draw.w) .. "x" .. tostring(draw.h)
            .. " - " .. readyHint
    end
    if draw and draw.reason == "too_large" then
        local smaller = IKST.text("IGUI_IKST_ClaimReq_WalkCloser", "walk a smaller area")
        if not walk then
            smaller = IKST.text("IGUI_IKST_ClaimReq_DragSmaller", "drag a smaller area")
        end
        return IKST.text("IGUI_IKST_ClaimReq_TooLarge", "Too large (max")
            .. " " .. tostring(IKST_Claim.MAX_DIM) .. " "
            .. IKST.text("IGUI_IKST_ClaimReq_PerSide", "per side")
            .. "). "
            .. IKST.text("IGUI_IKST_ClaimReq_NowSize", "Now")
            .. " " .. tostring(draw.w or "?") .. "x" .. tostring(draw.h or "?")
            .. " - " .. smaller
    end
    if draw and draw.reason == "too_small" then
        local larger = IKST.text("IGUI_IKST_ClaimReq_WalkLarger", "Walk farther (min")
        if not walk then
            larger = IKST.text("IGUI_IKST_ClaimReq_TooSmall", "Drag a larger zone (min")
        end
        return larger
            .. " " .. tostring(IKST_Claim.MIN_DIM) .. "). "
            .. IKST.text("IGUI_IKST_ClaimReq_NowSize", "Now")
            .. " " .. tostring(draw.w or "?") .. "x" .. tostring(draw.h or "?")
    end
    if draw and draw.reason == "floor" then
        return IKST.text("IGUI_IKST_ClaimReq_SameFloor", "Both corners must be on the same floor.")
    end
    if draw then
        return IKST.text("IGUI_IKST_ClaimReq_BadSize", "Zone must be")
            .. " " .. IKST_Claim.sizeRangeLabel()
            .. " (now " .. tostring(draw.w or "?") .. "x" .. tostring(draw.h or "?") .. ")"
    end
    if walk then
        return IKST.text("IGUI_IKST_ClaimReq_WalkToB",
            "Walk to the opposite corner. The zone is from where you started to where you stand.")
    end
    return IKST.text("IGUI_IKST_ClaimReq_DragHint",
        "Drag on the world to mark the zone. Running will not move it.")
end

function ClaimReqHud:syncWalkCorner()
    if IKST_ClaimRequestDraw._waitingConfirm then
        return
    end
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    if not state or state.claimReqMode ~= "walk" or not state.claimReqA then
        return
    end
    local corner = playerCorner(self.player)
    if not corner then
        return
    end
    state.claimReqB = corner
    writeDrawState(state, state.claimReqA, state.claimReqB)
end

function ClaimReqHud:prerender()
    self:syncWalkCorner()
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    local draw = state and state.claimReqDraw
    if self.send then
        self.send.enable = draw and draw.ok == true and not IKST_ClaimRequestDraw._waitingConfirm and not self._dragging
    end
    if IKUI_Chrome and type(IKUI_Chrome.drawSoftShell) == "function" then
        IKUI_Chrome.drawSoftShell(self)
    else
        self:drawRect(0, 0, self.width, self.height, 0.92, 0.08, 0.10, 0.12)
    end
    local accent = IKUI_Chrome and IKUI_Chrome.colors and IKUI_Chrome.colors.accent
    if accent then
        self:drawRect(0, 0, 3, self.height, 1, accent.r, accent.g, accent.b)
    else
        self:drawRect(0, 0, 3, self.height, 1, FILL_R, FILL_G, FILL_B)
    end
    self:paintWorldHighlight()
end

function ClaimReqHud:render()
    local pad = self._pad or 16
    local fontH = self._fontH or 14
    local title = IKST.text("IGUI_IKST_ClaimReq_SelectTitle", "Select claim zone")
    local tp = IKUI_Chrome and IKUI_Chrome.colors and IKUI_Chrome.colors.textPrimary
    local tm = IKUI_Chrome and IKUI_Chrome.colors and IKUI_Chrome.colors.textMuted
    local tr, tg, tb = 0.96, 0.96, 0.97
    local mr, mg, mb = 0.56, 0.56, 0.58
    if tp then
        tr, tg, tb = tp.r, tp.g, tp.b
    end
    if tm then
        mr, mg, mb = tm.r, tm.g, tm.b
    end
    self:drawText(title, pad + 4, pad, tr, tg, tb, 1, UIFont.Small)
    local body = self:hudText()
    self:drawText(body, pad + 4, pad + fontH + 6, mr, mg, mb, 1, UIFont.Small)
end

function ClaimReqHud:paintWorldHighlight()
    local player = self.player
    if not player or not IKST_ClaimRequestDraw.isActive(player) then
        return
    end
    local state = IKST.getPlayerState and IKST.getPlayerState(player)
    local a = state and state.claimReqA
    local b = state and state.claimReqB
    if not a or not b then
        return
    end
    local draw = writeDrawState(state, a, b)
    local x = (draw and draw.x) or a.x
    local y = (draw and draw.y) or a.y
    local w = (draw and draw.w) or 0
    local h = (draw and draw.h) or 0
    local z = (draw and draw.z) or a.z
    local fr, fg, fb, fa = FILL_R, FILL_G, FILL_B, FILL_A
    if not (draw and draw.ok) then
        fr, fg, fb, fa = BAD_R, BAD_G, BAD_B, BAD_A
    end
    rememberPaint(x, y, w, h, z)
    paintArea(player, x, y, w, h, z, fr, fg, fb, fa)
end

function ClaimReqHud:onMouseDownOutside(x, y)
    if self.playerNum ~= 0 then
        return
    end
    if IKST_ClaimRequestDraw.isWalkMode(self.player) then
        return
    end
    if IKST_ClaimRequestDraw._waitingConfirm or self._dragging then
        return
    end
    if clickIsOnOtherUI(self) then
        return
    end
    local absX = x + self:getAbsoluteX()
    local absY = y + self:getAbsoluteY()
    local picked = worldSquareAtScreen(self.player, absX, absY)
    if not picked then
        return
    end
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    if not state then
        return
    end
    state.claimReqA = { x = picked.x, y = picked.y, z = picked.z }
    state.claimReqB = { x = picked.x, y = picked.y, z = picked.z }
    writeDrawState(state, state.claimReqA, state.claimReqB)
    self._dragging = true
    setWorldMenuBlocked(true)
end

function ClaimReqHud:onMouseMoveOutside(dx, dy)
    if self.playerNum ~= 0 or not self._dragging then
        return
    end
    if IKST_ClaimRequestDraw._waitingConfirm then
        return
    end
    local picked = worldSquareAtScreen(self.player, getMouseX(), getMouseY())
    if not picked then
        return
    end
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    if not state or not state.claimReqA then
        return
    end
    state.claimReqB = { x = picked.x, y = picked.y, z = picked.z }
    writeDrawState(state, state.claimReqA, state.claimReqB)
end

function ClaimReqHud:onMouseUpOutside(x, y)
    if self.playerNum ~= 0 then
        return
    end
    self:finishDrag()
end

function ClaimReqHud:onMouseUp(x, y)
    ISPanelJoypad.onMouseUp(self, x, y)
    self:finishDrag()
end

function ClaimReqHud:finishDrag()
    if IKST_ClaimRequestDraw.isWalkMode(self.player) then
        return
    end
    if not self._dragging then
        return
    end
    self._dragging = false
    setWorldMenuBlocked(false)
    if IKST_ClaimRequestDraw._waitingConfirm then
        return
    end
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    local a = state and state.claimReqA
    local b = state and state.claimReqB
    if not a or not b then
        return
    end
    local draw = writeDrawState(state, a, b)
    if not draw or not draw.ok then
        state.claimReqA = nil
        state.claimReqB = nil
        state.claimReqDraw = { w = 0, h = 0, ok = false }
        local p = self.player
        if p and draw and draw.reason == "too_large" then
            IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_TooLarge", "Too large (max")
                .. " " .. tostring(IKST_Claim.MAX_DIM) .. ").", false)
        elseif p then
            IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_TooSmall", "Drag a larger zone (min")
                .. " " .. tostring(IKST_Claim.MIN_DIM) .. ").", false)
        end
        return
    end
    self:submitIfReady()
end

function ClaimReqHud:submitIfReady()
    if IKST_ClaimRequestDraw._waitingConfirm then
        return
    end
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    local draw = state and state.claimReqDraw
    if not state or not state.claimReqA or not state.claimReqB or not draw or not draw.ok then
        return
    end
    local onReady = IKST_ClaimRequestDraw._onReady
    if type(onReady) ~= "function" then
        return
    end
    IKST_ClaimRequestDraw._waitingConfirm = true
    if self.send then
        self.send.enable = false
    end
    onReady()
end

function IKST_ClaimRequestDraw.ensureHud(player)
    if IKST_ClaimRequestDraw._hud then
        if IKST_ClaimRequestDraw._hud.player == player then
            return
        end
        IKST_ClaimRequestDraw._hud:removeFromUIManager()
        IKST_ClaimRequestDraw._hud = nil
    end
    local hud = ClaimReqHud:new(player)
    hud:initialise()
    hud:instantiate()
    hud:addToUIManager()
    IKST_ClaimRequestDraw._hud = hud
    local pn = playerNum(player)
    if JoypadState and JoypadState.players and JoypadState.players[pn + 1] and type(setJoypadFocus) == "function" then
        setJoypadFocus(pn, hud)
    end
end

function IKST_ClaimRequestDraw.paint(player)
    if not player or not IKST_ClaimRequestDraw.isActive(player) then
        if IKST_ClaimRequestDraw._hud and IKST_ClaimRequestDraw._hud.player == player then
            IKST_ClaimRequestDraw._hud:removeFromUIManager()
            IKST_ClaimRequestDraw._hud = nil
        end
        return
    end
    IKST_ClaimRequestDraw.ensureHud(player)
end
