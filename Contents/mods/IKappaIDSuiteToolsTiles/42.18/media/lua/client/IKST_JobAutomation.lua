if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"

IKST_JobAutomation = IKST_JobAutomation or {}

function IKST_JobAutomation.radiusLabel(preset)
    if preset == IKST.RADIUS_PRESETS.S then
        return IKST.text("IGUI_IKST_Radius_S", "Small") .. " (" .. preset .. ")"
    end
    if preset == IKST.RADIUS_PRESETS.L then
        return IKST.text("IGUI_IKST_Radius_L", "Large") .. " (" .. preset .. ")"
    end
    return IKST.text("IGUI_IKST_Radius_M", "Medium") .. " (" .. preset .. ")"
end

function IKST_JobAutomation.dispatchRadius(panel, command)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local radius = state and state.autoRadius or IKST.RADIUS_PRESETS.M
    IKST.dispatchCommand(p, command, {
        x = math.floor(p:getX()),
        y = math.floor(p:getY()),
        z = p:getZ(),
        radius = radius,
    })
end

function IKST_JobAutomation.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    if not state.autoRadius then
        state.autoRadius = IKST.RADIUS_PRESETS.M
    end

    local y = 8
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Auto_Note", "Batch admin tools at your feet. Protected tiles are skipped."), UIFont.Small)
    y = y + 22

    local presets = { IKST.RADIUS_PRESETS.S, IKST.RADIUS_PRESETS.M, IKST.RADIUS_PRESETS.L }
    local x = 12
    for _, preset in ipairs(presets) do
        panel:makeJobButton(x, y, 90, 24, IKST_JobAutomation.radiusLabel(preset), function()
            state.autoRadius = preset
            panel:refreshJobUI()
        end, state.autoRadius == preset)
        x = x + 94
    end
    y = y + 32

    local p = panel.player
    local actions = {
        { cmd = IKST.CMD.autoGardener, label = IKST.text("IGUI_IKST_Auto_Gardener", "Gardener"), desc = IKST.text("IGUI_IKST_Auto_Gardener_Desc", "Removes shrubs and grass overlays in radius.") },
        { cmd = IKST.CMD.autoLumberjack, label = IKST.text("IGUI_IKST_Auto_Lumberjack", "Lumberjack"), desc = IKST.text("IGUI_IKST_Auto_Lumberjack_Desc", "Removes tree sprites in radius.") },
        { cmd = IKST.CMD.autoGravel, label = IKST.text("IGUI_IKST_Auto_Gravel", "Gravel buddy"), desc = IKST.text("IGUI_IKST_Auto_Gravel_Desc", "Gives dirt/sand/gravel bags for soil under feet. No rewind.") },
        { cmd = IKST.CMD.autoCorpseStack, label = IKST.text("IGUI_IKST_Auto_Corpse", "Corpse stack"), desc = IKST.text("IGUI_IKST_Auto_Corpse_Desc", "Moves corpses to your square.") },
        { cmd = IKST.CMD.autoHomeWreck, label = IKST.text("IGUI_IKST_Auto_HomeWreck", "Home wrecker"), desc = IKST.text("IGUI_IKST_Auto_HomeWreck_Desc", "Clears all objects in radius. Destructive.") },
        { cmd = IKST.CMD.autoFarmer, label = IKST.text("IGUI_IKST_Auto_Farmer", "Farmer water"), desc = IKST.text("IGUI_IKST_Auto_Farmer_Desc", "Waters crops and plants in radius.") },
        { cmd = IKST.CMD.autoUnloadContainers, label = IKST.text("IGUI_IKST_Auto_Unload", "Unload containers"), desc = IKST.text("IGUI_IKST_Auto_Unload_Desc", "Drops container contents on the ground.") },
    }

    local colW = math.floor(((panel.contentW or (panel.width - 24)) - 8) / 2)
    for i, action in ipairs(actions) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local bx = IKST_JobLayout.MARGIN + col * (colW + 8)
        local by = y + row * 40
        panel:makeJobButton(bx, by, colW, 24, action.label, function()
            IKST_JobAutomation.dispatchRadius(panel, action.cmd)
        end, i == 1)
        panel:makeJobLabel(bx, by + 24, action.desc, UIFont.Small)
    end
    y = y + math.ceil(#actions / 2) * 40 + 8

    IKST_ActionLog.dock(panel, panel.player, y)
    return y
end
