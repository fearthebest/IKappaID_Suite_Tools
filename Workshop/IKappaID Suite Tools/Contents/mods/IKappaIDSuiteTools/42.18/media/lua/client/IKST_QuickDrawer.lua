if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then

    return

end



require "IKST_Shared"

require "IKST_Utility"

require "IKST_QuickActions"

require "IKST_Chrome"

require "IKST_HubNav"



IKST_QuickDrawer = IKST_QuickDrawer or {}



function IKST_QuickDrawer.waterLabel()

    if IKST.isWaterShutOff() then

        return IKST.text("IGUI_IKST_Water_Off", "Water: OFF")

    end

    return IKST.text("IGUI_IKST_Water_On", "Water: ON")

end



function IKST_QuickDrawer.powerLabel()

    if IKST.isPowerShutOff() then

        return IKST.text("IGUI_IKST_Power_Off", "Power: OFF")

    end

    return IKST.text("IGUI_IKST_Power_On", "Power: ON")

end



function IKST_QuickDrawer.getCommands(player)

    return {

        {

            id = "save",

            label = IKST.text("IGUI_IKST_Save", "Save world"),

            run = function()

                IKST.dispatchCommand(player, IKST.CMD.quickSave, {})

            end,

        },

        {

            id = "broadcast",

            label = IKST.text("IGUI_IKST_Broadcast", "Broadcast"),

            run = function()

                local state = IKST.getPlayerState(player)

                local msg = "Admin message"

                if state and state.lastBroadcast and state.lastBroadcast ~= "" then

                    msg = state.lastBroadcast

                end

                IKST.dispatchCommand(player, IKST.CMD.quickBroadcast, { message = msg })

            end,

        },

        {

            id = "water",

            label = IKST_QuickDrawer.waterLabel(),

            run = function()

                IKST_QuickActions.run(player, "quickWater")

                if IKST_JobsPanel and IKST_JobsPanel.instance then

                    IKST_JobsPanel.instance:refreshJobUI()

                end

            end,

        },

        {

            id = "power",

            label = IKST_QuickDrawer.powerLabel(),

            run = function()

                IKST_QuickActions.run(player, "quickPower")

                if IKST_JobsPanel and IKST_JobsPanel.instance then

                    IKST_JobsPanel.instance:refreshJobUI()

                end

            end,

        },

    }

end



function IKST_QuickDrawer.addHit(panel, x, y, w, h, run)

    panel.quickHits = panel.quickHits or {}

    table.insert(panel.quickHits, { x = x, y = y, w = w, h = h, run = run })

end



function IKST_QuickDrawer.drawButtonRow(panel, y, buttons, primaryIds)

    primaryIds = primaryIds or {}

    local x = 12

    local rowH = 0

    for _, cmd in ipairs(buttons) do

        local active = false

        for _, pid in ipairs(primaryIds) do

            if cmd.id == pid then

                active = true

                break

            end

        end

        local w = getTextManager():MeasureStringX(UIFont.Small, cmd.label) + 20

        if w < 52 then

            w = 52

        end

        IKST_Chrome.drawTextButton(panel, x, y, w, 22, cmd.label, active)

        IKST_QuickDrawer.addHit(panel, x, y, w, 22, cmd.run)

        x = x + w + 6

        rowH = 22

    end

    return y + rowH

end



function IKST_QuickDrawer.drawHubStrip(panel, bodyY)

    panel.quickHits = {}

    local cc = IKST_Chrome.colors

    local y = bodyY

    local startY = y



    local state = IKST.getPlayerState(panel.player)

    if state and state.lastNavMode and not IKST_HubNav.isHomeView(state.lastNavMode) then

        local resumeLabel = IKST.text("IGUI_IKST_Continue", "Continue")

            .. ": " .. IKST_HubNav.labelForNav(state.lastNavMode, state.lastNavTool)

        local rw = getTextManager():MeasureStringX(UIFont.Small, resumeLabel) + 24

        if rw < 140 then

            rw = 140

        end

        IKST_Chrome.drawTextButton(panel, 12, y, rw, 24, resumeLabel, true)

        IKST_QuickDrawer.addHit(panel, 12, y, rw, 24, function()

            panel:enterNav(state.lastNavMode, state.lastNavTool)

        end)

        y = y + 30

    elseif state and state.lastView and not IKST_HubNav.isHomeView(state.lastView) then

        local mode, tool = IKST_HubNav.resolveView(state.lastView)

        local resumeLabel = IKST.text("IGUI_IKST_Continue", "Continue")

            .. ": " .. IKST_HubNav.labelForNav(mode, tool)

        local rw = getTextManager():MeasureStringX(UIFont.Small, resumeLabel) + 24

        if rw < 140 then

            rw = 140

        end

        IKST_Chrome.drawTextButton(panel, 12, y, rw, 24, resumeLabel, true)

        IKST_QuickDrawer.addHit(panel, 12, y, rw, 24, function()

            panel:enterNav(mode, tool)

        end)

        y = y + 30

    end



    local recent = IKST_HubNav.getRecentViews(panel.player)

    if recent and #recent > 0 then

        panel:drawText(IKST.text("IGUI_IKST_RecentTools", "Recent"), 12, y, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)

        y = y + 16

        local x = 12

        for _, recentKey in ipairs(recent) do

            local mode, tool = IKST_HubNav.parseRecentKey(recentKey)

            if not mode then

                mode, tool = IKST_HubNav.resolveView(recentKey)

            end

            local label = IKST_HubNav.labelForNav(mode, tool)

            local w = getTextManager():MeasureStringX(UIFont.Small, label) + 18

            if w < 48 then

                w = 48

            end

            IKST_Chrome.drawTextButton(panel, x, y, w, 22, label, false)

            IKST_QuickDrawer.addHit(panel, x, y, w, 22, function()

                panel:enterNav(mode, tool)

            end)

            x = x + w + 6

        end

        y = y + 28

    end



    panel:drawText(IKST.text("IGUI_IKST_QuickFavorites", "Pinned"), 12, y, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)

    y = y + 16

    y = IKST_QuickDrawer.drawButtonRow(panel, y, IKST_QuickActions.getPinnedCommands(panel.player))



    panel.hubQuickHeight = y - startY + 8

end



function IKST_QuickDrawer.tryClick(panel, x, y)

    if not panel.quickHits then

        return false

    end

    for _, hit in ipairs(panel.quickHits) do

        if x >= hit.x and x <= hit.x + hit.w and y >= hit.y and y <= hit.y + hit.h then

            if hit.run then

                hit.run()

            end

            return true

        end

    end

    return false

end

