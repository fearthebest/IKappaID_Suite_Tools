-- Floating soft hub — owns IKUI_Shell instance and page registry (MODULE-MAP).
-- Dark grey + orange via IKappaID_UI. Feature pages in IKST_Page*; Job* builds via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Plugins"
require "IKST_HubNav"
require "IKappaID_UI_Framework/IKUI_Shell"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_SoftPageHost"
require "IKST_PageHome"
require "IKST_PageUtilities"
require "IKST_PageClaim"
require "IKST_PageEveryone"
require "IKST_PageAdmin"
require "IKST_PageTiles"
require "IKST_PageVehicles"
require "IKST_PageEconomy"
require "IKST_PageLoot"

IKST_Hub = IKST_Hub or {}
IKST_Hub._pagesReady = false

local PAGE_DEFS = {
    {
        id = "home",
        labelKey = "IGUI_IKST_Home",
        label = "Home",
        area = "home",
        create = function(window, x, y, w, h)
            return IKST_PageHome.create(window, x, y, w, h)
        end,
    },
    {
        id = "everyone",
        labelKey = "IGUI_IKST_WS_Everyone",
        label = "Everyone",
        area = "everyone",
        create = function(window, x, y, w, h)
            return IKST_PageEveryone.create(window, x, y, w, h)
        end,
    },
    {
        id = "claim",
        labelKey = "IGUI_IKST_WS_Claim",
        label = "Claim",
        area = "claim",
        create = function(window, x, y, w, h)
            return IKST_PageClaim.create(window, x, y, w, h)
        end,
    },
    {
        id = "utilities",
        labelKey = "IGUI_IKST_WS_Utilities",
        label = "Utilities",
        area = "utilities",
        create = function(window, x, y, w, h)
            return IKST_PageUtilities.create(window, x, y, w, h)
        end,
    },
    {
        id = "tiles",
        labelKey = "IGUI_IKST_WS_World",
        label = "Tiles",
        area = "tiles",
        pluginId = "tiles",
        create = function(window, x, y, w, h)
            return IKST_PageTiles.create(window, x, y, w, h)
        end,
    },
    {
        id = "vehicles",
        labelKey = "IGUI_IKST_WS_Vehicles",
        label = "Vehicles",
        area = "vehicles",
        pluginId = "vehicles",
        create = function(window, x, y, w, h)
            return IKST_PageVehicles.create(window, x, y, w, h)
        end,
    },
    {
        id = "economy",
        labelKey = "IGUI_IKST_WS_Economy",
        label = "Economy",
        area = "economy",
        pluginId = "economy",
        create = function(window, x, y, w, h)
            return IKST_PageEconomy.create(window, x, y, w, h)
        end,
    },
    {
        id = "loot",
        labelKey = "IGUI_IKST_WS_Loot",
        label = "Loot",
        area = "loot",
        pluginId = "loot",
        create = function(window, x, y, w, h)
            return IKST_PageLoot.create(window, x, y, w, h)
        end,
    },
    {
        id = "admin",
        labelKey = "IGUI_IKST_WS_Admin",
        label = "Admin",
        area = "admin",
        pluginId = "admin",
        create = function(window, x, y, w, h)
            return IKST_PageAdmin.create(window, x, y, w, h)
        end,
    },
}

local function pageVisible(def, player)
    if not def then
        return false
    end
    if def.id == "home" or def.area == "home" then
        return true
    end
    if def.pluginId and IKST.Plugins and type(IKST.Plugins.isActive) == "function"
        and not IKST.Plugins.isActive(def.pluginId) then
        return false
    end
    if def.area and IKST_Access and type(IKST_Access.canUseWorkspace) == "function" then
        return IKST_Access.canUseWorkspace(player, def.area) == true
    end
    return true
end

function IKST_Hub.ensurePages()
    if IKST_Hub._pagesReady then
        return
    end
    if type(IKUI_Shell.clearPages) == "function" then
        IKUI_Shell.clearPages()
    end
    for i = 1, #PAGE_DEFS do
        local def = PAGE_DEFS[i]
        local label = IKST.text(def.labelKey, def.label)
        IKUI_Shell.registerPage({
            id = def.id,
            label = label,
            area = def.area or def.id,
            create = def.create,
            hidden = false,
        })
    end
    -- Addon Registers may declare hubPages = { { id, label, create, area?, pluginId? }, ... }
    if IKST.Plugins and type(IKST.Plugins.all) == "function" then
        local all = IKST.Plugins.all()
        if type(all) == "table" then
            for pluginId, spec in pairs(all) do
                if type(spec) == "table" and type(spec.hubPages) == "table" then
                    for _, hp in ipairs(spec.hubPages) do
                        if type(hp) == "table" and type(hp.id) == "string" and type(hp.create) == "function" then
                            IKUI_Shell.registerPage({
                                id = hp.id,
                                label = IKST.text(hp.labelKey, hp.label or hp.id),
                                area = hp.area or hp.id,
                                create = hp.create,
                                designH = hp.designH,
                            })
                        end
                    end
                end
            end
        end
    end
    IKST_Hub._pagesReady = true
end

local function syncHubSatellites(player)
    if IKST_HudChip and type(IKST_HudChip.sync) == "function" then
        IKST_HudChip.sync(player)
    end
end

local function hubUiList()
    if not UIManager or type(UIManager.getUI) ~= "function" then
        return nil
    end
    return UIManager:getUI()
end

function IKST_Hub.teardownPages(win)
    if not win or not win.pagePanels then
        return
    end
    for _, page in pairs(win.pagePanels) do
        if page and type(page.clearJobLayer) == "function" then
            page:clearJobLayer()
        end
        if page and type(page.clearHomeWidgets) == "function" then
            page:clearHomeWidgets()
        end
    end
end

function IKST_Hub.purgeStrayUi()
    local shell = IKUI_Shell and IKUI_Shell.instance

    local function underShell(el)
        if not el or not shell then
            return false
        end
        local node = el
        while node do
            if node == shell then
                return true
            end
            node = node.parent
        end
        return false
    end

    local function underAllowedHost(el)
        if underShell(el) then
            return true
        end
        local mini = IKUI_MiniBar and IKUI_MiniBar.instance
        if mini then
            local node = el
            while node do
                if node == mini then
                    return true
                end
                node = node.parent
            end
        end
        return false
    end

    local function isStrayIkstWidget(el)
        if not el then
            return false
        end
        if el._ikstHubSatellite == true then
            return true
        end
        if el.Type == "IKUI_Button" then
            return true
        end
        if el._ikstQuickEntry then
            return true
        end
        if el._ikuiTitle and el._ikuiOnClick then
            return true
        end
        return false
    end

    local list = hubUiList()
    if list and type(list.size) == "function" then
        for i = list:size() - 1, 0, -1 do
            local el = list:get(i)
            if el and isStrayIkstWidget(el) and not underAllowedHost(el) then
                if IKUI_Chrome and type(IKUI_Chrome.hideTooltip) == "function" then
                    IKUI_Chrome.hideTooltip(el)
                end
                if type(el.setVisible) == "function" then
                    el:setVisible(false)
                end
                if type(el.removeFromUIManager) == "function" then
                    el:removeFromUIManager()
                end
            end
        end
    end
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.purgeOrphans) == "function" then
        IKST_ActionLogWindow.purgeOrphans()
    end
end

local function bindShell(win, player)
    if not win then
        return
    end
    win.player = player
    win.canSee = function(_self, area)
        if not area or area == "home" then
            return true
        end
        for i = 1, #PAGE_DEFS do
            local def = PAGE_DEFS[i]
            if def.area == area or def.id == area then
                return pageVisible(def, player)
            end
        end
        if IKST_Access and type(IKST_Access.canUseWorkspace) == "function" then
            return IKST_Access.canUseWorkspace(player, area) == true
        end
        return true
    end
    -- Sidebar page click always binds navMode/navTool to that page (never leave stale tiles/protect).
    win.onPageChanged = function(_win, pageId)
        if not pageId or pageId == "home" then
            return
        end
        if not player or not IKST_HubNav or type(IKST_HubNav.applyNav) ~= "function" then
            return
        end
        local state = IKST.getPlayerState(player)
        if not state then
            return
        end
        local tool = nil
        if state.navMode == pageId and state.navTool then
            local tools = IKST_HubNav.toolsForWorkspace(pageId, player)
            for i = 1, #tools do
                if tools[i].id == state.navTool then
                    tool = state.navTool
                    break
                end
            end
        end
        if not tool and type(IKST_HubNav.defaultTool) == "function" then
            tool = IKST_HubNav.defaultTool(pageId)
        end
        IKST_HubNav.applyNav(state, pageId, tool)
    end
    win.onClosed = function(_win)
        IKST_Hub.disarmWorldTools(player)
        IKST_Hub.teardownPages(_win)
        if IKST_ActionLogWindow and type(IKST_ActionLogWindow.close) == "function" then
            IKST_ActionLogWindow.close()
        end
        IKST_Hub.purgeStrayUi()
        if IKST_HudChip and type(IKST_HudChip.sync) == "function" then
            IKST_HudChip.sync(player)
        end
    end
    win.onMinimized = function(_win)
        if IKST_ActionLogWindow and type(IKST_ActionLogWindow.close) == "function" then
            IKST_ActionLogWindow.close()
        end
        if IKST_HudChip and type(IKST_HudChip.sync) == "function" then
            IKST_HudChip.sync(player)
        end
    end
    win.onRestored = function(_win)
        local p = _win.player or player
        if p then
            syncHubSatellites(p)
        end
    end
end

function IKST_Hub.switchWorkspace(workspaceId, toolId)
    local win = IKUI_Shell.instance
    if not win then
        return
    end
    local pageId = workspaceId
    if pageId == IKST.VIEW.favorites or pageId == IKST.VIEW.hub then
        pageId = "home"
    end
    local player = win.player
    if player and IKST_HubNav and type(IKST_HubNav.applyNav) == "function" then
        local state = IKST.getPlayerState(player)
        if state then
            local tool = toolId
            if tool == nil and IKST_HubNav.defaultTool then
                tool = IKST_HubNav.defaultTool(workspaceId)
            end
            IKST_HubNav.applyNav(state, workspaceId, tool)
        end
    end
    if type(win.switchPage) == "function" then
        win:switchPage(pageId)
    end
    local inner = win:page(pageId)
    if inner and type(inner.refreshJobUI) == "function" then
        inner:refreshJobUI()
    elseif inner and type(inner.onShow) == "function" then
        inner:onShow()
    end
end

-- Open soft hub and optionally jump to a workspace/tool (replaces JobsPanel.enterJob).
function IKST_Hub.openWorkspace(player, workspaceId, toolId)
    local win = IKST_Hub.open(player)
    if win and workspaceId then
        IKST_Hub.switchWorkspace(workspaceId, toolId)
    end
    return win
end

function IKST_Hub.open(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canOpenPanel(player) then
        return nil
    end
    IKST_Hub.purgeStrayUi()
    IKST_Hub.ensurePages()
    if IKST_EdgeDock and type(IKST_EdgeDock.hide) == "function" then
        IKST_EdgeDock.hide()
    end
    local win = IKUI_Shell.open({
        title = IKST.text("IGUI_IKST_HubTitle", "IKappaID Suite Tools"),
        subtitle = "",
        prefsPrefix = "ikst.hub",
        minW = 860,
        minH = 560,
    })
    bindShell(win, player)
    if type(win.switchPage) == "function" then
        win:switchPage("home")
    end
    local home = win:page("home")
    if home and type(home.onShow) == "function" then
        home:onShow()
    end
    syncHubSatellites(player)
    return win
end

function IKST_Hub.toggle(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canOpenPanel(player) then
        return nil
    end
    local win = IKUI_Shell.instance
    if win and not win.minimized and type(win.getIsVisible) == "function" and win:getIsVisible() then
        if type(win.close) == "function" then
            win:close()
        end
        return nil
    end
    if win and win.minimized and type(win.restoreFromMini) == "function" then
        bindShell(win, player)
        win:restoreFromMini()
        return win
    end
    return IKST_Hub.open(player)
end

function IKST_Hub.close()
    local win = IKUI_Shell.instance
    if win and type(win.close) == "function" then
        win:close()
    end
end

function IKST_Hub.minimize()
    local win = IKUI_Shell.instance
    if win and type(win.toggleMinimize) == "function" and not win.minimized then
        win:toggleMinimize()
    end
end

function IKST_Hub.activeJobPanel()
    local win = IKUI_Shell and IKUI_Shell.instance
    if win and type(win.page) == "function" and win.activePage then
        local page = win:page(win.activePage)
        if page and type(page.refreshJobUI) == "function" then
            return page
        end
        if page then
            return page
        end
    end
    return nil
end

function IKST_Hub.refreshActive(preserveScroll)
    local win = IKUI_Shell and IKUI_Shell.instance
    if win and type(win.page) == "function" and win.activePage then
        local page = win:page(win.activePage)
        if not page then
            return
        elseif type(page.refreshJobUI) == "function" then
            page:refreshJobUI(preserveScroll)
            return
        elseif type(page.refreshFromSnapshot) == "function" then
            page:refreshFromSnapshot()
            return
        elseif type(page.rebuild) == "function" then
            page:rebuild()
            return
        end
    end
end

function IKST_Hub.disarmWorldTools(player)
    player = IKST.resolvePlayer(player)
    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
        IKST_WorldPick.disarm(player)
    end
    if IKST_PaintCursorManager and type(IKST_PaintCursorManager.disarm) == "function" then
        IKST_PaintCursorManager.disarm(player)
    end
    local state = player and IKST.getPlayerState(player) or nil
    if state then
        state.armed = false
        state.armedJob = nil
        if IKST_WorldPick and type(IKST_WorldPick.clearCommandPickState) == "function" then
            IKST_WorldPick.clearCommandPickState(state)
        end
    end
    if IKST_PreviewOverlay and type(IKST_PreviewOverlay.clear) == "function" then
        IKST_PreviewOverlay.clear()
    end
    if IKST_HudChip and type(IKST_HudChip.sync) == "function" then
        IKST_HudChip.sync(player)
    end
end

function IKST_Hub.isOpenVisible()
    local win = IKUI_Shell and IKUI_Shell.instance
    return win ~= nil and not win.minimized
        and type(win.getIsVisible) == "function" and win:getIsVisible() == true
end

function IKST_Hub.isOpen()
    return IKST_Hub.isOpenVisible()
end
