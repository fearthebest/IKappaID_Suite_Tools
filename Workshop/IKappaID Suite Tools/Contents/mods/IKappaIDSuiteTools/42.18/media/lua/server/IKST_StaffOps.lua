if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Identity"
require "IKST_Waypoints"

IKST_StaffOps = IKST_StaffOps or {}

IKST_StaffOps.KITS = {
    Tools = { {"Base.Hammer", 1}, {"Base.Saw", 1}, {"Base.Screwdriver", 1}, {"Base.Nails", 50} },
    Medical = { {"Base.Bandage", 6}, {"Base.Disinfectant", 2}, {"Base.Pills", 3} },
    Food = { {"Base.TinnedBeans", 5}, {"Base.WaterBottleFull", 3} },
}

-- Local constants (do not alias IKST_ClimatePresets at load — require order can leave it nil).
IKST_StaffOps.CLIMATE = {
    desat = 0,
    night = 2,
    rain = 3,
    fog = 5,
    wind = 6,
    cloud = 8,
}

IKST_StaffOps.WEATHER = {
    Clear = { rain = 0, cloud = 0, fog = 0, wind = 0 },
    Rain = { rain = 0.6, cloud = 0.8, fog = 0.1, wind = 0.4 },
    Storm = { rain = 1.0, cloud = 1.0, fog = 0.2, wind = 0.85 },
    Fog = { rain = 0, cloud = 0.4, fog = 0.85, wind = 0.1 },
}

function IKST_StaffOps.ensureClimatePresets()
    if IKST_ClimatePresets then
        return IKST_ClimatePresets
    end
    require "IKST_ClimatePresets"
    return IKST_ClimatePresets
end

function IKST_StaffOps.teleportPlayer(player, x, y, z)
    if not player then
        return
    end
    z = tonumber(z) or 0
    local vehicle = player.getVehicle and player:getVehicle()
    if vehicle and vehicle.exit then
        vehicle:exit(player)
    end
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    if player.setLx then
        player:setLx(x)
        player:setLy(y)
    end
    if player.setLz then
        player:setLz(z)
    end
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
            if player and player.getOnlineID and player:getOnlineID() == id then
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

function IKST_StaffOps.toggleGod(player)
    if not player or not player.isGodMod or not player.setGodMod then
        return false, "unavailable"
    end
    local on = not player:isGodMod()
    player:setGodMod(on)
    if player.setInvincible then
        player:setInvincible(on)
    end
    return true, on and "God ON" or "God OFF"
end

function IKST_StaffOps.toggleInvisible(player)
    if not player or not player.isInvisible or not player.setInvisible then
        return false, "unavailable"
    end
    local on = not player:isInvisible()
    player:setInvisible(on)
    return true, on and "Invisible ON" or "Invisible OFF"
end

function IKST_StaffOps.toggleGhost(player)
    if not player or not player.isGhostMode or not player.setGhostMode then
        return false, "unavailable"
    end
    local on = not player:isGhostMode()
    player:setGhostMode(on)
    if player.setNoClip then
        player:setNoClip(on)
    end
    return true, on and "Ghost ON" or "Ghost OFF"
end

function IKST_StaffOps.giveItem(player, itemType, count)
    if not player or not player.getInventory then
        return false, "no player"
    end
    if not IKST_Args then
        require "IKST_Args"
    end
    itemType = IKST_Args.readItemType({ type = itemType }, "type") or "Base.Axe"
    count = IKST_Args.readAmount({ count = count }, "count", 1, 100) or 1
    local inv = player:getInventory()
    local given = 0
    for _ = 1, count do
        if inv:AddItem(itemType) then
            given = given + 1
        end
    end
    if given > 0 then
        return true, "Gave " .. given .. " x " .. itemType
    end
    return false, "give failed"
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
            if inv:AddItem(itemType) then
                n = n + 1
            end
        end
    end
    return n > 0, kitName .. ": " .. n .. " items"
end

function IKST_StaffOps.climateMgr()
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.climateMgr then
        return cp.climateMgr()
    end
    return nil
end

function IKST_StaffOps.transmitClimate()
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.transmitClimate then
        cp.transmitClimate()
    end
end

function IKST_StaffOps.setClimateFloat(idx, value)
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.setClimateFloat then
        return cp.setClimateFloat(idx, value)
    end
    return false
end

function IKST_StaffOps.releaseClimate()
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.releaseClimate then
        return cp.releaseClimate()
    end
    return false
end

function IKST_StaffOps.setWeather(presetName)
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession()
        and type(isClient) == "function" and not isClient() then
        return false, "weather runs on admin client in MP"
    end
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.applyPreset then
        return cp.applyPreset(presetName)
    end
    return false, "climate unavailable"
end

function IKST_StaffOps.clearWeather()
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession()
        and type(isClient) == "function" and not isClient() then
        return false, "weather runs on admin client in MP"
    end
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.clearWeather then
        return cp.clearWeather()
    end
    return false, "climate unavailable"
end

function IKST_StaffOps.setTime(hour)
    hour = tonumber(hour)
    if not hour then
        return false, "no hour"
    end
    if hour < 0 then
        hour = 0
    elseif hour >= 24 then
        hour = 23.99
    end
    local gt = getGameTime and getGameTime()
    if not gt or not gt.setTimeOfDay then
        return false, "no game time"
    end
    gt:setTimeOfDay(hour)
    if gt.updateCalendar and gt.getYear and gt.getMonth and gt.getDay then
        gt:updateCalendar(gt:getYear(), gt:getMonth(), gt:getDay(), math.floor(hour), math.floor((hour % 1) * 60))
    end
    return true, string.format("Time %02d:%02d", math.floor(hour), math.floor((hour % 1) * 60))
end

function IKST_StaffOps.clearZombies(player, radius)
    local cell = getCell and getCell()
    if not cell or not cell.getZombieList then
        return false, "no cell"
    end
    local zlist = cell:getZombieList()
    if not zlist or not zlist.size then
        return false, "no zombies"
    end
    radius = tonumber(radius)
    if radius and radius <= 0 then
        radius = nil
    end
    local px = player and player:getX() or 0
    local py = player and player:getY() or 0
    local removed = 0
    for i = zlist:size() - 1, 0, -1 do
        local z = zlist:get(i)
        if z then
            local hit = true
            if radius then
                local dx = z:getX() - px
                local dy = z:getY() - py
                hit = (dx * dx + dy * dy) <= (radius * radius)
            end
            if hit then
                if z.removeFromWorld then
                    z:removeFromWorld()
                end
                if z.removeFromSquare then
                    z:removeFromSquare()
                end
                removed = removed + 1
            end
        end
    end
    return true, "Removed " .. removed .. " zombies"
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
    local myId = player.getOnlineID and player:getOnlineID()
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
    if not IKST_Identity or not IKST_Identity.reissueIdCard then
        return false, "identity module missing"
    end
    local ok, msg = IKST_Identity.reissueIdCard(player, { recordCooldown = false, bumpSerial = true, notifyPlayer = true })
    return ok, msg or (ok and "ID reissued" or "reissue failed")
end

function IKST_StaffOps.handle(command, player, args)
    args = args or {}

    if command == IKST.CMD.healSelf then
        return IKST_StaffOps.heal(player)
    end
    if command == IKST.CMD.feedSelf then
        return IKST_StaffOps.feed(player)
    end
    if command == IKST.CMD.cureSelf then
        return IKST_StaffOps.cure(player)
    end
    if command == IKST.CMD.godSelf then
        return IKST_StaffOps.toggleGod(player)
    end
    if command == IKST.CMD.invisSelf then
        return IKST_StaffOps.toggleInvisible(player)
    end
    if command == IKST.CMD.ghostSelf then
        return IKST_StaffOps.toggleGhost(player)
    end
    if command == IKST.CMD.tpCoords then
        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z) or 0
        if not x or not y then
            return false, "enter X and Y"
        end
        IKST_StaffOps.teleportPlayer(player, x, y, z)
        return true, string.format("TP %d,%d,%d", math.floor(x), math.floor(y), math.floor(z))
    end
    if command == IKST.CMD.giveItem then
        return IKST_StaffOps.giveItem(player, args.type, args.count)
    end
    if command == IKST.CMD.giveKit then
        return IKST_StaffOps.giveKit(player, args.kit)
    end
    if command == IKST.CMD.setTime then
        return IKST_StaffOps.setTime(args.hour)
    end
    if command == IKST.CMD.setWeather then
        return IKST_StaffOps.setWeather(args.preset)
    end
    if command == IKST.CMD.clearWeather then
        return IKST_StaffOps.clearWeather()
    end
    if command == IKST.CMD.clearZombies then
        return IKST_StaffOps.clearZombies(player, args.radius)
    end
    if command == IKST.CMD.economyGive then
        if not IKST_EconomyBridge or not IKST_EconomyBridge.giveMoney then
            return false, "enable Economy addon + PhoneShop"
        end
        return IKST_EconomyBridge.giveMoney(player, args.amount)
    end
    if command == IKST.CMD.economyBalance then
        if IKST_EconomyOps and IKST_EconomyOps.sendSnapshot then
            IKST_EconomyOps.sendSnapshot(player)
            return true, "Balance updated"
        end
        if not IKST_EconomyBridge or not IKST_EconomyBridge.getBalance then
            return false, "enable Economy addon + PhoneShop"
        end
        local bal = IKST_EconomyBridge.getBalance(player)
        if IKST_Economy and IKST_Economy.formatAmount then
            return true, "Balance: " .. IKST_Economy.formatAmount(bal)
        end
        return true, "Balance: " .. tostring(bal)
    end

    if command == IKST.CMD.economyReissueId then
        if not IKST_Access or not IKST_Access.canUseTools or not IKST_Access.canUseTools(player) then
            return false, "admin only"
        end
        return IKST_StaffOps.reissueBankId(player)
    end
    if command == IKST.CMD.economyReissueIdTarget then
        if not IKST_Access or not IKST_Access.canUseTools or not IKST_Access.canUseTools(player) then
            return false, "admin only"
        end
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.reissueBankId(target)
        local label = IKST_StaffOps.playerLabel(target)
        if ok then
            return true, (msg or "ID reissued") .. " -> " .. label
        end
        return false, (msg or "reissue failed") .. " (" .. label .. ")"
    end

    if command == IKST.CMD.healTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.heal(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.bringTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        IKST_StaffOps.teleportPlayer(target, player:getX(), player:getY(), player:getZ())
        return true, "Brought " .. IKST_StaffOps.playerLabel(target)
    end
    if command == IKST.CMD.tpToTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        IKST_StaffOps.teleportPlayer(player, target:getX(), target:getY(), target:getZ())
        return true, "TP to " .. IKST_StaffOps.playerLabel(target)
    end
    if command == IKST.CMD.giveTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.giveItem(target, args.type, args.count)
        return ok, msg .. " -> " .. IKST_StaffOps.playerLabel(target)
    end
    if command == IKST.CMD.economyGiveTarget then
        if not IKST_EconomyBridge or not IKST_EconomyBridge.giveMoney then
            return false, "enable Economy addon + PhoneShop"
        end
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_EconomyBridge.giveMoney(target, args.amount)
        return ok, msg .. " -> " .. IKST_StaffOps.playerLabel(target)
    end

    if command == IKST.CMD.healAll then
        return IKST_StaffOps.healAll()
    end
    if command == IKST.CMD.feedAll then
        return IKST_StaffOps.feedAll()
    end
    if command == IKST.CMD.cureAll then
        return IKST_StaffOps.cureAll()
    end
    if command == IKST.CMD.tpAllToMe then
        return IKST_StaffOps.tpAllToMe(player)
    end
    if command == IKST.CMD.saveWaypoint then
        return IKST_Waypoints.save(player, args and args.name)
    end
    if command == IKST.CMD.delWaypoint then
        return IKST_Waypoints.delete(args and args.name)
    end
    if command == IKST.CMD.tpWaypoint then
        local wp = IKST_Waypoints.find(args and args.name)
        if not wp then
            return false, "no such waypoint"
        end
        IKST_StaffOps.teleportPlayer(player, wp.x, wp.y, wp.z)
        return true, "TP '" .. wp.name .. "'"
    end
    if command == IKST.CMD.feedTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.feed(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.cureTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.cure(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.godTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.toggleGod(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end

    return false, "unknown staff command"
end
