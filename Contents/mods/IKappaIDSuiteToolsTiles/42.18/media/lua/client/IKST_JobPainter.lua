if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
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
    if entry and entry.getText then
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

function IKST_JobPainter.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
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

    local y = 8
    local pick = state.currentPick
    local spriteLabel = pick and pick.sprite or IKST.text("IGUI_IKST_NoPick", "No sprite selected")

    local pickSprite = pick and pick.sprite or nil

    local info = ISPanel:new(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 40)
    info.backgroundColor = IKST_Chrome.colors.bgCard
    info.borderColor = IKST_Chrome.colors.accentDim
    info:initialise()
    info.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        p:drawText(spriteLabel, 8, 12, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
        if pickSprite then
            local tex = IKST_TileIndex and IKST_TileIndex.spriteTexture and IKST_TileIndex.spriteTexture(pickSprite)
            if not tex and getTexture then
                tex = getTexture(pickSprite)
            end
            if tex and tex.getWidth and tex.getHeight then
                local tw = tex:getWidth()
                local th = tex:getHeight()
                if tw > 0 and th > 0 then
                    local box = 32
                    local scale = math.min(box / tw, box / th)
                    local dw = math.floor(tw * scale)
                    local dh = math.floor(th * scale)
                    p:drawRectBorder(p.width - box - 8, 4, box, box, 0.8, cc.accentDim.r, cc.accentDim.g, cc.accentDim.b)
                    p:drawTextureScaled(
                        tex,
                        p.width - box - 8 + math.floor((box - dw) / 2),
                        4 + math.floor((box - dh) / 2),
                        dw, dh,
                        1, 1, 1, 1
                    )
                end
            end
        end
    end
    panel:addJobWidget(info)
    y = y + 48

    local modes = {
        { id = IKST.PAINTER_MODES.eyedropper, label = IKST.text("IGUI_IKST_Eyedropper", "Eyedropper") },
        { id = IKST.PAINTER_MODES.paint, label = IKST.text("IGUI_IKST_Paint", "Paint") },
        { id = IKST.PAINTER_MODES.remove, label = IKST.text("IGUI_IKST_Remove", "Remove") },
        { id = IKST.PAINTER_MODES.replace, label = IKST.text("IGUI_IKST_Replace", "Replace") },
    }
    local x = 12
    for _, m in ipairs(modes) do
        panel:makeJobButton(x, y, 90, 24, m.label, function()
            IKST_PaintCursorManager.arm(panel.player, m.id)
            panel:refreshJobUI()
        end, state.painterMode == m.id and state.armed and state.armedJob == IKST.VIEW.painter)
        x = x + 96
    end
    y = y + 32

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_PackFilter", "Pack filter"), UIFont.Small)
    y = y + 16
    panel.packFilterEntry = ISTextEntryBox:new(panel.packFilter, 12, y, 180, 22)
    panel.packFilterEntry:initialise()
    panel.packFilterEntry:instantiate()
    panel:addJobWidget(panel.packFilterEntry)

    panel:makeJobButton(200, y, 100, 22, IKST.text("IGUI_IKST_ListPacks", "List packs"), function()
        IKST_JobPainter.listPacks(panel)
        panel:refreshJobUI()
    end, false)
    panel:makeJobButton(306, y, 70, 22, "<", function()
        panel.packPage = math.max(1, (panel.packPage or 1) - 1)
        panel:refreshJobUI()
    end, false)
    panel:makeJobButton(380, y, 70, 22, ">", function()
        local pages = math.max(1, math.ceil(#(panel.packNames or {}) / 4))
        panel.packPage = math.min(pages, (panel.packPage or 1) + 1)
        panel:refreshJobUI()
    end, false)
    y = y + 28

    local names = panel.packNames or {}
    local pageStart = ((panel.packPage or 1) - 1) * 4 + 1
    for i = pageStart, math.min(pageStart + 3, #names) do
        local name = names[i]
        local short = string.sub(name, 1, 18)
        panel:makeJobButton(12 + (i - pageStart) * 122, y, 118, 22, short, function()
            panel.selectedPack = name
            panel:refreshJobUI()
        end, panel.selectedPack == name)
    end
    y = y + 28

    panel:makeJobButton(12, y, 120, 22, IKST.text("IGUI_IKST_LoadPack", "Load pack"), function()
        IKST_JobPainter.loadSelectedPack(panel)
        panel:refreshJobUI()
    end, true)
    if panel.selectedPack then
        local count = panel.packSprites and #panel.packSprites or 0
        panel:makeJobLabel(140, y + 4, panel.selectedPack .. " (" .. count .. ")", UIFont.Small)
    end
    y = y + 28

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SpriteFilter", "Sprite filter"), UIFont.Small)
    y = y + 16
    panel.spriteFilterEntry = ISTextEntryBox:new(panel.spriteFilter, 12, y, 220, 22)
    panel.spriteFilterEntry:initialise()
    panel.spriteFilterEntry:instantiate()
    panel:addJobWidget(panel.spriteFilterEntry)
    panel:makeJobButton(240, y, 90, 22, IKST.text("IGUI_IKST_ApplyFilter", "Filter"), function()
        panel.spriteFilter = IKST_JobPainter.readEntryText(panel.spriteFilterEntry)
        panel.spriteGridPage = 1
        panel:refreshJobUI()
    end, false)
    panel:makeJobButton(336, y, 100, 22, IKST.text("IGUI_IKST_UseSprite", "Use sprite"), function()
        local name = IKST_JobPainter.readEntryText(panel.spriteFilterEntry)
        if name == "" and pick and pick.sprite then
            name = pick.sprite
        end
        IKST_JobPainter.tryManualSprite(panel, name)
    end, false)
    y = y + 28

    local gridH = math.max(60, panel.height - y - 130)
    local sprites = IKST_JobPainter.getGridSprites(panel)
    local grid = IKST_SpriteGrid:new(12, y, panel.width - 24, gridH, sprites, function(sprite)
        IKST_JobPainter.onSpritePicked(panel, sprite)
    end)
    grid.page = panel.spriteGridPage
    grid:initialise()
    panel:addJobWidget(grid)
    y = y + gridH + 4

    if #sprites > grid.perPage then
        panel:makeJobButton(12, y, 60, 22, IKST.text("IGUI_IKST_PagePrev", "Prev"), function()
            panel.spriteGridPage = math.max(1, (panel.spriteGridPage or 1) - 1)
            panel:refreshJobUI()
        end, false)
        panel:makeJobButton(78, y, 60, 22, IKST.text("IGUI_IKST_PageNext", "Next"), function()
            local pages = math.max(1, math.ceil(#sprites / 48))
            panel.spriteGridPage = math.min(pages, (panel.spriteGridPage or 1) + 1)
            panel:refreshJobUI()
        end, false)
        y = y + 26
    end

    panel:makeJobButton(12, y, 84, 22, IKST.text("IGUI_IKST_Disarm", "DISARM"), function()
        IKST_PaintCursorManager.disarm(panel.player)
        panel:refreshJobUI()
    end, false)

    if pick and pick.sprite then
        panel:makeJobButton(IKST_JobLayout.contentRight(panel) - 100, 8, 100, 22, IKST.text("IGUI_IKST_Favorite", "Favorite"), function()
            table.insert(state.favorites, 1, pick)
            IKST.notify(panel.player, IKST.text("IGUI_IKST_Favorited", "Added to favorites"), true)
        end, false)
    end

    IKST_ActionLog.dock(panel, panel.player, y + 8)
    return y + 8
end
