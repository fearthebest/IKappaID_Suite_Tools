-- Adds Server Briefing to the in-game pause menu (ESC), coexisting with other mods.
-- B42.20+: the quit label is MainScreen.quitToDesktopOption (quitToDesktop is a method).

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Briefing"

local function quitLabel(self)
    if not self then
        return nil
    end
    -- B42.20 renamed the pause-menu label; quitToDesktop is now the quit method.
    local label = self.quitToDesktopOption
    if label and type(label) ~= "function" and (label.getBottom or label.x ~= nil) then
        return label
    end
    label = self.quitToDesktop
    if label and type(label) ~= "function" and (label.getBottom or label.x ~= nil) then
        return label
    end
    return nil
end

local function lowestMenuBottom(self)
    local quit = quitLabel(self)
    local maxBottom = 0
    if quit and quit.getBottom then
        maxBottom = quit:getBottom() or 0
    end
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

    local quit = quitLabel(self)
    if not quit or not self.bottomPanel then
        return
    end

    local labelHgt = getTextManager():getFontHeight(UIFont.Large) + 16
    local x = (type(quit.getX) == "function" and quit:getX()) or quit.x or 0
    local y = (type(quit.getBottom) == "function" and quit:getBottom()) or 0
    local w = (type(quit.getWidth) == "function" and quit:getWidth()) or quit.width or 200

    self.ikstBriefingOption = ISLabel:new(x, y + 16,
        labelHgt, IKST.text("IGUI_IKST_Briefing_Menu", "Server Briefing"), 1, 1, 1, 1, UIFont.Large, true)
    self.ikstBriefingOption.internal = "IKST_BRIEFING"
    self.ikstBriefingOption:initialise()
    self.bottomPanel:addChild(self.ikstBriefingOption)
    self.ikstBriefingOption:setWidth(w)

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
        if IKST_BriefingUI and type(IKST_BriefingUI.open) == "function" then
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
