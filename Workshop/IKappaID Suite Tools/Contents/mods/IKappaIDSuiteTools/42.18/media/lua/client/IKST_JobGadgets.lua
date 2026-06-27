if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_QuickActions"
require "IKST_HubNav"
require "IKST_JobLayout"
require "IKST_JobThreat"
require "IKST_JobLayout"

IKST_JobGadgets = IKST_JobGadgets or {}

function IKST_JobGadgets.buildQuickPage(panel)
    local y = 8
    local p = panel.player
    local state = IKST.getPlayerState(p)

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Quick_Self", "You"), UIFont.Small)
    y = y + 18
    panel:makeJobButton(12, y, 72, 24, IKST.text("IGUI_IKST_Heal", "Heal"), function()
        IKST_QuickActions.run(p, "healSelf")
    end, true)
    panel:makeJobButton(90, y, 72, 24, IKST.text("IGUI_IKST_Feed", "Feed"), function()
        IKST_QuickActions.run(p, "feedSelf")
    end, false)
    panel:makeJobButton(168, y, 72, 24, IKST.text("IGUI_IKST_Cure", "Cure"), function()
        IKST_QuickActions.run(p, "cureSelf")
    end, false)
    panel:makeJobButton(246, y, 72, 24, IKST.text("IGUI_IKST_God", "God"), function()
        IKST_QuickActions.run(p, "godSelf")
    end, false)
    y = y + 32

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Quick_World", "World"), UIFont.Small)
    y = y + 18
    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Save", "Save world"), function()
        IKST.dispatchCommand(p, IKST.CMD.quickSave, {})
    end, false)
    panel:makeJobButton(118, y, 100, 24, IKST.text("IGUI_IKST_Broadcast", "Broadcast"), function()
        local msg = "Admin message"
        if state and state.lastBroadcast and state.lastBroadcast ~= "" then
            msg = state.lastBroadcast
        end
        IKST.dispatchCommand(p, IKST.CMD.quickBroadcast, { message = msg })
    end, false)
    panel:makeJobButton(224, y, 120, 24, IKST.text("IGUI_IKST_ClearZombies", "Clear zombies"), function()
        IKST_QuickActions.run(p, "clearZombies")
    end, true)
    y = y + 32

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Gadget_utilities", "Water & power"), UIFont.Small)
    y = y + 18
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Water", "Water"), function()
        IKST_QuickActions.run(p, "quickWater")
        panel:refreshJobUI()
    end, IKST.isWaterOn())
    panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_Power", "Power"), function()
        IKST_QuickActions.run(p, "quickPower")
        panel:refreshJobUI()
    end, IKST.isPowerOn())
    y = y + 28
    panel:makeJobLabel(12, y, IKST.utilityStatusLine(), UIFont.Small)
    y = y + 22

    if IKST_JobThreat then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Gadget_zombies", "Zombies"), UIFont.Small)
        y = y + 18
        if not panel.threatRadius then
            panel.threatRadius = IKST.RADIUS_PRESETS.M
        end
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Scope_Radius", "Radius") .. " " .. panel.threatRadius, function()
            local presets = { IKST.RADIUS_PRESETS.S, IKST.RADIUS_PRESETS.M, IKST.RADIUS_PRESETS.L }
            local idx = 1
            for i, val in ipairs(presets) do
                if val == panel.threatRadius then
                    idx = i
                    break
                end
            end
            panel.threatRadius = presets[(idx % #presets) + 1]
            panel:refreshJobUI()
        end, false)
        panel:makeJobButton(140, y, 100, 24, IKST.text("IGUI_IKST_Scan", "Scan"), function()
            IKST.dispatchCommand(p, IKST.CMD.threatPopulation, {
                x = math.floor(p:getX()), y = math.floor(p:getY()), z = p:getZ(),
                radius = panel.threatRadius,
            })
        end, false)
        panel:makeJobButton(250, y, 100, 24, IKST.text("IGUI_IKST_Cull", "Cull"), function()
            IKST.dispatchCommand(p, IKST.CMD.threatCull, {
                x = math.floor(p:getX()), y = math.floor(p:getY()), z = p:getZ(),
                radius = panel.threatRadius,
            })
        end, true)
        y = y + 34
        local stats = IKST_JobThreat.stats
        panel:makeJobLabel(12, y, "Zombies: " .. tostring(stats.total) .. "  Sprinters: " .. tostring(stats.sprinters), UIFont.Small)
        y = y + 22
    end

    if IKST_JobTilesGuard and IKST_JobTilesGuard.buildRestore then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Gadget_backups", "Backups"), UIFont.Small)
        y = y + 18
        y = IKST_JobTilesGuard.buildRestore(panel, y)
    end

    panel.logPanel = IKST_ActionLog.dock(panel, p, y)
    return y
end

function IKST_JobGadgets.build(panel)
    return IKST_JobGadgets.buildQuickPage(panel)
end
