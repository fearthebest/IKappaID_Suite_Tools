-- Clearance Tag: ID-bound physical access (separate serial store from bank ID).

require "IKST_Shared"
require "IKST_Identity"

IKST_Clearance = IKST_Clearance or {}

IKST_Clearance.STORE_KEY = "IKST_Clearance"
IKST_Clearance.CARD_TYPE = "IKST.ClearanceTag"
IKST_Clearance.MD_OWNER_KEY = "IKST_ownerKey"
IKST_Clearance.MD_CARD_SERIAL = "IKST_cardSerial"
IKST_Clearance.MD_ZONE_ID = "IKST_clearanceZone"

function IKST_Clearance.runsOnServer()
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return true
    end
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
end

function IKST_Clearance.store()
    return ModData.getOrCreate(IKST_Clearance.STORE_KEY)
end

function IKST_Clearance.ownerRow(ownerKey)
    if not ownerKey or ownerKey == "" then
        return nil
    end
    local data = IKST_Clearance.store()
    data.owners = data.owners or {}
    local row = data.owners[ownerKey]
    if not row then
        row = { activeSerial = 1 }
        data.owners[ownerKey] = row
    end
    local serial = math.floor(tonumber(row.activeSerial) or 0)
    if serial < 1 then
        serial = 1
        row.activeSerial = serial
    end
    return row
end

function IKST_Clearance.activeSerial(player)
    if not IKST_Identity or not IKST_Identity.accountKey then
        return nil
    end
    local key = IKST_Identity.accountKey(player)
    if not key then
        return nil
    end
    return math.floor(tonumber(IKST_Clearance.ownerRow(key).activeSerial) or 1)
end

function IKST_Clearance.bumpSerial(player)
    if not IKST_Clearance.runsOnServer() then
        return nil
    end
    if not IKST_Identity or not IKST_Identity.accountKey then
        return nil
    end
    local key = IKST_Identity.accountKey(player)
    if not key then
        return nil
    end
    local row = IKST_Clearance.ownerRow(key)
    local nextSerial = math.floor(tonumber(row.activeSerial) or 0) + 1
    if nextSerial < 1 then
        nextSerial = 1
    end
    row.activeSerial = nextSerial
    return nextSerial
end

function IKST_Clearance.isClearanceItem(item)
    return item and item.getFullType and item:getFullType() == IKST_Clearance.CARD_TYPE
end

function IKST_Clearance.zoneFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    local zone = md[IKST_Clearance.MD_ZONE_ID]
    if type(zone) ~= "string" or zone == "" then
        return nil
    end
    return zone
end

function IKST_Clearance.cardOwnerKeyFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    local key = md[IKST_Clearance.MD_OWNER_KEY]
    if type(key) ~= "string" or key == "" then
        return nil
    end
    return key
end

function IKST_Clearance.cardSerialFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    return tonumber(md[IKST_Clearance.MD_CARD_SERIAL])
end

function IKST_Clearance.cardMatchesPlayer(item, player)
    if not item or not player or not IKST_Clearance.isClearanceItem(item) then
        return false
    end
    if not IKST_Identity or not IKST_Identity.playerOwnsKey then
        return false
    end
    local ownerKey = IKST_Clearance.cardOwnerKeyFromItem(item)
    if not ownerKey or not IKST_Identity.playerOwnsKey(player, ownerKey) then
        return false
    end
    local serial = IKST_Clearance.cardSerialFromItem(item)
    local active = IKST_Clearance.activeSerial(player)
    if serial == nil or active == nil then
        return false
    end
    return math.floor(serial) == math.floor(active)
end

function IKST_Clearance.cardGrantsZone(item, zoneId)
    if not zoneId or zoneId == "" then
        return false
    end
    local cardZone = IKST_Clearance.zoneFromItem(item)
    if not cardZone then
        return false
    end
    return cardZone == zoneId
end

function IKST_Clearance.eachInventoryItem(player, fn)
    if not player or not player.getInventory or not fn then
        return
    end
    local inv = player:getInventory()
    if not inv or not inv.getItems then
        return
    end
    local items = inv:getItems()
    if not items or not items.size or not items.get then
        return
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            fn(item)
        end
    end
end

function IKST_Clearance.removePlayerCards(player)
    if not player or not IKST_Clearance.runsOnServer() then
        return 0
    end
    local inv = player:getInventory()
    if not inv or not inv.getItems or not inv.Remove then
        return 0
    end
    local removed = 0
    local toRemove = {}
    IKST_Clearance.eachInventoryItem(player, function(item)
        if IKST_Clearance.isClearanceItem(item) then
            toRemove[#toRemove + 1] = item
        end
    end)
    for _, item in ipairs(toRemove) do
        inv:Remove(item)
        removed = removed + 1
    end
    return removed
end

function IKST_Clearance.findValidCardForZone(player, zoneId)
    if not player or not zoneId or zoneId == "" then
        return nil
    end
    local found = nil
    IKST_Clearance.eachInventoryItem(player, function(item)
        if not found
            and IKST_Clearance.cardMatchesPlayer(item, player)
            and IKST_Clearance.cardGrantsZone(item, zoneId) then
            found = item
        end
    end)
    return found
end

function IKST_Clearance.stampCard(item, player, zoneId, serial)
    if not item or not player or not zoneId then
        return false
    end
    if not IKST_Clearance.runsOnServer() then
        return false
    end
    if not IKST_Clearance.isClearanceItem(item) then
        return false
    end
    if not IKST_Identity or not IKST_Identity.accountKey then
        return false
    end
    local key = IKST_Identity.accountKey(player)
    if not key then
        return false
    end
    serial = tonumber(serial) or IKST_Clearance.activeSerial(player)
    if not serial or serial < 1 then
        return false
    end
    local md = item:getModData()
    if not md then
        return false
    end
    md[IKST_Clearance.MD_OWNER_KEY] = key
    md[IKST_Clearance.MD_CARD_SERIAL] = serial
    md[IKST_Clearance.MD_ZONE_ID] = zoneId
    if item.syncItemFields then
        item:syncItemFields()
    end
    if item.setName then
        local label = IKST_Identity.displayLabel and IKST_Identity.displayLabel(player) or "Survivor"
        item:setName(label .. " — " .. zoneId)
    end
    return true
end

function IKST_Clearance.issueCard(player, zoneId)
    if not player or not zoneId or zoneId == "" then
        return false, "bad zone"
    end
    if not IKST_Clearance.runsOnServer() then
        return false, "server only"
    end
    local inv = player:getInventory()
    if not inv then
        return false, "no inventory"
    end
    if not instanceItem then
        return false, "cannot create item"
    end
    IKST_Clearance.removePlayerCards(player)
    local serial = IKST_Clearance.bumpSerial(player)
    if not serial then
        return false, "serial failed"
    end
    local card = instanceItem(IKST_Clearance.CARD_TYPE)
    if not card then
        return false, "cannot create clearance tag"
    end
    if not IKST_Clearance.stampCard(card, player, zoneId, serial) then
        return false, "stamp failed"
    end
    if not inv:AddItem(card) then
        return false, "inventory full"
    end
    if sendAddItemToContainer then
        sendAddItemToContainer(inv, card)
    end
    if IKST.notify then
        IKST.notify(player, IKST.text("IGUI_IKST_Clearance_Issued", "Clearance tag issued."), true)
    end
    return true, "clearance issued"
end

function IKST_Clearance.revokeCards(player)
    if not player or not IKST_Clearance.runsOnServer() then
        return false, "server only"
    end
    IKST_Clearance.bumpSerial(player)
    local removed = IKST_Clearance.removePlayerCards(player)
    if IKST.notify then
        IKST.notify(player, IKST.text("IGUI_IKST_Clearance_Revoked", "Clearance tags revoked."), true)
    end
    return true, "revoked " .. tostring(removed)
end
