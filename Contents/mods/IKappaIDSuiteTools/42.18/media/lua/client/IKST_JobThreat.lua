if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_JobLayout"
require "IKST_Threat"

IKST_JobThreat = IKST_JobThreat or {}
IKST_JobThreat.stats = { total = 0, sprinters = 0 }

function IKST_JobThreat.build(panel)
    if not panel.threatRadius then
        panel.threatRadius = IKST.RADIUS_PRESETS.M
    end

    local y = 8
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
        local p = panel.player
        IKST.dispatchCommand(p, IKST.CMD.threatPopulation, {
            x = math.floor(p:getX()),
            y = math.floor(p:getY()),
            z = p:getZ(),
            radius = panel.threatRadius,
        })
    end, false)

    panel:makeJobButton(250, y, 100, 24, IKST.text("IGUI_IKST_Cull", "Cull"), function()
        local p = panel.player
        IKST.dispatchCommand(p, IKST.CMD.threatCull, {
            x = math.floor(p:getX()),
            y = math.floor(p:getY()),
            z = p:getZ(),
            radius = panel.threatRadius,
        })
    end, true)

    y = y + 34
    local stats = IKST_JobThreat.stats
    local statsText = "Zombies: " .. tostring(stats.total) .. "  Sprinters: " .. tostring(stats.sprinters)
    local info = ISPanel:new(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 40)
    info.backgroundColor = IKST_Chrome.colors.bgCard
    info.borderColor = IKST_Chrome.colors.accentDim
    info:initialise()
    info.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        p:drawText(statsText, 8, 12, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
    end
    panel:addJobWidget(info)

    y = y + 48
    IKST_ActionLog.dock(panel, panel.player, y)
    return y
end

function IKST_JobThreat.onResult(args)
    if not args then
        return
    end
    if args.total then
        IKST_JobThreat.stats.total = args.total
        IKST_JobThreat.stats.sprinters = args.sprinters or 0
        local player = IKST.resolvePlayer()
        if player then
            IKST.notify(player, "Found " .. tostring(args.total) .. " zombies (" .. tostring(args.sprinters or 0) .. " sprinters)", true)
        end
    end
    if args.removed then
        if args.mirrorCull == true and IKST_Threat and IKST_Threat.cullAt
            and IKST.isRemoteClient and IKST.isRemoteClient() then
            local radius = IKST.clampRadius(args.radius or IKST.RADIUS_PRESETS.M)
            IKST_Threat.cullAt(args.x, args.y, args.z, radius, args.removed + 50)
        end
        IKST_JobThreat.stats.total = math.max(0, IKST_JobThreat.stats.total - args.removed)
        local player = IKST.resolvePlayer()
        if player then
            IKST.pushLog(player, "cull removed " .. tostring(args.removed))
            IKST.notify(player, "Removed " .. tostring(args.removed) .. " zombies", true)
        end
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
