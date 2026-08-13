if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then return end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_JobLayout"

IKST_ActionLog = IKST_ActionLog or {}

function IKST_ActionLog.create(parent, x, y, w, h, player)
    local logPanel = ISRichTextPanel:new(x, y, w, h)
    logPanel:initialise()
    -- Transparent so our rounded background shows through instead of the
    -- vanilla ISPanel square fill/border; text/scroll rendering below is
    -- untouched (instance-only override, not a shared-class monkey patch).
    logPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    logPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    if type(ISRichTextPanel) == "table" and type(ISRichTextPanel.render) == "function" then
        logPanel.render = function(self)
            IKST_Chrome.drawRoundedCard(self, 0, 0, self.width, self.height,
                { shadow = false, borderColor = IKST_Chrome.colors.accentDim })
            ISRichTextPanel.render(self)
        end
    end
    logPanel:setMargins(8, 8, 8, 8)
    if parent.addQ4Widget then
        parent:addQ4Widget(logPanel)
    elseif parent.addChromeWidget then
        parent:addChromeWidget(logPanel)
    else
        parent:addJobWidget(logPanel)
    end
    IKST_ActionLog.refresh(logPanel, player)
    return logPanel
end

-- Action log docked on the right; paginate() gives ISRichTextPanel scroll buttons.
-- Prefer JobsPanel:updateLog as the single dock path. Jobs may call dock() once;
-- repeated docks reuse the existing panel when already present.
function IKST_ActionLog.dock(parent, player, _)
    if parent.logPanel and parent.logPanel.parent then
        IKST_ActionLog.refresh(parent.logPanel, player)
        return parent.logPanel
    end
    if parent.q4Panel then
        if not parent.q4Panel:getIsVisible() then
            return nil
        end
        local w = parent.q4Panel:getWidth()
        local h = parent.q4Panel:getHeight()
        if not w or w < 40 or not h or h < 40 then
            return nil
        end
        parent.logPanel = IKST_ActionLog.create(parent, 0, 0, w, h, player)
        return parent.logPanel
    end
    local x, y, w, h = IKST_JobLayout.logRect(parent)
    if not w or w < 40 then
        return nil
    end
    parent.logPanel = IKST_ActionLog.create(parent, x, IKST_JobLayout.toLayerY(parent, y), w, h, player)
    return parent.logPanel
end

-- Full action history (no 10-line cap) so the right column scrolls.
function IKST_ActionLog.lineRgb(kind, text)
    local c = IKST_Chrome.colors
    local k = kind
    if not k and type(text) == "string" then
        if string.find(text, "^DENIED") or string.find(text, "denied") then
            k = "deny"
        elseif string.find(text, "/") and string.find(text, "%d+/%d+") then
            k = "progress"
        end
    end
    if k == "deny" or k == "danger" or k == "error" then
        return c.danger.r, c.danger.g, c.danger.b
    end
    if k == "success" then
        return c.success.r, c.success.g, c.success.b
    end
    if k == "progress" or k == "accent" then
        return c.accent.r, c.accent.g, c.accent.b
    end
    return c.textMuted.r, c.textMuted.g, c.textMuted.b
end

function IKST_ActionLog.refresh(logPanel, player)
    if not logPanel then
        return
    end
    local state = IKST.getPlayerState(player)
    local logTitle = IKST.text("IGUI_IKST_ActionLog", "Action log")
    local lines = state and state.log or {}
    local omitTitle = logPanel._ikstOmitTitle == true
    if #lines == 0 then
        if omitTitle then
            logPanel:setText("<TEXT><RGB:0.55,0.6,0.65> " .. IKST.text("IGUI_IKST_NoLog", "No actions yet."))
        else
            logPanel:setText("<TEXT> " .. logTitle .. "<LINE><RGB:0.55,0.6,0.65> " .. IKST.text("IGUI_IKST_NoLog", "No actions yet."))
        end
    else
        local text = omitTitle and "<TEXT>" or ("<TEXT> " .. logTitle .. "<LINE>")
        for _, line in ipairs(lines) do
            local body = line
            local kind = nil
            if type(line) == "table" then
                body = line.text or ""
                kind = line.kind
            end
            local r, g, b = IKST_ActionLog.lineRgb(kind, body)
            text = text .. string.format("<LINE><RGB:%.2f,%.2f,%.2f> %s", r, g, b, tostring(body))
        end
        logPanel:setText(text)
    end
    logPanel:paginate()
    if type(logPanel.updateScrollbars) == "function" then
        logPanel:updateScrollbars()
    end
end
