if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then return end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_JobLayout"

IKST_ActionLog = IKST_ActionLog or {}

function IKST_ActionLog.create(parent, x, y, w, h, player)
    local logPanel = ISRichTextPanel:new(x, y, w, h)
    logPanel:initialise()
    logPanel.backgroundColor = IKST_Chrome.colors.bgCard
    logPanel.borderColor = IKST_Chrome.colors.accentDim
    logPanel:setMargins(8, 8, 8, 8)
    if parent.addChromeWidget then
        parent:addChromeWidget(logPanel)
    else
        parent:addJobWidget(logPanel)
    end
    IKST_ActionLog.refresh(logPanel, player)
    return logPanel
end

function IKST_ActionLog.dock(parent, player, _)
    local x, y, w, h = IKST_JobLayout.logRect(parent)
    parent.logPanel = IKST_ActionLog.create(parent, x, IKST_JobLayout.toLayerY(parent, y), w, h, player)
    return parent.logPanel
end

function IKST_ActionLog.refresh(logPanel, player)
    if not logPanel then
        return
    end
    local state = IKST.getPlayerState(player)
    local logTitle = IKST.text("IGUI_IKST_ActionLog", "Action log")
    local lines = state and state.log or {}
    if #lines == 0 then
        logPanel:setText("<TEXT> " .. logTitle .. "<LINE><RGB:0.55,0.6,0.65> " .. IKST.text("IGUI_IKST_NoLog", "No actions yet."))
    else
        local text = "<TEXT> " .. logTitle .. "<LINE>"
        for i, line in ipairs(lines) do
            text = text .. "<LINE><RGB:0.75,0.78,0.82> " .. line
            if i >= 10 then
                break
            end
        end
        logPanel:setText(text)
    end
    logPanel:paginate()
end
