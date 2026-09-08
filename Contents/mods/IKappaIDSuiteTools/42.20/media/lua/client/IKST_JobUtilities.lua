if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"
require "IKST_JobStaff"
require "IKST_JobThreat"
require "IKST_QuickActions"
require "IKST_ClientStaff"
require "IKST_StaffCheats"

IKST_JobUtilities = IKST_JobUtilities or {}

IKST_JobUtilities.SELF_TOGGLES = {
    {
        labelKey = "IGUI_IKST_UtilTile_GodMode", label = "God mode",
        isOn = function(p) return type(p.isGodMod) == "function" and p:isGodMod() == true end,
        fire = function(p) IKST.dispatchCommand(p, IKST.CMD.godSelf, {}) end,
    },
    {
        labelKey = "IGUI_IKST_UtilTile_NoClip", label = "No clip",
        isOn = function(p) return type(p.isNoClip) == "function" and p:isNoClip() == true end,
        fire = function(p) IKST.dispatchCommand(p, IKST.CMD.noclipSelf, {}) end,
    },
    {
        labelKey = "IGUI_IKST_UtilTile_Invisible", label = "Invisible",
        isOn = function(p) return type(p.isInvisible) == "function" and p:isInvisible() == true end,
        fire = function(p) IKST.dispatchCommand(p, IKST.CMD.invisSelf, {}) end,
    },
}

IKST_JobUtilities.SELF_CHEAT_TOGGLES = {
    { labelKey = "IGUI_IKST_UtilTile_UnlStamina", label = "Unlimited stamina", cheat = "unlimitedEndurance" },
    { labelKey = "IGUI_IKST_UtilTile_SuperSpeed", label = "Super speed", cheat = "fastMove" },
}

IKST_JobUtilities.ITEM_CHEAT_TOGGLES = {
    { labelKey = "IGUI_IKST_UtilTile_UnlAmmo", label = "Unlimited ammo", cheat = "unlimitedAmmo" },
    { labelKey = "IGUI_IKST_UtilTile_NoMaterials", label = "No materials", cheat = "build" },
    { labelKey = "IGUI_IKST_UtilTile_InstantCraft", label = "Instant craft", cheat = "instantActions" },
    { labelKey = "IGUI_IKST_UtilTile_UnlCarry", label = "Unlimited carry", cheat = "unlimitedCarry" },
}

function IKST_JobUtilities.disarmAllSelfTools(panel)
    local p = panel.player
    if not p then
        return
    end
    if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
        for _, toggle in ipairs(IKST_JobUtilities.SELF_TOGGLES) do
            if toggle.isOn(p) then
                toggle.fire(p)
            end
        end
    end
    for _, toggle in ipairs(IKST_JobUtilities.SELF_CHEAT_TOGGLES) do
        if IKST_StaffCheats.isActive(p, toggle.cheat) then
            IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = toggle.cheat })
        end
    end
    for _, toggle in ipairs(IKST_JobUtilities.ITEM_CHEAT_TOGGLES) do
        if IKST_StaffCheats.isActive(p, toggle.cheat) then
            IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = toggle.cheat })
        end
    end
    panel:refreshJobUI()
end

function IKST_JobUtilities.cycleTarget(panel, dir)
    local list = IKST_JobStaff.onlinePlayers or {}
    if #list == 0 then
        return
    end
    local idx = panel.staffTargetIndex or 1
    idx = idx + dir
    if idx < 1 then
        idx = #list
    elseif idx > #list then
        idx = 1
    end
    panel.staffTargetIndex = idx
    panel:refreshJobUI()
end

local function selfMovementItems(p)
    local items = {}
    if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
        for _, t in ipairs(IKST_JobUtilities.SELF_TOGGLES) do
            items[#items + 1] = {
                label = IKST.text(t.labelKey, t.label),
                primary = t.isOn(p) == true,
                onClick = function()
                    t.fire(p)
                    -- refresh via JobsPanel after command result; local toggle state needs rebuild
                end,
            }
        end
    end
    for _, t in ipairs(IKST_JobUtilities.SELF_CHEAT_TOGGLES) do
        items[#items + 1] = {
            label = IKST.text(t.labelKey, t.label),
            primary = IKST_StaffCheats.isActive(p, t.cheat) == true,
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = t.cheat })
            end,
        }
    end
    return items
end

local function itemsInventoryItems(p)
    local items = {}
    for _, t in ipairs(IKST_JobUtilities.ITEM_CHEAT_TOGGLES) do
        items[#items + 1] = {
            label = IKST.text(t.labelKey, t.label),
            primary = IKST_StaffCheats.isActive(p, t.cheat) == true,
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = t.cheat })
            end,
        }
    end
    items[#items + 1] = {
        label = IKST.text("IGUI_IKST_UtilTile_Duplicate", "Duplicate"),
        onClick = function()
            IKST.dispatchCommand(p, IKST.CMD.duplicateItem, {})
        end,
    }
    return items
end

local function wrapRefresh(panel, fn)
    return function()
        fn()
        panel:refreshJobUI()
    end
end


function IKST_JobUtilities.buildServerTools(panel)
    if IKST_SoftTool_Utilities and type(IKST_SoftTool_Utilities.buildServerTools) == "function" then
        return IKST_SoftTool_Utilities.buildServerTools(panel)
    end
    return 8
end

function IKST_JobUtilities.buildSelfOverview(panel)
    if IKST_SoftTool_Utilities and type(IKST_SoftTool_Utilities.buildSelf) == "function" then
        return IKST_SoftTool_Utilities.buildSelf(panel)
    end
    return 8
end

function IKST_JobUtilities.build(panel)
    if IKST_SoftTool_Utilities and type(IKST_SoftTool_Utilities.build) == "function" then
        return IKST_SoftTool_Utilities.build(panel)
    end
    return 8
end
