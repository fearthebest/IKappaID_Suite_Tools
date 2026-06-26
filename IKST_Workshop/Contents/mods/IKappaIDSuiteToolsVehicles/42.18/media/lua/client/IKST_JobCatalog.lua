if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Catalog"
require "IKST_JobLayout"

IKST_JobCatalog = IKST_JobCatalog or {}

function IKST_JobCatalog.buildCategoryRow(panel, y, categories, activeId, onPick)
    if not categories or #categories == 0 then
        return y
    end
    if #categories > 8 then
        return IKST_JobCatalog.buildCategoryPicker(panel, y, categories, activeId, onPick)
    end
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Catalog_Category", "Category") .. ":", UIFont.Small)
    y = y + 18
    local x = 12
    for _, cat in ipairs(categories) do
        local label = cat.label or cat.id or "?"
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 18
        if w < 44 then
            w = 44
        end
        if x > IKST_JobLayout.MARGIN and x + w > IKST_JobLayout.contentRight(panel) then
            x = 12
            y = y + 26
        end
        panel:makeJobButton(x, y, w, 22, label, function()
            if onPick then
                onPick(cat.id)
            end
        end, activeId == cat.id)
        x = x + w + 4
    end
    return y + 28
end

function IKST_JobCatalog.buildCategoryPicker(panel, y, categories, activeId, onPick)
    local activeIndex = 1
    for i, cat in ipairs(categories) do
        if cat.id == activeId then
            activeIndex = i
            break
        end
    end
    local active = categories[activeIndex] or categories[1]
    local label = active and (active.label or active.id) or "?"

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Catalog_Category", "Category") .. ":", UIFont.Small)
    y = y + 18

    local prevLabel = IKST.text("IGUI_IKST_PagePrev", "Back")
    local nextLabel = IKST.text("IGUI_IKST_PageNext", "Next")
    local prevW = getTextManager():MeasureStringX(UIFont.Small, prevLabel) + 16
    local nextW = getTextManager():MeasureStringX(UIFont.Small, nextLabel) + 16
    if prevW < 44 then prevW = 44 end
    if nextW < 44 then nextW = 44 end

    panel:makeJobButton(12, y, prevW, 22, prevLabel, function()
        local idx = activeIndex - 1
        if idx < 1 then
            idx = #categories
        end
        if onPick and categories[idx] then
            onPick(categories[idx].id)
        end
    end, false)

    local centerW = IKST_JobLayout.clampWidth(panel, 12 + prevW + 8, panel.contentW or 280) - prevW - nextW - 16
    if centerW < 120 then
        centerW = 120
    end
    panel:makeJobButton(12 + prevW + 8, y, centerW, 22, label, function()
        if onPick and active then
            onPick(active.id)
        end
    end, true)

    panel:makeJobButton(12 + prevW + 8 + centerW + 8, y, nextW, 22, nextLabel, function()
        local idx = activeIndex + 1
        if idx > #categories then
            idx = 1
        end
        if onPick and categories[idx] then
            onPick(categories[idx].id)
        end
    end, false)

    return y + 28
end

function IKST_JobCatalog.truncationNote(shown, total)
    if total <= shown then
        return nil
    end
    return IKST.text("IGUI_IKST_Catalog_Truncated", "Showing first results — narrow category or search.")
        .. " (" .. tostring(shown) .. "/" .. tostring(total) .. ")"
end
