if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_TileIndex"
require "IKST_SpriteGrid"
require "IKST_JobLayout"

IKST_JobPainter = IKST_JobPainter or {}

function IKST_JobPainter.onSpritePicked(panel, sprite)
    IKST_PaintCursorManager.setPick(panel.player, sprite)
    IKST_PaintCursorManager.arm(panel.player, IKST.PAINTER_MODES.paint)
    panel:refreshJobUI()
end

function IKST_JobPainter.trim(text)
    return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

function IKST_JobPainter.readEntryText(entry)
    if entry and type(entry.getText) == "function" then
        return IKST_JobPainter.trim(entry:getText())
    end
    return ""
end

function IKST_JobPainter.tryManualSprite(panel, spriteName)
    spriteName = IKST_JobPainter.trim(spriteName)
    if spriteName == "" then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_NoPick", "No sprite selected"), false)
        return
    end
    if not IKST_TileIndex.isValidSprite(spriteName) then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_SpriteNotFound", "Sprite not loaded") .. ": " .. spriteName, false)
        return
    end
    IKST_JobPainter.onSpritePicked(panel, spriteName)
end

function IKST_JobPainter.listPacks(panel)
    panel.packFilter = IKST_JobPainter.readEntryText(panel.packFilterEntry)
    panel.packNames = IKST_TileIndex.filterPacks(panel.packFilter)
    panel.packPage = 1
    if not panel.selectedPack and panel.packNames[1] then
        panel.selectedPack = panel.packNames[1]
    end
end

function IKST_JobPainter.loadSelectedPack(panel)
    if not panel.selectedPack then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_SelectPack", "Select a pack first"), false)
        return
    end
    panel.packSprites = IKST_TileIndex.scanPack(panel.selectedPack)
    panel.spriteGridPage = 1
end

function IKST_JobPainter.getGridSprites(panel)
    local sprites = panel.packSprites or {}
    panel.spriteFilter = IKST_JobPainter.readEntryText(panel.spriteFilterEntry)
    return IKST_TileIndex.filterSpriteList(sprites, panel.spriteFilter)
end

function IKST_JobPainter.ensureState(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return nil
    end
    if not panel.packNames then
        panel.packNames = IKST_TileIndex.getPackNames()
    end
    if not panel.selectedPack then
        for _, name in ipairs(panel.packNames) do
            if name == "ikst_suite" then
                panel.selectedPack = name
                break
            end
        end
        if not panel.selectedPack and panel.packNames[1] then
            panel.selectedPack = panel.packNames[1]
        end
    end
    if panel.selectedPack == "ikst_suite" and (not panel.packSprites or #panel.packSprites == 0) then
        panel.packSprites = IKST_TileIndex.scanPack("ikst_suite")
    end
    if not panel.packPage then
        panel.packPage = 1
    end
    if not panel.packFilter then
        panel.packFilter = ""
    end
    if not panel.spriteFilter then
        panel.spriteFilter = ""
    end
    if not panel.spriteGridPage then
        panel.spriteGridPage = 1
    end
    return state
end

function IKST_JobPainter.build(panel)
    local state = IKST_JobPainter.ensureState(panel)
    if not state then
        return 8
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 3, gap)
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

    local pick = state.currentPick
    local painterArmed = state.armed and state.armedJob == IKST.VIEW.painter

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_SectionModes", "Modes"))
        local modes = {
            { id = IKST.PAINTER_MODES.eyedropper, label = IKST.text("IGUI_IKST_Eyedropper", "Eyedropper") },
            { id = IKST.PAINTER_MODES.paint, label = IKST.text("IGUI_IKST_Paint", "Paint"), primary = true },
            { id = IKST.PAINTER_MODES.wall, label = IKST.text("IGUI_IKST_TilesTile_PaintWall", "Paint wall") },
            { id = IKST.PAINTER_MODES.remove, label = IKST.text("IGUI_IKST_Remove", "Remove") },
            { id = IKST.PAINTER_MODES.replace, label = IKST.text("IGUI_IKST_Replace", "Replace tile") },
        }
        local items = {}
        for i = 1, #modes do
            local m = modes[i]
            items[#items + 1] = {
                label = m.label,
                primary = painterArmed and state.painterMode == m.id,
                onClick = function()
                    if IKST_PaintCursorManager and type(IKST_PaintCursorManager.arm) == "function" then
                        IKST_PaintCursorManager.arm(panel.player, m.id)
                    end
                    panel:refreshJobUI()
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_SectionPack", "Pack"))
        local btnWStd = select(1, IKST_JobLayout.standardPillSize(panel))
        local _, navRows, _, navGridH = IKST_JobLayout.pillGridMetrics(aw, 4, btnWStd, btnH)
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, math.max(1, navRows))
        local pillY = ay + listH + gapLP
        local pillAreaH = math.max(btnH, pillH, navGridH)

        local pickLabel = pick and pick.sprite or IKST.text("IGUI_IKST_NoPick", "No sprite selected")
        local info = ISLabel:new(ax, ay, 16, pickLabel, 1, 1, 1, 1, UIFont.Small, true)
        info:initialise()
        card:addChild(info)

        local names = panel.packNames or {}
        local pageStart = ((panel.packPage or 1) - 1) * 4 + 1
        local packItems = {}
        for i = pageStart, math.min(pageStart + 3, #names) do
            local name = names[i]
            local short = string.sub(name, 1, 18)
            packItems[#packItems + 1] = {
                label = short,
                primary = panel.selectedPack == name,
                onClick = function()
                    panel.selectedPack = name
                    panel:refreshJobUI()
                end,
            }
        end
        local packRowH = 0
        if #packItems > 0 then
            local _, pr, _, pgH = IKST_JobLayout.pillGridMetrics(aw, #packItems, btnWStd, btnH)
            packRowH = pgH
            IKST_JobLayout.placePillGroup(panel, card, ax, ay + 18, aw, packRowH, packItems)
        end

        local gridTop = ay + 18 + packRowH + (packRowH > 0 and 6 or 0)
        local gridH = math.max(36, listH - (gridTop - ay))
        if gridTop + gridH > ay + listH then
            gridH = math.max(36, ay + listH - gridTop)
        end
        local sprites = IKST_JobPainter.getGridSprites(panel)
        local grid = IKST_SpriteGrid:new(ax, gridTop, aw, gridH, sprites, function(sprite)
            IKST_JobPainter.onSpritePicked(panel, sprite)
        end)
        grid.page = panel.spriteGridPage
        grid:initialise()
        IKST_JobLayout.attachToolWidget(panel, card, grid)

        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_ListPacks", "List packs"),
                onClick = function()
                    IKST_JobPainter.listPacks(panel)
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LoadPack", "Load"),
                primary = true,
                onClick = function()
                    IKST_JobPainter.loadSelectedPack(panel)
                    panel:refreshJobUI()
                end,
            },
            {
                label = "<",
                onClick = function()
                    panel.packPage = math.max(1, (panel.packPage or 1) - 1)
                    panel:refreshJobUI()
                end,
            },
            {
                label = ">",
                onClick = function()
                    local pages = math.max(1, math.ceil(#(panel.packNames or {}) / 4))
                    panel.packPage = math.min(pages, (panel.packPage or 1) + 1)
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_SpriteFilter", "Sprite"))
        local defaultText = panel.spriteFilter or ""
        if defaultText == "" and pick and pick.sprite then
            defaultText = pick.sprite
        end
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = defaultText, fieldName = "spriteFilterEntry" },
        }, IKST.text("IGUI_IKST_UseSprite", "Use sprite"), function()
            local name = IKST_JobPainter.readEntryText(panel.spriteFilterEntry)
            if name == "" and pick and pick.sprite then
                name = pick.sprite
            end
            IKST_JobPainter.tryManualSprite(panel, name)
        end)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end
