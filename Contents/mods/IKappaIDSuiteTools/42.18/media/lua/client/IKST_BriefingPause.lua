-- Adds Server Briefing to the in-game pause menu (ESC), coexisting with other mods.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Briefing"

local function lowestMenuBottom(self)
    local maxBottom = self.quitToDesktop and self.quitToDesktop:getBottom() or 0
    if not self.bottomPanel or not self.bottomPanel.getChildren then
        return maxBottom
    end
    for _, child in pairs(self.bottomPanel:getChildren()) do
        if child.Type == "ISLabel" and child ~= self.ikstBriefingOption then
            local b = child:getBottom()
            if b and b > maxBottom then
                maxBottom = b
            end
        end
    end
    return maxBottom
end

local function positionBriefingItem(self)
    if not self.ikstBriefingOption or not self.bottomPanel then
        return
    end
    self.ikstBriefingOption:setY(lowestMenuBottom(self) + 16)
    self.bottomPanel:setHeight(self.ikstBriefingOption:getBottom())
end

local originalInstantiate = MainScreen.instantiate
function MainScreen:instantiate()
    originalInstantiate(self)

    if not self.inGame or not IKST_Briefing.enabled() then
        return
    end
    if self.ikstBriefingOption then
        return
    end

    local labelHgt = getTextManager():getFontHeight(UIFont.Large) + 16
    self.ikstBriefingOption = ISLabel:new(self.quitToDesktop.x, self.quitToDesktop:getBottom() + 16,
        labelHgt, IKST.text("IGUI_IKST_Briefing_Menu", "Server Briefing"), 1, 1, 1, 1, UIFont.Large, true)
    self.ikstBriefingOption.internal = "IKST_BRIEFING"
    self.ikstBriefingOption:initialise()
    self.bottomPanel:addChild(self.ikstBriefingOption)
    self.ikstBriefingOption:setWidth(self.quitToDesktop.width)

    self.ikstBriefingOption.fade = UITransition.new()
    self.ikstBriefingOption.fade:setFadeIn(false)
    self.ikstBriefingOption.prerender = MainScreen.prerenderBottomPanelLabel
    self.ikstBriefingOption.onMouseMove = function(label)
        label.fade:setFadeIn(true)
    end
    self.ikstBriefingOption.onMouseMoveOutside = function(label)
        label.fade:setFadeIn(false)
    end
    self.ikstBriefingOption.onMouseDown = function()
        getSoundManager():playUISound("UIActivateMainMenuItem")
        if IKST_BriefingUI and IKST_BriefingUI.open then
            IKST_BriefingUI.open(getPlayer())
        end
    end

    positionBriefingItem(self)

    local prevRender = self.render or MainScreen.render
    self.render = function(s)
        prevRender(s)
        if s.inGame and s.ikstBriefingOption then
            positionBriefingItem(s)
        end
    end
end
