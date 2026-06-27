if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Access"
require "IKST_Chrome"
require "IKST_Locks"
require "IKST_Grid"

IKST_KeypadKit = IKST_KeypadKit or {}

function IKST_KeypadKit.resolveItem(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        local actual = ISInventoryPane.getActualItems(items)
        if actual and actual[1] then
            return actual[1]
        end
    end
    return items and items[1] or nil
end

function IKST_KeypadKit.isKitItem(item)
    return item and item.getFullType and item:getFullType() == IKST.KEYPAD_KIT_TYPE
end

function IKST_KeypadKit.containerAtPlayer(player)
    if not player or not player.getSquare then
        return nil
    end
    local sq = player:getSquare()
    if not sq then
        return nil
    end
    local objects = sq:getObjects()
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getContainer and obj:getContainer() then
            return obj, obj:getContainer()
        end
    end
    return nil
end

function IKST_KeypadKit.promptPassword(player, item, x, y, z, onSubmit)
    local w, h = 280, 120
    local panel = ISPanel:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
    IKST_Chrome.applyPanelColors(panel)
    panel:initialise()
    panel:addToUIManager()

    local label = ISLabel:new(12, 12, 20, IKST.text("IGUI_IKST_Keypad_SetPassword", "Set lock password:"), 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    panel:addChild(label)

    local entry = ISTextEntryBox:new("", 12, 34, w - 24, 22)
    entry:initialise()
    entry:instantiate()
    panel:addChild(entry)

    local ok = ISButton:new(12, 68, 100, 22, IKST.text("IGUI_IKST_Keypad_Install", "Install"), panel, function()
        local pw = entry:getText() or ""
        if pw == "" then
            IKST.notify(player, IKST.text("IGUI_IKST_Keypad_PasswordRequired", "Enter a password."), false)
            return
        end
        panel:removeFromUIManager()
        if onSubmit then
            onSubmit(pw)
        end
    end)
    ok:initialise()
    panel:addChild(ok)

    local cancel = ISButton:new(120, 68, 80, 22, IKST.text("IGUI_IKST_Cancel", "Cancel"), panel, function()
        panel:removeFromUIManager()
    end)
    cancel:initialise()
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

function IKST_KeypadKit.onInventoryMenu(playerNum, context, items)
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    local item = IKST_KeypadKit.resolveItem(items)
    if not IKST_KeypadKit.isKitItem(item) then
        return
    end
    context:addOption(IKST.text("IGUI_IKST_Keypad_InstallHere", "Install keypad on nearby container"), player, function()
        local obj, container = IKST_KeypadKit.containerAtPlayer(player)
        if not container then
            IKST.notify(player, IKST.text("IGUI_IKST_Keypad_NoContainer", "Stand next to a container."), false)
            return
        end
        local sq = obj and obj.getSquare and obj:getSquare()
        if not sq then
            return
        end
        IKST_KeypadKit.promptPassword(player, item, sq:getX(), sq:getY(), sq:getZ(), function(pw)
            IKST_KeypadKit.installAt(player, item, sq:getX(), sq:getY(), sq:getZ(), pw)
        end)
    end)
end

function IKST_KeypadKit.onWorldMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    local sq = IKST_Grid and IKST_Grid.squareFromWorldObjects and IKST_Grid.squareFromWorldObjects(worldobjects)
    if not sq then
        return
    end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    if IKST_Locks and IKST_Locks.isLocked and IKST_Locks.isLocked(x, y, z) and not IKST_Locks.mayAccess(player, x, y, z) then
        context:addOption(IKST.text("IGUI_IKST_Keypad_Unlock", "Enter lock password"), player, function()
            IKST_KeypadKit.promptPassword(player, nil, x, y, z, function(pw)
                IKST.dispatchCommand(player, IKST.CMD.lockTryUnlock, { x = x, y = y, z = z, password = pw })
            end)
        end)
    end
end

if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(IKST_KeypadKit.onInventoryMenu)
end
if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_KeypadKit.onWorldMenu)
end
