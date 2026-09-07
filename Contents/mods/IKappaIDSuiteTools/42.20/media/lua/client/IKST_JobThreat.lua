if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_JobLayout"
require "IKST_Threat"

IKST_JobThreat = IKST_JobThreat or {}
IKST_JobThreat.stats = { total = 0, sprinters = 0 }

function IKST_JobThreat.build(panel)
    if IKST_SoftTool_Utilities and type(IKST_SoftTool_Utilities.buildZombies) == "function" then
        return IKST_SoftTool_Utilities.buildZombies(panel)
    end
    if not panel.threatRadius then
        panel.threatRadius = IKST.RADIUS_PRESETS.M
    end

    local p = panel.player
    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands, stackBottom, soft = IKST_JobLayout.toolBands(panel, rect, 2, gap, { 1, 2 })
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_SectionScope", "Scope"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Scope_Radius", "Radius") .. " " .. tostring(panel.threatRadius),
                onClick = function()
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
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Scan", "Scan"),
                onClick = function()
                    if not p then
                        return
                    end
                    IKST_Threat.applyClientPreview(p:getX(), p:getY(), p:getZ(), panel.threatRadius, "warn")
                    IKST.dispatchCommand(p, IKST.CMD.threatPopulation, {
                        x = math.floor(p:getX()),
                        y = math.floor(p:getY()),
                        z = p:getZ(),
                        radius = panel.threatRadius,
                    })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Cull", "Cull"),
                primary = true,
                onClick = function()
                    if not p then
                        return
                    end
                    IKST_Threat.applyClientPreview(p:getX(), p:getY(), p:getZ(), panel.threatRadius, "warn")
                    IKST.dispatchCommand(p, IKST.CMD.threatCull, {
                        x = math.floor(p:getX()),
                        y = math.floor(p:getY()),
                        z = p:getZ(),
                        radius = panel.threatRadius,
                    })
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_SectionPopulation", "Population"))
        local stats = IKST_JobThreat.stats
        local statsText = "Zombies: " .. tostring(stats.total) .. "  Sprinters: " .. tostring(stats.sprinters)
        local affects = ""
        if IKST_Threat and type(IKST_Threat.affectsLabel) == "function" then
            affects = IKST_Threat.affectsLabel(panel.threatRadius)
        end
        local lineH = 16
        local note = ISLabel:new(ax, ay, lineH, statsText, 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        card:addChild(note)
        if affects ~= "" then
            local note2 = ISLabel:new(ax, ay + lineH + 4, lineH, affects, 1, 1, 1, 1, UIFont.Small, true)
            note2:initialise()
            card:addChild(note2)
        end
    end

    if p then
        IKST_Threat.applyClientPreview(p:getX(), p:getY(), p:getZ(), panel.threatRadius, "warn")
    end

    panel._ikstToolFit = true
    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
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
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end
