if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_UI_Layout"
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

function IKST_JobPainter.spritePageCount(panel)
    local sprites = IKST_JobPainter.getGridSprites(panel)
    local per = math.max(1, tonumber(panel._spriteGridPerPage) or 8)
    if #sprites < 1 then
        return 1
    end
    return math.max(1, math.ceil(#sprites / per))
end

function IKST_JobPainter.shiftSpritePage(panel, delta)
    local pages = IKST_JobPainter.spritePageCount(panel)
    local page = (panel.spriteGridPage or 1) + (tonumber(delta) or 0)
    if page < 1 then
        page = 1
    elseif page > pages then
        page = pages
    end
    panel.spriteGridPage = page
    panel:refreshJobUI()
end

function IKST_JobPainter.packPageCount(panel)
    local names = panel.packNames or {}
    if #names < 1 then
        return 1
    end
    return math.max(1, math.ceil(#names / 4))
end

function IKST_JobPainter.shiftPackPage(panel, delta)
    local pages = IKST_JobPainter.packPageCount(panel)
    local page = (panel.packPage or 1) + (tonumber(delta) or 0)
    if page < 1 then
        page = 1
    elseif page > pages then
        page = pages
    end
    panel.packPage = page
    panel:refreshJobUI()
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
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.buildPaint) == "function" then
        return IKST_SoftTool_Tiles.buildPaint(panel)
    end
    local state = IKST_JobPainter.ensureState(panel)
    if not state then
        return 8
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    -- Soft-only: Modes | Pack (flex) | Search — Pack gets leftover height.
    local L = IKST_UI_Layout
    local page = L.box(rect.x, rect.y, rect.w, rect.h)
    local searchH = IKST_JobLayout.fieldActionBandH(1)
    local modeH = IKST_JobLayout.compactPillBandH(2)
    local bands = L.columnIn(page, {
        { h = modeH },
        { flex = 1 },
        { h = searchH },
    }, { gap = gap, pad = 0 })
    local stackBottom = rect.y + rect.h
    local soft = true
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local bx = band.x or rect.x
        local bw = band.w or rect.w
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, bx, band.y, bw, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, bw - inner * 2)
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
        local L = IKST_UI_Layout
        local area = L.box(ax, ay, aw, ah)
        local btnWStd, btnHStd = IKST_JobLayout.standardPillSize(panel, aw)
        local names = panel.packNames or {}
        local pageStart = ((panel.packPage or 1) - 1) * 4 + 1
        local packItems = {}
        for i = pageStart, math.min(pageStart + 3, #names) do
            local name = names[i]
            packItems[#packItems + 1] = {
                label = string.sub(name, 1, 18),
                primary = panel.selectedPack == name,
                onClick = function()
                    panel.selectedPack = name
                    panel.spriteGridPage = 1
                    IKST_JobPainter.loadSelectedPack(panel)
                    panel:refreshJobUI()
                end,
            }
        end
        local packH = btnHStd
        if #packItems > 0 then
            local _, _, _, pgH = IKST_JobLayout.pillGridMetrics(aw, #packItems, btnWStd, btnHStd)
            packH = math.max(btnHStd, pgH)
        end
        local _, _, _, actListH = IKST_JobLayout.pillGridMetrics(aw, 2, btnWStd, btnHStd)
        actListH = math.max(btnHStd, actListH)
        local _, _, _, actPackNavH = IKST_JobLayout.pillGridMetrics(aw, 3, btnWStd, btnHStd)
        actPackNavH = math.max(btnHStd, actPackNavH)
        local _, _, _, actTileNavH = IKST_JobLayout.pillGridMetrics(aw, 3, btnWStd, btnHStd)
        actTileNavH = math.max(btnHStd, actTileNavH)
        local labelH = 16
        local slotGap = 6
        local fixedGaps = slotGap * 5
        local budget = math.max(btnHStd * 4, ah - labelH - fixedGaps)
        local fixedActs = actListH + actPackNavH + actTileNavH
        if packH + fixedActs > budget then
            actListH = math.min(actListH, math.max(btnHStd, budget - btnHStd * 3))
            actPackNavH = math.min(actPackNavH, math.max(btnHStd, budget - actListH - btnHStd * 2))
            actTileNavH = math.min(actTileNavH, math.max(btnHStd, budget - actListH - actPackNavH - btnHStd))
            packH = math.max(btnHStd, budget - actListH - actPackNavH - actTileNavH)
        end
        local slots = L.columnIn(area, {
            { h = labelH },
            { h = packH },
            { h = actListH },
            { h = actPackNavH },
            { h = actTileNavH },
            { flex = 1 },
        }, { gap = slotGap, pad = 0 })

        local pickLabel = pick and pick.sprite or IKST.text("IGUI_IKST_NoPick", "No sprite selected")
        local info = ISLabel:new(slots[1].x, slots[1].y, labelH, pickLabel, 1, 1, 1, 1, UIFont.Small, true)
        info:initialise()
        card:addChild(info)

        if #packItems > 0 and slots[2] and L.contains(area, slots[2]) then
            IKST_JobLayout.placePillGroup(panel, card, slots[2].x, slots[2].y, slots[2].w, slots[2].h, packItems)
        end

        if slots[3] and L.contains(area, slots[3]) then
            IKST_JobLayout.placePillGroup(panel, card, slots[3].x, slots[3].y, slots[3].w, slots[3].h, {
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
            })
        end

        if slots[4] and L.contains(area, slots[4]) then
            local packPage = panel.packPage or 1
            local packPages = IKST_JobPainter.packPageCount(panel)
            IKST_JobLayout.placeNavPillGroup(panel, card, slots[4].x, slots[4].y, slots[4].w, slots[4].h, {
                {
                    label = IKST.text("IGUI_IKST_PackPrev", "<"),
                    onClick = function()
                        IKST_JobPainter.shiftPackPage(panel, -1)
                    end,
                },
                {
                    label = string.format("%d / %d", packPage, packPages),
                    primary = "chip",
                    onClick = function()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_PackNext", ">"),
                    onClick = function()
                        IKST_JobPainter.shiftPackPage(panel, 1)
                    end,
                },
            })
        end

        if slots[5] and L.contains(area, slots[5]) then
            -- Estimate tiles/page from the grid slot before the grid exists (for the page label).
            if slots[6] and slots[6].h >= 36 then
                local cols = math.max(1, math.floor((slots[6].w - 4) / 52))
                local rows = math.max(1, math.floor((slots[6].h - 20) / 52))
                panel._spriteGridPerPage = cols * rows
            end
            local tilePage = panel.spriteGridPage or 1
            local tilePages = IKST_JobPainter.spritePageCount(panel)
            IKST_JobLayout.placeNavPillGroup(panel, card, slots[5].x, slots[5].y, slots[5].w, slots[5].h, {
                {
                    label = IKST.text("IGUI_IKST_TilesPrev", "<"),
                    onClick = function()
                        IKST_JobPainter.shiftSpritePage(panel, -1)
                    end,
                },
                {
                    label = string.format("%d / %d", tilePage, tilePages),
                    primary = "chip",
                    onClick = function()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_TilesNext", ">"),
                    onClick = function()
                        IKST_JobPainter.shiftSpritePage(panel, 1)
                    end,
                },
            })
        end

        if slots[6] and slots[6].h >= 36 and L.contains(area, slots[6]) then
            local sprites = IKST_JobPainter.getGridSprites(panel)
            local grid = IKST_SpriteGrid:new(slots[6].x, slots[6].y, slots[6].w, slots[6].h, sprites, function(sprite)
                IKST_JobPainter.onSpritePicked(panel, sprite)
            end)
            if type(grid.layoutMetrics) == "function" then
                grid:layoutMetrics()
            end
            panel._spriteGridPerPage = math.max(1, grid.perPage or 8)
            local pages = math.max(1, math.ceil(math.max(1, #sprites) / panel._spriteGridPerPage))
            if (panel.spriteGridPage or 1) > pages then
                panel.spriteGridPage = pages
            end
            grid.page = panel.spriteGridPage or 1
            grid.onPageChange = function(page)
                panel.spriteGridPage = page
            end
            if grid.clipping ~= nil then
                grid.clipping = true
            end
            grid:initialise()
            if type(grid.layoutMetrics) == "function" then
                grid:layoutMetrics()
            end
            IKST_JobLayout.attachToolWidget(panel, card, grid)
            -- Soft host steals wheel for page scroll; register grid so tile pages advance under the cursor.
            panel._ikstSelectLists = panel._ikstSelectLists or {}
            panel._ikstSelectLists[#panel._ikstSelectLists + 1] = grid
        end
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
    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end
