-- Briefing cache + hub redirect. Rules live in Everyone → Help (soft).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_BriefingUI = IKST_BriefingUI or {}
IKST_BriefingUI._cache = IKST_BriefingUI._cache or nil

function IKST_BriefingUI.open(player, _sectionId)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    if not player then
        return
    end
    if not (IKST_Hub and type(IKST_Hub.openWorkspace) == "function") then
        return
    end
    IKST_Hub.openWorkspace(player, IKST.VIEW.everyone, "help")
    local panel = type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
    if not panel then
        return
    end
    panel.helpShowRules = true
    if type(panel.refreshJobUI) == "function" then
        panel:refreshJobUI(true)
    end
end

function IKST_BriefingUI.onResult(args)
    IKST_BriefingUI._cache = args
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive(true)
    end
end
