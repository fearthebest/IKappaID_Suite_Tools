if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISButton"
require "IKST_Shared"
require "IKST_Access"
require "IKST_Chrome"

IKST_HudChip = ISPanel:derive("IKST_HudChip")
IKST_HudChip.instance = nil

function IKST_HudChip:new(player)
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w, h = 320, 36
    local o = ISPanel:new(sw - w - 16, sh - h - 72, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    IKST_Chrome.applyPanelColors(o)
    o.moveWithMouse = false
    return o
end

function IKST_HudChip:createChildren()
    local openLabel = IKST.text("IGUI_IKST_Hud_Open", "Open panel")
    self.openBtn = ISButton:new(self.width - 92, 6, 84, 22, openLabel, self, IKST_HudChip.onOpen)
    self.openBtn:initialise()
    IKST_Chrome.styleSecondaryButton(self.openBtn)
    self:addChild(self.openBtn)
end

function IKST_HudChip:onOpen()
    if IKST_JobsPanel and self.player then
        IKST_JobsPanel.open(self.player)
    end
end

function IKST_HudChip:getStatusText()
    local state = IKST.getPlayerState(self.player)
    if not state or not state.armed then
        return ""
    end
    if state.armedJob == IKST.VIEW.painter then
        local modeLabel = IKST.text("IGUI_IKST_Paint", "Paint")
        if state.painterMode == IKST.PAINTER_MODES.eyedropper then
            modeLabel = IKST.text("IGUI_IKST_Eyedropper", "Eyedropper")
        elseif state.painterMode == IKST.PAINTER_MODES.remove then
            modeLabel = IKST.text("IGUI_IKST_Remove", "Remove")
        elseif state.painterMode == IKST.PAINTER_MODES.replace then
            modeLabel = IKST.text("IGUI_IKST_Replace", "Replace")
        end
        return IKST.text("IGUI_IKST_Job_Painter", "World Painter") .. " · " .. modeLabel
    end
    if state.armedJob == IKST.VIEW.inspector then
        return IKST.text("IGUI_IKST_Job_Inspector", "Square Inspector") .. " · " .. IKST.text("IGUI_IKST_Armed", "ARMED")
    end
    if state.armedJob == IKST.VIEW.loot and IKST.getLootScope and IKST.lootScopeLabel then
        return IKST.text("IGUI_IKST_Job_Loot", "Loot repopulate") .. " · " .. IKST.lootScopeLabel(IKST.getLootScope(state), state)
    end
    local action = IKST.cleanupActionLabel(IKST.getCleanupAction(state))
    local scope = IKST.cleanupScopeLabel(IKST.getCleanupScope(state), state)
    return IKST.text("IGUI_IKST_Job_Cleanup", "Cleanup Crew") .. " · " .. action .. " · " .. scope
end

function IKST_HudChip:prerender()
    ISPanel.prerender(self)
    local c = IKST_Chrome.colors.accent
    self:drawRect(0, 0, 3, self.height, 1, c.r, c.g, c.b)
end

function IKST_HudChip:render()
    local text = self:getStatusText()
    if text == "" then
        return
    end
    local c = IKST_Chrome.colors
    self:drawRect(10, 6, 6, 6, 1, c.accent.r, c.accent.g, c.accent.b)
    self:drawText("IKST · " .. text, 22, 10, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
end

function IKST_HudChip.shouldShow(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseTools(player) then
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state or not state.armed then
        return false
    end
    local panel = IKST_JobsPanel and IKST_JobsPanel.instance
    if panel and panel.getIsVisible and panel:getIsVisible() then
        return false
    end
    return true
end

function IKST_HudChip.sync(player)
    player = IKST.resolvePlayer(player)
    if not IKST_HudChip.shouldShow(player) then
        if IKST_HudChip.instance then
            IKST_HudChip.instance:setVisible(false)
        end
        return
    end
    if not IKST_HudChip.instance then
        IKST_HudChip.instance = IKST_HudChip:new(player)
        IKST_HudChip.instance:initialise()
        IKST_HudChip.instance:createChildren()
        IKST_HudChip.instance:addToUIManager()
    end
    IKST_HudChip.instance.player = player
    IKST_HudChip.instance:setVisible(true)
end

function IKST_HudChip.destroy()
    if IKST_HudChip.instance then
        IKST_HudChip.instance:removeFromUIManager()
        IKST_HudChip.instance = nil
    end
end
