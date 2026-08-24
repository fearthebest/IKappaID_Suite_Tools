-- Dashboard quick-action row (6 user-assignable slots, persisted in IKST_UIPrefs).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_UIPrefs"
require "IKST_QuickActions"

IKST_DashboardQuick = IKST_DashboardQuick or {}
IKST_DashboardQuick.SLOT_COUNT = 6
IKST_DashboardQuick.STAR_TEX_ON = "media/ui/FavoriteStarChecked.png"
IKST_DashboardQuick.STAR_TEX_OFF = "media/ui/FavoriteStarUnchecked.png"
IKST_DashboardQuick._starTexOn = nil
IKST_DashboardQuick._starTexOff = nil

IKST_DashboardQuick.DEFAULTS = {
    "nav:claim:safehouses",
    "nav:claim:vehicleclaim",
    "action:healSelf",
    "action:tpHome",
    "economy:open",
    "quick:quickSave",
}

function IKST_DashboardQuick.prefKey(index)
    return "dashQuick" .. tostring(index)
end

function IKST_DashboardQuick.loadSlots()
    local slots = {}
    local any = false
    for i = 1, IKST_DashboardQuick.SLOT_COUNT do
        local raw = IKST_UIPrefs.get(IKST_DashboardQuick.prefKey(i))
        if raw and raw ~= "" then
            slots[i] = raw
            any = true
        else
            slots[i] = nil
        end
    end
    if not any then
        for i = 1, IKST_DashboardQuick.SLOT_COUNT do
            slots[i] = IKST_DashboardQuick.DEFAULTS[i]
        end
    end
    return slots
end

function IKST_DashboardQuick.setSlot(index, entryId)
    index = tonumber(index)
    if not index or index < 1 or index > IKST_DashboardQuick.SLOT_COUNT then
        return
    end
    if entryId and entryId ~= "" then
        IKST_UIPrefs.set(IKST_DashboardQuick.prefKey(index), entryId)
    else
        IKST_UIPrefs.set(IKST_DashboardQuick.prefKey(index), "")
    end
end

function IKST_DashboardQuick.entryIdForNav(modeId, toolId)
    modeId = tostring(modeId or "")
    if not toolId or toolId == "" then
        return "nav:" .. modeId .. ":"
    end
    return "nav:" .. modeId .. ":" .. tostring(toolId)
end

function IKST_DashboardQuick.isFavorited(entryId)
    if not entryId or entryId == "" then
        return false
    end
    for i = 1, IKST_DashboardQuick.SLOT_COUNT do
        local raw = IKST_UIPrefs.get(IKST_DashboardQuick.prefKey(i))
        if raw == entryId then
            return true
        end
    end
    return false
end

function IKST_DashboardQuick.toggleFavorite(panel, entryId)
    if not entryId or entryId == "" then
        return
    end
    for i = 1, IKST_DashboardQuick.SLOT_COUNT do
        local raw = IKST_UIPrefs.get(IKST_DashboardQuick.prefKey(i))
        if raw == entryId then
            IKST_DashboardQuick.setSlot(i, nil)
            if panel and type(panel.refreshJobUI) == "function" then
                panel:refreshJobUI(true)
            end
            return
        end
    end
    for i = 1, IKST_DashboardQuick.SLOT_COUNT do
        local raw = IKST_UIPrefs.get(IKST_DashboardQuick.prefKey(i))
        if not raw or raw == "" then
            IKST_DashboardQuick.setSlot(i, entryId)
            if panel and type(panel.refreshJobUI) == "function" then
                panel:refreshJobUI(true)
            end
            if panel and panel.player and IKST.notify then
                IKST.notify(panel.player, IKST.text("IGUI_IKST_Favorited", "Added to favorites"), true)
            end
            return
        end
    end
    IKST_DashboardQuick.setSlot(IKST_DashboardQuick.SLOT_COUNT, entryId)
    if panel and type(panel.refreshJobUI) == "function" then
        panel:refreshJobUI(true)
    end
    if panel and panel.player and IKST.notify then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_Favorited", "Added to favorites"), true)
    end
end

function IKST_DashboardQuick.starSize()
    return 16
end

function IKST_DashboardQuick.starTexture(favorited)
    if not getTexture then
        return nil
    end
    if favorited then
        if not IKST_DashboardQuick._starTexOn then
            IKST_DashboardQuick._starTexOn = getTexture(IKST_DashboardQuick.STAR_TEX_ON)
        end
        return IKST_DashboardQuick._starTexOn
    end
    if not IKST_DashboardQuick._starTexOff then
        IKST_DashboardQuick._starTexOff = getTexture(IKST_DashboardQuick.STAR_TEX_OFF)
    end
    return IKST_DashboardQuick._starTexOff
end

function IKST_DashboardQuick.starRect(btn)
    local sz = IKST_DashboardQuick.starSize()
    local pad = 4
    local x = btn.width - sz - pad
    local y = btn.height - sz - pad
    if x < 0 then
        x = 0
    end
    if y < 0 then
        y = 0
    end
    return x, y, sz, sz
end

function IKST_DashboardQuick.hitStar(btn, localX, localY)
    if not btn then
        return false
    end
    local sx, sy, sw, sh = IKST_DashboardQuick.starRect(btn)
    return localX >= sx and localX <= sx + sw and localY >= sy and localY <= sy + sh
end

function IKST_DashboardQuick.drawToolStar(btn, favorited)
    if not btn or type(btn.drawTextureScaled) ~= "function" then
        return
    end
    local tex = IKST_DashboardQuick.starTexture(favorited == true)
    if not tex then
        return
    end
    local x, y, w, h = IKST_DashboardQuick.starRect(btn)
    btn:drawTextureScaled(tex, x, y, w, h, 1, 1, 1, 1)
end

function IKST_DashboardQuick.decorateToolButton(panel, btn, entryId)
    if not btn or not entryId then
        return
    end
    btn._ikstQuickEntry = entryId
    local baseRender = btn.render
    btn.render = function(b)
        if baseRender then
            baseRender(b)
        end
        IKST_DashboardQuick.drawToolStar(b, IKST_DashboardQuick.isFavorited(b._ikstQuickEntry))
    end
    btn.onMouseDown = function(b, mx, my)
        if IKST_DashboardQuick.hitStar(b, mx, my) then
            IKST_DashboardQuick.toggleFavorite(panel, b._ikstQuickEntry)
            return true
        end
        if ISButton and ISButton.onMouseDown then
            return ISButton.onMouseDown(b, mx, my)
        end
        return false
    end
end

function IKST_DashboardQuick.labelFor(entryId)
    if not entryId or entryId == "" then
        return IKST.text("IGUI_IKST_Dashboard_Quick_Empty", "Assign")
    end
    local kind, a, b, c = string.match(entryId, "^([^:]+):([^:]*):?([^:]*)$")
    if kind == "nav" and a ~= "" then
        local ws = IKST_HubNav and IKST_HubNav.workspaceById(a)
        if ws and b and b ~= "" and ws.tools then
            for _, tool in ipairs(ws.tools) do
                if tool.id == b then
                    return IKST_HubNav.toolLabel(tool)
                end
            end
        end
        if ws then
            return IKST_HubNav.modeLabel(ws)
        end
    end
    if kind == "action" and a ~= "" then
        if a == "healSelf" then
            return IKST.text("IGUI_IKST_Dashboard_Fav_Heal", "Heal self")
        end
        if a == "tpHome" then
            return IKST.text("IGUI_IKST_Dashboard_Fav_TpHome", "Teleport home")
        end
    end
    if kind == "economy" and a == "open" then
        return IKST.text("IGUI_IKST_Economy_OpenWallet", "Open economy")
    end
    if kind == "quick" and a ~= "" and IKST_QuickActions and IKST_QuickActions.DEFS[a] then
        return IKST_QuickActions.label(IKST_QuickActions.DEFS[a])
    end
    return entryId
end

function IKST_DashboardQuick.isAvailable(player, entryId)
    if not entryId or entryId == "" then
        return false
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    local kind, a, b = string.match(entryId, "^([^:]+):([^:]*):?([^:]*)$")
    if kind == "nav" and a ~= "" then
        if not IKST_Access or type(IKST_Access.canUseWorkspace) ~= "function" then
            return true
        end
        return IKST_Access.canUseWorkspace(player, a) == true
    end
    if kind == "action" and a == "healSelf" then
        return IKST_Access and IKST_Access.canUseStaffTools(player) == true
    end
    if kind == "action" and a == "tpHome" then
        return true
    end
    if kind == "economy" and a == "open" then
        if not (IKST.Plugins and IKST.Plugins.isActive("economy")) then
            return false
        end
        if not (IKST_EconomyUI and type(IKST_EconomyUI.open) == "function") then
            return false
        end
        return IKST_Access and IKST_Access.canUseWorkspace(player, IKST.VIEW.economy) == true
    end
    if kind == "quick" and a ~= "" and IKST_QuickActions and IKST_QuickActions.DEFS[a] then
        return true
    end
    return false
end

function IKST_DashboardQuick.assignableEntries(player)
    local out = {}
    local seen = {}
    local function add(id, label)
        if not id or seen[id] then
            return
        end
        if IKST_DashboardQuick.isAvailable(player, id) then
            seen[id] = true
            out[#out + 1] = { id = id, label = label }
        end
    end

    if IKST_HubNav and type(IKST_HubNav.visibleWorkspaces) == "function" then
        for _, ws in ipairs(IKST_HubNav.visibleWorkspaces(player)) do
            if not ws._missingPlugin then
                if ws.tools then
                    for _, tool in ipairs(ws.tools) do
                        if not tool.adminOnly or (IKST_Access and IKST_Access.canUseStaffTools(player)) then
                            local id = "nav:" .. tostring(ws.id) .. ":" .. tostring(tool.id)
                            add(id, IKST_HubNav.modeLabel(ws) .. " - " .. IKST_HubNav.toolLabel(tool))
                        end
                    end
                else
                    local id = "nav:" .. tostring(ws.id) .. ":"
                    add(id, IKST_HubNav.modeLabel(ws))
                end
            end
        end
    end

    add("action:healSelf", IKST.text("IGUI_IKST_Dashboard_Fav_Heal", "Heal self"))
    add("action:tpHome", IKST.text("IGUI_IKST_Dashboard_Fav_TpHome", "Teleport home"))
    add("economy:open", IKST.text("IGUI_IKST_Economy_OpenWallet", "Open economy"))

    if IKST_QuickActions and IKST_QuickActions.DEFS then
        for pinId, def in pairs(IKST_QuickActions.DEFS) do
            add("quick:" .. pinId, IKST_QuickActions.label(def))
        end
    end

    table.sort(out, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return out
end

function IKST_DashboardQuick.run(panel, slotIndex)
    if not panel then
        return
    end
    local slots = IKST_DashboardQuick.loadSlots()
    local entryId = slots[slotIndex]
    if not entryId or entryId == "" then
        IKST_DashboardQuick.showAssignMenu(panel, slotIndex)
        return
    end
    if not IKST_DashboardQuick.isAvailable(panel.player, entryId) then
        if IKST.notify and panel.player then
            IKST.notify(panel.player, IKST.text("IGUI_IKST_Dashboard_Quick_Unavailable", "Not available"), false)
        end
        return
    end

    local kind, a, b = string.match(entryId, "^([^:]+):([^:]*):?([^:]*)$")
    if kind == "nav" and a ~= "" then
        local tool = b
        if not tool or tool == "" then
            tool = IKST_HubNav.defaultTool(a)
        end
        panel:enterNav(a, tool)
        return
    end
    if kind == "action" and a ~= "" then
        if IKST_Dashboard and type(IKST_Dashboard.runFavoriteAction) == "function" then
            IKST_Dashboard.runFavoriteAction(panel, a)
        end
        return
    end
    if kind == "economy" and a == "open" then
        local player = panel.player
        if player and IKST_EconomyUI and type(IKST_EconomyUI.open) == "function" then
            IKST_EconomyUI.open(player, math.floor(player:getX()), math.floor(player:getY()), player:getZ())
        end
        return
    end
    if kind == "quick" and a ~= "" and IKST_QuickActions and type(IKST_QuickActions.run) == "function" then
        IKST_QuickActions.run(panel.player, a)
    end
end

function IKST_DashboardQuick.showAssignMenu(panel, slotIndex)
    if not panel or not panel.player then
        return
    end
    local player = panel.player
    if not ISContextMenu or type(ISContextMenu.get) ~= "function" then
        return
    end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local menu = ISContextMenu.get(player:getPlayerNum(), mx, my)
    if not menu then
        return
    end
    menu:addOption(IKST.text("IGUI_IKST_Dashboard_Quick_Clear", "Clear slot"), panel, function()
        IKST_DashboardQuick.setSlot(slotIndex, nil)
        if panel.refreshJobUI then
            panel:refreshJobUI(true)
        end
    end)
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(sub, IKST.text("IGUI_IKST_Dashboard_Quick_Assign", "Assign tool"))
    for _, entry in ipairs(IKST_DashboardQuick.assignableEntries(player)) do
        sub:addOption(entry.label, panel, function()
            IKST_DashboardQuick.setSlot(slotIndex, entry.id)
            if panel.refreshJobUI then
                panel:refreshJobUI(true)
            end
        end)
    end
end

function IKST_DashboardQuick.onSlotMouseDown(panel, slotIndex, _x, _y)
    if isRightMouseButtonDown and type(isRightMouseButtonDown) == "function" and isRightMouseButtonDown() then
        IKST_DashboardQuick.showAssignMenu(panel, slotIndex)
        return true
    end
    IKST_DashboardQuick.run(panel, slotIndex)
    return true
end
