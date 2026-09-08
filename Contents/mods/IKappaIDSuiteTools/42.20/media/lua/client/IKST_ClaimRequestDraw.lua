-- Live ground preview while a player walks claim-request corner A to B.
-- Vanilla addAreaHighlightForPlayer expires immediately; refresh every tick while active.
-- Staff preview: highlight a pending request zone after TP/select.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISUIElement"
require "IKST_Shared"
require "IKST_Claim"

IKST_ClaimRequestDraw = IKST_ClaimRequestDraw or {}

local FILL_R, FILL_G, FILL_B, FILL_A = 0.20, 0.75, 0.95, 0.28
local BAD_R, BAD_G, BAD_B, BAD_A = 0.95, 0.35, 0.25, 0.32
local STAFF_R, STAFF_G, STAFF_B, STAFF_A = 0.95, 0.55, 0.15, 0.35
local HUD_W, HUD_H = 340, 28

local function playerNum(player)
    if not player or type(player.getPlayerNum) ~= "function" then
        return 0
    end
    return player:getPlayerNum() or 0
end

local function floorPos(player)
    if not player or type(player.getX) ~= "function" then
        return nil
    end
    return {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ() or 0),
    }
end

function IKST_ClaimRequestDraw.isActive(player)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    return state ~= nil and state.claimReqA ~= nil
end

function IKST_ClaimRequestDraw.clear(player)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    if state then
        state.claimReqA = nil
        state.claimReqDraw = nil
    end
    if IKST_ClaimRequestDraw._hud and IKST_ClaimRequestDraw._hud.player == player then
        IKST_ClaimRequestDraw._hud:removeFromUIManager()
        IKST_ClaimRequestDraw._hud = nil
    end
end

function IKST_ClaimRequestDraw.start(player, cornerA)
    local state = player and IKST.getPlayerState and IKST.getPlayerState(player)
    if not state or not cornerA then
        return
    end
    state.claimReqA = {
        x = math.floor(tonumber(cornerA.x) or 0),
        y = math.floor(tonumber(cornerA.y) or 0),
        z = math.floor(tonumber(cornerA.z) or 0),
    }
    state.claimReqDraw = { w = 1, h = 1, ok = false }
    IKST_ClaimRequestDraw.ensureHud(player)
end

function IKST_ClaimRequestDraw.clearStaffPreview()
    IKST_ClaimRequestDraw._staffPreview = nil
end

function IKST_ClaimRequestDraw.setStaffPreview(rect)
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
end

function IKST_ClaimRequestDraw.paintStaffPreview(player)
    local preview = IKST_ClaimRequestDraw._staffPreview
    if not preview or not player or type(addAreaHighlightForPlayer) ~= "function" then
        return
    end
    local pn = playerNum(player)
    local x2 = preview.x + preview.w
    local y2 = preview.y + preview.h
    addAreaHighlightForPlayer(pn, preview.x, preview.y, x2, y2, preview.z, STAFF_R, STAFF_G, STAFF_B, STAFF_A)
end

local ClaimReqHud = ISUIElement:derive("IKST_ClaimReqHud")

function ClaimReqHud:new(player)
    local core = getCore and getCore() or nil
    local sw = core and core:getScreenWidth() or 800
    local sh = core and core:getScreenHeight() or 600
    local o = ISUIElement:new(math.floor((sw - HUD_W) / 2), sh - HUD_H - 96, HUD_W, HUD_H)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.background = false
    return o
end

function ClaimReqHud:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.72, 0.08, 0.10, 0.12)
    self:drawRect(0, 0, 3, self.height, 1, FILL_R, FILL_G, FILL_B)
end

function ClaimReqHud:render()
    local state = IKST.getPlayerState and IKST.getPlayerState(self.player)
    local draw = state and state.claimReqDraw
    local text
    if draw and draw.ok then
        text = IKST.text("IGUI_IKST_ClaimReq_Drawing", "Drawing claim zone")
            .. ": " .. tostring(draw.w) .. "x" .. tostring(draw.h)
            .. " - " .. IKST.text("IGUI_IKST_ClaimReq_PressB", "Set opposite corner when ready")
    elseif draw and draw.reason == "too_large" then
        text = IKST.text("IGUI_IKST_ClaimReq_TooLarge", "Too large (max")
            .. " " .. tostring(IKST_Claim.MAX_DIM) .. " "
            .. IKST.text("IGUI_IKST_ClaimReq_PerSide", "per side")
            .. "). "
            .. IKST.text("IGUI_IKST_ClaimReq_NowSize", "Now")
            .. " " .. tostring(draw.w or "?") .. "x" .. tostring(draw.h or "?")
            .. " - " .. IKST.text("IGUI_IKST_ClaimReq_WalkCloser", "walk closer")
    elseif draw and draw.reason == "too_small" then
        text = IKST.text("IGUI_IKST_ClaimReq_TooSmall", "Keep walking (min")
            .. " " .. tostring(IKST_Claim.MIN_DIM) .. "). "
            .. IKST.text("IGUI_IKST_ClaimReq_NowSize", "Now")
            .. " " .. tostring(draw.w or "?") .. "x" .. tostring(draw.h or "?")
    elseif draw and draw.reason == "floor" then
        text = IKST.text("IGUI_IKST_ClaimReq_SameFloor", "Both corners must be on the same floor.")
    elseif draw then
        text = IKST.text("IGUI_IKST_ClaimReq_BadSize", "Zone must be")
            .. " " .. IKST_Claim.sizeRangeLabel()
            .. " (now " .. tostring(draw.w or "?") .. "x" .. tostring(draw.h or "?") .. ")"
    else
        text = IKST.text("IGUI_IKST_ClaimReq_Drawing", "Drawing claim zone")
    end
    self:drawText(text, 10, 7, 0.92, 0.94, 0.96, 1, UIFont.Small)
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
    hud:addToUIManager()
    IKST_ClaimRequestDraw._hud = hud
end

function IKST_ClaimRequestDraw.paint(player)
    if not player or not IKST_ClaimRequestDraw.isActive(player) then
        if IKST_ClaimRequestDraw._hud and IKST_ClaimRequestDraw._hud.player == player then
            IKST_ClaimRequestDraw._hud:removeFromUIManager()
            IKST_ClaimRequestDraw._hud = nil
        end
        return
    end
    if type(addAreaHighlightForPlayer) ~= "function" then
        return
    end
    local state = IKST.getPlayerState(player)
    local a = state and state.claimReqA
    local here = floorPos(player)
    if not a or not here then
        return
    end
    local x, y, w, h = IKST_Claim.rectFromCorners(a.x, a.y, here.x, here.y)
    local sameFloor = (a.z or 0) == (here.z or 0)
    local reason = nil
    if not sameFloor then
        reason = "floor"
    elseif w < IKST_Claim.MIN_DIM or h < IKST_Claim.MIN_DIM then
        reason = "too_small"
    elseif w > IKST_Claim.MAX_DIM or h > IKST_Claim.MAX_DIM then
        reason = "too_large"
    end
    local ok = reason == nil
    state.claimReqDraw = { w = w, h = h, ok = ok, reason = reason, x = x, y = y, z = a.z or here.z }
    IKST_ClaimRequestDraw.ensureHud(player)

    local sig = tostring(w) .. "x" .. tostring(h) .. ":" .. tostring(ok)
    if IKST_ClaimRequestDraw._uiSig ~= sig then
        IKST_ClaimRequestDraw._uiSig = sig
        IKST_ClaimRequestDraw._uiRefreshTick = (IKST_ClaimRequestDraw._uiRefreshTick or 0) + 1
        if IKST_ClaimRequestDraw._uiRefreshTick % 12 == 0 then
            if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
                IKST_Hub.refreshActive()
            end
        end
    end

    local z = a.z or here.z
    local x2 = x + w
    local y2 = y + h
    local pn = playerNum(player)
    local fr, fg, fb, fa = FILL_R, FILL_G, FILL_B, FILL_A
    if not ok then
        fr, fg, fb, fa = BAD_R, BAD_G, BAD_B, BAD_A
    end
    addAreaHighlightForPlayer(pn, x, y, x2, y2, z, fr, fg, fb, fa)
end

local function onTick()
    if type(getSpecificPlayer) ~= "function" then
        return
    end
    local anyActive = false
    local anyStaff = IKST_ClaimRequestDraw._staffPreview ~= nil
    for i = 0, 3 do
        local player = getSpecificPlayer(i)
        if player and IKST_ClaimRequestDraw.isActive(player) then
            anyActive = true
            break
        end
    end
    if not anyActive and not anyStaff then
        if IKST_ClaimRequestDraw._hud then
            IKST_ClaimRequestDraw._hud:removeFromUIManager()
            IKST_ClaimRequestDraw._hud = nil
        end
        return
    end
    for i = 0, 3 do
        local player = getSpecificPlayer(i)
        if player then
            if anyActive then
                IKST_ClaimRequestDraw.paint(player)
            end
            if anyStaff then
                IKST_ClaimRequestDraw.paintStaffPreview(player)
            end
        end
    end
end

if Events and Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(onTick)
end
