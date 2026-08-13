-- Teleport and player-admin helpers (split from IKST_StaffOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Identity"
require "IKST_StaffCheats"
require "IKST_Clearance"
require "IKST_WorldOps"
require "IKST_Args"

IKST_StaffOps = IKST_StaffOps or {}

IKST_StaffOps.KITS = {
    Tools = { {"Base.Hammer", 1}, {"Base.Saw", 1}, {"Base.Screwdriver", 1}, {"Base.Nails", 50} },
    Medical = { {"Base.Bandage", 6}, {"Base.Disinfectant", 2}, {"Base.Pills", 3} },
    Food = { {"Base.TinnedBeans", 5}, {"Base.WaterBottleFull", 3} },
}

function IKST_StaffOps.addItemToInventory(inv, itemType)
    if not inv or not itemType or itemType == "" then
        return false
    end
    if instanceItem then
        local item = instanceItem(itemType)
        if not item then
            return false
        end
        if not inv:AddItem(item) then
            return false
        end
        if sendAddItemToContainer then
            sendAddItemToContainer(inv, item)
        end
        if inv.setDrawDirty then
            inv:setDrawDirty(true)
        end
        return true
    end
    if not inv.AddItem then
        return false
    end
    local added = inv:AddItem(itemType, 1, true)
    if type(added) == "boolean" then
        if added and inv.setDrawDirty then
            inv:setDrawDirty(true)
        end
        return added
    end
    if added and inv.setDrawDirty then
        inv:setDrawDirty(true)
    end
    return added ~= nil
end

function IKST_StaffOps.teleportPlayer(player, x, y, z)
    if not player then
        return false
    end
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z) or 0
    if not x or not y then
        return false
    end
    local vehicle = type(player.getVehicle) == "function" and player:getVehicle()
    if vehicle and type(vehicle.exit) == "function" then
        vehicle:exit(player)
    end
    if type(player.teleportTo) == "function" then
        player:teleportTo(x, y, z)
    else
        player:setX(x)
        player:setY(y)
        player:setZ(z)
        if type(player.setLx) == "function" then
            player:setLx(x)
            player:setLy(y)
        end
        if type(player.setLz) == "function" then
            player:setLz(z)
        end
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if type(teleportPlayers) == "function" then
            teleportPlayers(player)
        end
        if IKST.deliverClientCommand then
            IKST.deliverClientCommand(player, IKST.CMD.applyTeleport, { x = x, y = y, z = z })
        end
    end
    return true
end

function IKST_StaffOps.findPlayerByOnlineID(id)
    id = tonumber(id)
    if id == nil then
        return nil
    end
    if getPlayerByOnlineID then
        local player = getPlayerByOnlineID(id)
        if player then
            return player
        end
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size and list.get then
        for i = 0, list:size() - 1 do
            local player = list:get(i)
            if player and type(player.getOnlineID) == "function" and player:getOnlineID() == id then
                return player
            end
        end
    end
    return nil
end

function IKST_StaffOps.playerLabel(player)
    if not player then
        return "player"
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getOnlineID then
        return "Player " .. tostring(player:getOnlineID())
    end
    return "player"
end

function IKST_StaffOps.heal(player)
    if not player or not player.getBodyDamage then
        return false, "no player"
    end
    player:getBodyDamage():RestoreToFullHealth()
    return true, "Healed"
end

function IKST_StaffOps.setStatMinimum(stats, stat)
    if not stats or not stat or not stats.set or not stat.getMinimumValue then
        return false
    end
    stats:set(stat, stat:getMinimumValue())
    return true
end

function IKST_StaffOps.setStatMaximum(stats, stat)
    if not stats or not stat or not stats.set or not stat.getMaximumValue then
        return false
    end
    stats:set(stat, stat:getMaximumValue())
    return true
end

function IKST_StaffOps.feed(player)
    if not player or not player.getStats then
        return false, "no player"
    end
    local stats = player:getStats()
    if not stats then
        return false, "no stats"
    end
    if CharacterStat and stats.set then
        IKST_StaffOps.setStatMinimum(stats, CharacterStat.HUNGER)
        IKST_StaffOps.setStatMinimum(stats, CharacterStat.THIRST)
        IKST_StaffOps.setStatMinimum(stats, CharacterStat.FATIGUE)
        IKST_StaffOps.setStatMaximum(stats, CharacterStat.ENDURANCE)
        return true, "Fed"
    end
    return false, "stats unavailable"
end

function IKST_StaffOps.cure(player)
    if not player or not player.getBodyDamage then
        return false, "no player"
    end
    local bd = player:getBodyDamage()
    if not bd then
        return false, "no body damage"
    end
    if bd.setInfected then
        bd:setInfected(false)
    end
    if bd.setIsFakeInfected then
        bd:setIsFakeInfected(false)
    end
    if bd.setInfectionTime then
        bd:setInfectionTime(-1)
    end
    if bd.setInfectionMortalityDuration then
        bd:setInfectionMortalityDuration(-1)
    end
    if bd.setInfectionGrowthRate then
        bd:setInfectionGrowthRate(0)
    end
    if player.getStats and CharacterStat then
        local stats = player:getStats()
        if stats and stats.set then
            IKST_StaffOps.setStatMinimum(stats, CharacterStat.ZOMBIE_INFECTION)
            IKST_StaffOps.setStatMinimum(stats, CharacterStat.ZOMBIE_FEVER)
        end
    end
    bd:RestoreToFullHealth()
    return true, "Cured"
end

-- MP server only: force-sync engine flags to remote clients. SP applies on client JVM.
function IKST_StaffOps.useForcedSync()
    return IKST.isMultiplayerSession and IKST.isMultiplayerSession()
        and IKST.runsOnServerJvm and IKST.runsOnServerJvm()
end

function IKST_StaffOps.shouldMutateEngineOnServer()
    return IKST_StaffOps.useForcedSync()
end

-- Mirrors PlayerCheats / IKST.engineStaffModesAvailable().
function IKST_StaffOps.engineCheatsAllowed()
    if IKST.engineStaffModesAvailable then
        return IKST.engineStaffModesAvailable() == true
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return true
    end
    if type(getDebug) == "function" and getDebug() then
        return true
    end
    if type(isDebugEnabled) == "function" and isDebugEnabled() then
        return true
    end
    return false
end

-- SP without -debug: refuse turning ON God/Invisible/Ghost/NoClip (engine no-ops).
function IKST_StaffOps.requireEngineCheats(turningOn)
    if turningOn ~= true then
        return true
    end
    if IKST_StaffOps.engineCheatsAllowed() then
        return true
    end
    return false, "needs -debug in SP"
end

function IKST_StaffOps.setPlayerFlag(player, setFnName, on)
    if not player or type(player[setFnName]) ~= "function" then
        return false
    end
    on = on == true
    if IKST_StaffOps.useForcedSync() then
        player[setFnName](player, on, true)
    else
        player[setFnName](player, on)
    end
    return true
end

function IKST_StaffOps.syncStaffModesToClient(player)
    if not player or not IKST.deliverClientCommand then
        return
    end
    local md = IKST_StaffOps.staffModData(player)
    local args = {}
    if md and md.god ~= nil then
        args.god = md.god == true
    end
    if md and md.ghost ~= nil then
        args.ghost = md.ghost == true
    end
    if md and md.noclip ~= nil then
        args.noclip = md.noclip == true
    elseif md and md.ghost ~= nil then
        -- Legacy: Ghost used to drive noclip too.
        args.noclip = md.ghost == true
    end
    if md and md.invisible ~= nil then
        args.invisible = md.invisible == true
    end
    if args.god == nil and args.ghost == nil and args.noclip == nil and args.invisible == nil then
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.applyStaffModes, args)
end

function IKST_StaffOps.toggleGod(player)
    if not player or not player.getModData then
        return false, "unavailable"
    end
    local md = IKST_StaffOps.staffModData(player)
    if not md then
        return false, "unavailable"
    end
    local nextOn = not (md.god == true)
    local okCheat, cheatMsg = IKST_StaffOps.requireEngineCheats(nextOn)
    if not okCheat then
        return false, "God " .. (cheatMsg or "unavailable")
    end
    md.god = nextOn
    IKST_StaffOps.applyStaffModes(player)
    IKST_StaffOps.syncStaffModesToClient(player)
    return true, md.god and "God ON" or "God OFF"
end

function IKST_StaffOps.staffModData(player)
    if not player or not player.getModData then
        return nil
    end
    local md = player:getModData()
    if not md.ikst_staff then
        md.ikst_staff = {}
    end
    return md.ikst_staff
end

function IKST_StaffOps.applyStaffModes(player)
    if not player then
        return
    end
    if not IKST_StaffOps.shouldMutateEngineOnServer() then
        return
    end
    local md = IKST_StaffOps.staffModData(player)
    if not md then
        return
    end
    if md.god ~= nil then
        IKST_StaffOps.setPlayerFlag(player, "setGodMod", md.god == true)
    end
    if md.ghost ~= nil then
        IKST_StaffOps.setPlayerFlag(player, "setGhostMode", md.ghost == true)
    end
    local noclipOn = nil
    if md.noclip ~= nil then
        noclipOn = md.noclip == true
    elseif md.ghost ~= nil then
        -- Keep prior Ghost button behavior: ghost also drives noclip unless noclip was set alone.
        noclipOn = md.ghost == true
    end
    if noclipOn ~= nil then
        IKST_StaffOps.setPlayerFlag(player, "setNoClip", noclipOn)
    end
    if md.invisible ~= nil then
        IKST_StaffOps.setPlayerFlag(player, "setInvisible", md.invisible == true)
    end
end

function IKST_StaffOps.toggleInvisible(player)
    if not player or type(player.setInvisible) ~= "function" then
        return false, "unavailable"
    end
    local md = IKST_StaffOps.staffModData(player)
    if not md then
        return false, "unavailable"
    end
    local nextOn = not (md.invisible == true)
    local okCheat, cheatMsg = IKST_StaffOps.requireEngineCheats(nextOn)
    if not okCheat then
        return false, "Invisible " .. (cheatMsg or "unavailable")
    end
    md.invisible = nextOn
    IKST_StaffOps.applyStaffModes(player)
    IKST_StaffOps.syncStaffModesToClient(player)
    return true, md.invisible and "Invisible ON" or "Invisible OFF"
end

function IKST_StaffOps.toggleGhost(player)
    if not player or type(player.setGhostMode) ~= "function" then
        return false, "unavailable"
    end
    local md = IKST_StaffOps.staffModData(player)
    if not md then
        return false, "unavailable"
    end
    local nextOn = not (md.ghost == true)
    local okCheat, cheatMsg = IKST_StaffOps.requireEngineCheats(nextOn)
    if not okCheat then
        return false, "Ghost " .. (cheatMsg or "unavailable")
    end
    md.ghost = nextOn
    -- Ghost also toggles noclip (walk through walls) unless user set noclip separately later.
    md.noclip = md.ghost
    IKST_StaffOps.applyStaffModes(player)
    IKST_StaffOps.syncStaffModesToClient(player)
    return true, md.ghost and "Ghost ON" or "Ghost OFF"
end

function IKST_StaffOps.toggleNoClip(player)
    if not player or type(player.setNoClip) ~= "function" then
        return false, "unavailable"
    end
    local md = IKST_StaffOps.staffModData(player)
    if not md then
        return false, "unavailable"
    end
    local nextOn = not (md.noclip == true)
    local okCheat, cheatMsg = IKST_StaffOps.requireEngineCheats(nextOn)
    if not okCheat then
        return false, "NoClip " .. (cheatMsg or "unavailable")
    end
    md.noclip = nextOn
    IKST_StaffOps.applyStaffModes(player)
    IKST_StaffOps.syncStaffModesToClient(player)
    return true, md.noclip and "NoClip ON" or "NoClip OFF"
end

function IKST_StaffOps.giveItem(player, itemType, count)
    if not player or not player.getInventory then
        return false, "no player"
    end
    if not IKST_Args then
        require "IKST_Args"
    end
    itemType = IKST_Args.readItemType({ type = itemType }, "type")
    if not itemType then
        return false, "invalid item type"
    end
    count = IKST_Args.readAmount({ count = count }, "count", 1, 100) or 1
    local inv = player:getInventory()
    local given = 0
    for _ = 1, count do
        if IKST_StaffOps.addItemToInventory(inv, itemType) then
            given = given + 1
        end
    end
    if given > 0 then
        return true, "Gave " .. given .. " x " .. itemType
    end
    return false, "give failed"
end

function IKST_StaffOps.duplicateHeldItem(player)
    if not player then
        return false, "no player"
    end
    local item = nil
    if type(player.getPrimaryHandItem) == "function" then
        item = player:getPrimaryHandItem()
    end
    if not item and type(player.getSecondaryHandItem) == "function" then
        item = player:getSecondaryHandItem()
    end
    if not item then
        return false, "no item in hands"
    end
    local itemType = nil
    if type(item.getFullType) == "function" then
        itemType = item:getFullType()
    elseif type(item.getType) == "function" then
        itemType = item:getType()
    end
    if not itemType or itemType == "" then
        return false, "unknown item type"
    end
    return IKST_StaffOps.giveItem(player, itemType, 1)
end

function IKST_StaffOps.giveKit(player, kitName)
    local kit = IKST_StaffOps.KITS[kitName]
    if not kit or not player or not player.getInventory then
        return false, "unknown kit"
    end
    local inv = player:getInventory()
    local n = 0
    for _, entry in ipairs(kit) do
        local itemType = entry[1]
        local qty = entry[2] or 1
        for _ = 1, qty do
            if IKST_StaffOps.addItemToInventory(inv, itemType) then
                n = n + 1
            end
        end
    end
    return n > 0, kitName .. ": " .. n .. " items"
end

function IKST_StaffOps.clearZombies(player, radius)
    if not IKST_WorldOps or not IKST_WorldOps.threatCull then
        return false, "world ops unavailable"
    end
    local px = player and player:getX() or 0
    local py = player and player:getY() or 0
    local pz = player and player:getZ() or 0
    radius = tonumber(radius)
    if not radius or radius <= 0 then
        radius = 99999
    end
    local total = 0
    local batch = 200
    local removed = IKST_WorldOps.threatCull(px, py, pz, radius, batch)
    while removed > 0 do
        total = total + removed
        if removed < batch then
            break
        end
        removed = IKST_WorldOps.threatCull(px, py, pz, radius, batch)
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() and player and IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.threatResult, {
            removed = total,
            x = math.floor(px),
            y = math.floor(py),
            z = pz,
            radius = radius,
            mirrorCull = true,
        })
    end
    if IKST_WorldOps and IKST_WorldOps.broadcastThreatCull then
        IKST_WorldOps.broadcastThreatCull(player, px, py, pz, radius, total)
    end
    return true, "Removed " .. total .. " zombies"
end

function IKST_StaffOps.forEachOnline(visitor)
    local count = 0
    local list = getOnlinePlayers and getOnlinePlayers()
    if not list or not list.size or not list.get or not visitor then
        return count
    end
    for i = 0, list:size() - 1 do
        local onlinePlayer = list:get(i)
        if onlinePlayer then
            visitor(onlinePlayer)
            count = count + 1
        end
    end
    return count
end

function IKST_StaffOps.healAll()
    local n = 0
    IKST_StaffOps.forEachOnline(function(p)
        IKST_StaffOps.heal(p)
        n = n + 1
    end)
    return true, "Healed " .. n .. " players"
end

function IKST_StaffOps.feedAll()
    local n = 0
    IKST_StaffOps.forEachOnline(function(p)
        IKST_StaffOps.feed(p)
        n = n + 1
    end)
    return true, "Fed " .. n .. " players"
end

function IKST_StaffOps.cureAll()
    local n = 0
    IKST_StaffOps.forEachOnline(function(p)
        IKST_StaffOps.cure(p)
        n = n + 1
    end)
    return true, "Cured " .. n .. " players"
end

function IKST_StaffOps.tpAllToMe(player)
    if not player then
        return false, "no player"
    end
    local myId = type(player.getOnlineID) == "function" and player:getOnlineID()
    local x, y, z = player:getX(), player:getY(), player:getZ()
    local n = 0
    IKST_StaffOps.forEachOnline(function(p)
        if not myId or not p.getOnlineID or p:getOnlineID() ~= myId then
            IKST_StaffOps.teleportPlayer(p, x, y, z)
            n = n + 1
        end
    end)
    return true, "Teleported " .. n .. " players to you"
end

function IKST_StaffOps.listOnlinePlayers()
    local out = {}
    local list = getOnlinePlayers and getOnlinePlayers()
    if not list or not list.size or not list.get then
        return out
    end
    for i = 0, list:size() - 1 do
        local player = list:get(i)
        if player and player.getOnlineID then
            out[#out + 1] = {
                id = player:getOnlineID(),
                name = IKST_StaffOps.playerLabel(player),
            }
        end
    end
    return out
end

function IKST_StaffOps.reissueBankId(player)
    if not player then
        return false, "no player"
    end
    if not IKST_Economy or not IKST_Economy.idCardBanking or not IKST_Economy.idCardBanking() then
        return false, "ID card banking is off"
    end
    if not IKST_EconomyIdentity or not IKST_EconomyIdentity.reissueIdCard then
        return false, "identity module missing"
    end
    local ok, msg = IKST_EconomyIdentity.reissueIdCard(player, { recordCooldown = false, bumpSerial = true, notifyPlayer = true })
    return ok, msg or (ok and "ID reissued" or "reissue failed")
end

function IKST_StaffOps.repairGear(player)
    if not player or not player.getInventory then
        return false, "no player"
    end
    local inv = player:getInventory()
    if not inv or not inv.getItems then
        return false, "no inventory"
    end
    local items = inv:getItems()
    if not items or not items.size or not items.get then
        return false, "no items"
    end
    local count = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getConditionMax) == "function" and type(item.setCondition) == "function" then
            local max = item:getConditionMax()
            if max and max > 0 then
                item:setCondition(max)
                count = count + 1
            end
        end
    end
    return true, "Repaired " .. tostring(count) .. " items"
end

function IKST_StaffOps.resetMood(player)
    if not player or not player.getStats then
        return false, "no player"
    end
    local stats = player:getStats()
    if not stats or not CharacterStat or not stats.set then
        return false, "stats unavailable"
    end
    IKST_StaffOps.setStatMinimum(stats, CharacterStat.PANIC)
    IKST_StaffOps.setStatMinimum(stats, CharacterStat.STRESS)
    return true, "Mood reset"
end

function IKST_StaffOps.issueClearance(player, zoneId)
    if not IKST_Clearance or not IKST_Clearance.issueCard then
        return false, "clearance unavailable"
    end
    zoneId = IKST_Args and IKST_Args.readZoneId({ zoneId = zoneId }, "zoneId")
    if not zoneId then
        return false, "invalid zone id"
    end
    return IKST_Clearance.issueCard(player, zoneId)
end

function IKST_StaffOps.revokeClearance(player)
    if not IKST_Clearance or not IKST_Clearance.revokeCards then
        return false, "clearance unavailable"
    end
    return IKST_Clearance.revokeCards(player)
end
