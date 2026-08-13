if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKST_Utility"
require "IKST_Access"
require "IKST_Grid"
require "IKST_JobsPanel"

IKST_ContextMenu = IKST_ContextMenu or {}

function IKST_ContextMenu.isPainterArmed(player)
    local state = IKST.getPlayerState(player)
    return state and state.armed and state.armedJob == IKST.VIEW.painter
end

function IKST_ContextMenu.openJob(player, view)
    IKST_JobsPanel.open(player)
    local panel = IKST_JobsPanel.instance
    if panel and view then
        panel:enterJob(view)
    end
end

function IKST_ContextMenu.addRootOption(context, label)
    if not context or not label then
        return nil
    end
    local walkTo = getText and getText("ContextMenu_Walk_to") or "Walk to"
    local root = nil
    if context.insertOptionBefore then
        root = context:insertOptionBefore(walkTo, label)
    end
    if not root and context.addOption then
        root = context:addOption(label)
    end
    if root then
        local iconTexture = getTexture and getTexture("media/ui/Panel_Icon_More.png")
        if iconTexture then
            root.iconTexture = iconTexture
            root.icon = nil
        end
    end
    return root
end

function IKST_ContextMenu.applyPainterAtSquare(player, square, mode)
    if not player or not square or not IKST_ContextMenu.isPainterArmed(player) then
        return
    end
    if IKST.ensurePaintCursor and not IKST.ensurePaintCursor() then
        return
    end
    if not IKST_PaintCursor then
        return
    end
    local cursor = IKST_PaintCursor:new(player, mode)
    cursor:create(square:getX(), square:getY(), square:getZ(), false, nil)
end

function IKST_ContextMenu.addArmedSquareOptions(player, context, square)
    if not player or not context or not square then
        return
    end

    if IKST_WorldPick and IKST_WorldPick.isCleanupArmed and IKST_WorldPick.isCleanupArmed(player) then
        local state = IKST.getPlayerState(player)
        local label = IKST.text("IGUI_IKST_Context_Apply", "Apply cleanup here")
        local action = IKST.getCleanupAction(state)
        if action == IKST.CLEANUP_MODES.removeTile then
            label = IKST.text("IGUI_IKST_Context_RemoveTile", "Remove tile here")
        elseif action == IKST.CLEANUP_MODES.vegetation then
            label = IKST.text("IGUI_IKST_Context_RemoveVeg", "Remove vegetation here")
        end
        context:addOption(label, player, function()
            if IKST_WorldPick.tryPickSquare then
                IKST_WorldPick.tryPickSquare(player, square, nil, nil)
            end
        end)
    end

    if IKST_WorldPick and IKST_WorldPick.isInspectorArmed and IKST_WorldPick.isInspectorArmed(player) then
        context:addOption(IKST.text("IGUI_IKST_Context_Inspect", "Inspect here"), player, function()
            if IKST_WorldPick.tryInspectSquare then
                IKST_WorldPick.tryInspectSquare(player, square, nil, nil)
            end
        end)
    end

    if IKST_ContextMenu.isPainterArmed(player) then
        local state = IKST.getPlayerState(player)
        local mode = state and state.painterMode or IKST.PAINTER_MODES.paint
        local label = IKST.text("IGUI_IKST_Context_PaintHere", "Paint here")
        if mode == IKST.PAINTER_MODES.eyedropper then
            label = IKST.text("IGUI_IKST_Context_PickSprite", "Pick sprite here")
        elseif mode == IKST.PAINTER_MODES.remove then
            label = IKST.text("IGUI_IKST_Context_RemoveTile", "Remove tile here")
        elseif mode == IKST.PAINTER_MODES.replace then
            label = IKST.text("IGUI_IKST_Context_ReplaceHere", "Replace tile here")
        end
        context:addOption(label, player, function()
            IKST_ContextMenu.applyPainterAtSquare(player, square, mode)
        end)
    end
end

function IKST_ContextMenu.fillUtilitySubMenu(sub, player)
    sub:addOption(IKST.utilityContextLabel("water"), player, function()
        if IKST.toggleUtilityForPlayer(player, "water") and IKST_JobsPanel and IKST_JobsPanel.instance then
            IKST_JobsPanel.instance:refreshJobUI()
        end
    end)
    sub:addOption(IKST.utilityContextLabel("power"), player, function()
        if IKST.toggleUtilityForPlayer(player, "power") and IKST_JobsPanel and IKST_JobsPanel.instance then
            IKST_JobsPanel.instance:refreshJobUI()
        end
    end)
end

function IKST_ContextMenu.fillJobSubMenu(sub, player)
    sub:addOption(IKST.text("IGUI_IKST_Context_OpenHub", "Open main menu"), player, function()
        IKST_ContextMenu.openJob(player, nil)
    end)
    sub:addOption(IKST.text("IGUI_IKST_Context_Toggle", "Show / hide panel"), player, function()
        IKST_JobsPanel.toggle(player)
    end)

    local function addCategoryOption(parent, catKey, catFallback, views)
        local catLabel = IKST.text(catKey, catFallback)
        local catOpt = parent:addOption(catLabel)
        local catSub = ISContextMenu:getNew(parent)
        parent:addSubMenu(catOpt, catSub)
        for _, entry in ipairs(views) do
            catSub:addOption(IKST.text(entry.key, entry.fallback), player, function()
                IKST_ContextMenu.openJob(player, entry.view)
            end)
        end
    end

    if IKST.Plugins and IKST.Plugins.isActive("tiles") then
        addCategoryOption(sub, "IGUI_IKST_Cat_World", "World", {
            { key = "IGUI_IKST_Job_Cleanup", fallback = "Remove Stuff", view = IKST.VIEW.cleanup },
            { key = "IGUI_IKST_Job_Painter", fallback = "Paint Tiles", view = IKST.VIEW.painter },
            { key = "IGUI_IKST_Job_Inspector", fallback = "Inspect Tile", view = IKST.VIEW.inspector },
        })
    end
    local dangerViews = {
        { key = "IGUI_IKST_Job_Threat", fallback = "Clear Zombies", view = IKST.VIEW.threat },
    }
    if IKST.Plugins and IKST.Plugins.isActive("vehicles") then
        table.insert(dangerViews, 1, { key = "IGUI_IKST_Job_Vehicle", fallback = "Cars & Trucks", view = IKST.VIEW.vehicle })
    end
    addCategoryOption(sub, "IGUI_IKST_Cat_Danger", "Cars & Zombies", dangerViews)
    local peopleViews = {
        { key = "IGUI_IKST_Job_Staff", fallback = "Player Tools", view = IKST.VIEW.staff },
    }
    if IKST.Plugins and IKST.Plugins.isActive("economy") then
        table.insert(peopleViews, { key = "IGUI_IKST_Job_Economy", fallback = "Economy", view = IKST.VIEW.economy })
    end
    addCategoryOption(sub, "IGUI_IKST_Cat_People", "You & Players", peopleViews)
    if IKST.Plugins and IKST.Plugins.isActive("loot") then
        addCategoryOption(sub, "IGUI_IKST_Cat_Loot", "Loot", {
            { key = "IGUI_IKST_Job_Loot", fallback = "Loot repopulate", view = IKST.VIEW.loot },
        })
    end
    local protectViews = {}
    if IKST.Plugins and IKST.Plugins.isActive("tiles") then
        table.insert(protectViews, { key = "IGUI_IKST_Job_Guard", fallback = "Rules & Protection", view = IKST.VIEW.guard })
        table.insert(protectViews, { key = "IGUI_IKST_Job_Automation", fallback = "Quick Area Jobs", view = IKST.VIEW.automation })
    end
    if #protectViews > 0 then
        addCategoryOption(sub, "IGUI_IKST_Cat_Protect", "Protect & Automate", protectViews)
    end

    local utilMenu = sub:addOption(IKST.text("IGUI_IKST_Context_Utilities", "Water & Power"))
    local utilSub = ISContextMenu:getNew(sub)
    sub:addSubMenu(utilMenu, utilSub)
    IKST_ContextMenu.fillUtilitySubMenu(utilSub, player)
end

function IKST_ContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not IKST_Access.canOpenPanel(player) or not context then
        return
    end

    if IKST_Access.canUseTools(player) then
        local square = IKST_Grid.squareFromWorldObjects(worldobjects)
        IKST_ContextMenu.addArmedSquareOptions(player, context, square)
    end

    local label = IKST.text("IGUI_IKST_Context_Root", "Suite Tools")
    local root = IKST_ContextMenu.addRootOption(context, label)
    if not root then
        return
    end
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    if IKST_Access.canUseTools(player) then
        IKST_ContextMenu.fillJobSubMenu(sub, player)
    else
        sub:addOption(IKST.text("IGUI_IKST_Context_OpenHub", "Open main menu"), player, function()
            IKST_ContextMenu.openJob(player, nil)
        end)
        sub:addOption(IKST.text("IGUI_IKST_Context_Toggle", "Show / hide panel"), player, function()
            IKST_JobsPanel.toggle(player)
        end)
    end
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_ContextMenu.onFillWorldObjectContextMenu)
end
