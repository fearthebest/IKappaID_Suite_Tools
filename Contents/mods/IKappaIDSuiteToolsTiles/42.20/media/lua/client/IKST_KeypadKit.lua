if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Access"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_Locks"
require "IKST_Grid"
require "IKST_Clearance"
require "IKST_PreviewOverlay"

IKST_KeypadKit = IKST_KeypadKit or {}
IKST_KeypadKit._installTarget = nil
IKST_KeypadKit._installDialogOpen = false
IKST_KeypadKit._tickHooked = false

function IKST_KeypadKit.playerHasClearanceTag(player)
    if not player or not IKST_Clearance or not IKST_Clearance.eachInventoryItem then
        return false
    end
    local found = false
    IKST_Clearance.eachInventoryItem(player, function(item)
        if not found and IKST_Clearance.isClearanceItem(item) then
            found = true
        end
    end)
    return found
end

function IKST_KeypadKit.isKitItem(item)
    return item and type(item.getFullType) == "function" and item:getFullType() == IKST.KEYPAD_KIT_TYPE
end

function IKST_KeypadKit.findKitInInventory(player)
    if not player or not IKST_Clearance or not IKST_Clearance.eachInventoryItem then
        return nil
    end
    local kit = nil
    IKST_Clearance.eachInventoryItem(player, function(item)
        if not kit and IKST_KeypadKit.isKitItem(item) then
            kit = item
        end
    end)
    return kit
end

function IKST_KeypadKit.releaseTick()
    if not IKST_KeypadKit._tickHooked then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(IKST_KeypadKit.onTick)
    end
    IKST_KeypadKit._tickHooked = false
end

function IKST_KeypadKit.ensureTick()
    if IKST_KeypadKit._tickHooked then
        return
    end
    if not Events or not Events.OnTick or not Events.OnTick.Add then
        return
    end
    Events.OnTick.Add(IKST_KeypadKit.onTick)
    IKST_KeypadKit._tickHooked = true
end

function IKST_KeypadKit.clearInstallHighlight()
    local obj = IKST_KeypadKit._installTarget and IKST_KeypadKit._installTarget.obj
    IKST_KeypadKit._installTarget = nil
    IKST_KeypadKit._installDialogOpen = false
    if IKST_PreviewOverlay and type(IKST_PreviewOverlay.releaseObjectHighlight) == "function" then
        IKST_PreviewOverlay.releaseObjectHighlight(obj)
    elseif obj and type(obj.setHighlighted) == "function" then
        obj:setHighlighted(false, false)
    end
    if IKST_PreviewOverlay and IKST_PreviewOverlay.clearJob then
        IKST_PreviewOverlay.clearJob()
    end
    IKST_KeypadKit.releaseTick()
end

function IKST_KeypadKit.setInstallHighlight(obj)
    IKST_KeypadKit.clearInstallHighlight()
    if not obj then
        return
    end
    IKST_KeypadKit._installTarget = { obj = obj }
    if IKST_PreviewOverlay and type(IKST_PreviewOverlay.releaseObjectHighlight) == "function" then
        IKST_PreviewOverlay.releaseObjectHighlight(obj)
    end
    local sq = nil
    if IKST_Grid and type(IKST_Grid.squareFromObject) == "function" then
        sq = IKST_Grid.squareFromObject(obj)
    elseif type(obj.getSquare) == "function" then
        sq = obj:getSquare()
    end
    if sq and IKST_PreviewOverlay and type(IKST_PreviewOverlay.setJobSquare) == "function" then
        IKST_PreviewOverlay.setJobSquare(sq, "accent")
    end
    IKST_KeypadKit.ensureTick()
end

function IKST_KeypadKit.isContextMenuVisible()
    if not UIManager or type(UIManager.getUI) ~= "function" then
        return false
    end
    local ui = UIManager:getUI()
    if not ui then
        return false
    end
    for i = 0, ui:size() - 1 do
        local panel = ui:get(i)
        if panel and panel.Type == "ISContextMenu" and type(panel.isVisible) == "function" and panel:isVisible() then
            return true
        end
    end
    return false
end

function IKST_KeypadKit.onTick()
    if IKST_KeypadKit._installDialogOpen then
        return
    end
    if not IKST_KeypadKit._installTarget then
        IKST_KeypadKit.releaseTick()
        return
    end
    if IKST_KeypadKit.isContextMenuVisible() then
        return
    end
    IKST_KeypadKit.clearInstallHighlight()
end

function IKST_KeypadKit.promptPassword(player, item, x, y, z, onSubmit, clearHighlightOnClose)
    if clearHighlightOnClose == nil then
        clearHighlightOnClose = true
    end
    local w, h = 280, 120
    local panel = ISPanel:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
    IKUI_Chrome.applyPanelColors(panel)
    panel:initialise()
    panel:addToUIManager()

    local function closeDialog(runSubmit)
        panel:removeFromUIManager()
        IKST_KeypadKit._installDialogOpen = false
        if clearHighlightOnClose then
            IKST_KeypadKit.clearInstallHighlight()
        end
        if runSubmit then
            runSubmit()
        end
    end

    local label = ISLabel:new(12, 12, 20, IKST.text("IGUI_IKST_Keypad_SetPassword", "Set lock password:"), 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    panel:addChild(label)

    local entry = ISTextEntryBox:new("", 12, 34, w - 24, 22)
    entry:initialise()
    entry:instantiate()
    panel:addChild(entry)

    local ok = IKUI_Chrome.newActionButton(12, 68, 100, 22, IKST.text("IGUI_IKST_Keypad_Install", "Install"), panel, function()
        local pw = entry:getText() or ""
        if pw == "" then
            IKST.notify(player, IKST.text("IGUI_IKST_Keypad_PasswordRequired", "Enter a password."), false)
            return
        end
        closeDialog(function()
            if onSubmit then
                onSubmit(pw)
            end
        end)
    end, "primary")
    panel:addChild(ok)

    local cancel = IKUI_Chrome.newActionButton(120, 68, 80, 22, IKST.text("IGUI_IKST_Cancel", "Cancel"), panel, function()
        closeDialog(nil)
    end, "outline")
    panel:addChild(cancel)
end

function IKST_KeypadKit.installAt(player, item, x, y, z, password)
    if not player or not item or not item.getID then
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.lockInstallKeypad, {
        x = x, y = y, z = z,
        password = password,
        itemId = item:getID(),
    })
end

function IKST_KeypadKit.onWorldMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context or not IKST_Grid then
        return
    end

    local obj, container, sq = IKST_Grid.containerFromWorldObjects(worldobjects)
    if not sq then
        sq = IKST_Grid.squareFromWorldObjects(worldobjects, player)
    end
    if not sq then
        return
    end

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local locked = IKST_Locks and IKST_Locks.isLocked and IKST_Locks.isLocked(x, y, z)
    local mayAccess = not locked or (IKST_Locks.mayAccess and IKST_Locks.mayAccess(player, x, y, z))

    if locked and not mayAccess then
        context:addOption(IKST.text("IGUI_IKST_Keypad_Unlock", "Enter lock password"), player, function()
            IKST_KeypadKit.promptPassword(player, nil, x, y, z, function(pw)
                IKST.dispatchCommand(player, IKST.CMD.lockTryUnlock, { x = x, y = y, z = z, password = pw })
            end, false)
        end)
        if IKST_KeypadKit.playerHasClearanceTag(player) then
            context:addOption(IKST.text("IGUI_IKST_Clearance_UseTag", "Use clearance tag"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.lockTryClearance, { x = x, y = y, z = z })
            end)
        end
        return
    end

    if not container then
        return
    end

    local kit = IKST_KeypadKit.findKitInInventory(player)
    if not kit then
        return
    end

    local installSq = IKST_Grid.squareFromObject(obj) or sq
    IKST_KeypadKit.setInstallHighlight(obj)

    context:addOption(IKST.text("IGUI_IKST_Keypad_InstallOnContainer", "Install keypad"), player, function()
        local liveKit = IKST_KeypadKit.findKitInInventory(player)
        if not liveKit then
            IKST.notify(player, IKST.text("IGUI_IKST_Keypad_NoKit", "You need a keypad kit in your inventory."), false)
            IKST_KeypadKit.clearInstallHighlight()
            return
        end
        if not installSq then
            IKST_KeypadKit.clearInstallHighlight()
            return
        end
        local ix, iy, iz = installSq:getX(), installSq:getY(), installSq:getZ()
        IKST_KeypadKit._installDialogOpen = true
        IKST_KeypadKit.promptPassword(player, liveKit, ix, iy, iz, function(pw)
            IKST_KeypadKit.installAt(player, liveKit, ix, iy, iz, pw)
        end, true)
    end)
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_KeypadKit.onWorldMenu)
end
