-- Zombie kill bounty — server JVM only (OnHitZombie / OnZombieDead).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Economy"
require "IKST_EconomyBridge"
require "IKST_EconomyOps"

IKST_EconomyBounty = IKST_EconomyBounty or {}

local MD_HIT = "IKST_bountyHitBy"
local MD_HIT_TIME = "IKST_bountyHitAt"
local MD_PAID = "IKST_bountyPaid"
local HIT_WINDOW_MS = 120000

local function nowMs()
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

local function rollChance()
    local chance = IKST_Economy.zombieBountyChance()
    if chance <= 0 then
        return false
    end
    if chance >= 100 then
        return true
    end
    if not ZombRand then
        return false
    end
    return ZombRand(100) < chance
end

local function rollAmount()
    local minA = IKST_Economy.zombieBountyMin()
    local maxA = IKST_Economy.zombieBountyMax()
    if maxA < minA then
        maxA = minA
    end
    if maxA <= 0 then
        return 0
    end
    if minA == maxA then
        return minA
    end
    if not ZombRand then
        return minA
    end
    return ZombRand(minA, maxA + 1)
end

local function killerFromAccountKey(accountKey)
    if not accountKey or accountKey == "" then
        return nil
    end
    local online = IKST_EconomyOps.findPlayerByAccountKey(accountKey)
    if online then
        return online
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return nil
    end
    if getSpecificPlayer then
        local p = getSpecificPlayer(0)
        if p and IKST_Economy.accountKey(p) == accountKey then
            return p
        end
    end
    return nil
end

local function resolveKiller(zombie)
    if not zombie then
        return nil
    end
    if zombie.getAttacker then
        local att = zombie:getAttacker()
        if att and instanceof(att, "IsoPlayer") then
            return att
        end
    end
    local md = zombie:getModData()
    if not md or not md[MD_HIT] then
        return nil
    end
    local hitAt = tonumber(md[MD_HIT_TIME]) or 0
    if nowMs() - hitAt > HIT_WINDOW_MS then
        return nil
    end
    return killerFromAccountKey(md[MD_HIT])
end

local function payBounty(player, amount)
    if IKST_Economy.zombieBountyToBank() then
        IKST_Economy.addBank(player, amount)
        return
    end
    if IKST_EconomyBridge.giveCash(player, amount) then
        return
    end
    IKST_Economy.addBank(player, amount)
end

local function bountyMessage(amount)
    local fmt = IKST.text("IGUI_IKST_Economy_BountyKill", "Zombie bounty: %1")
    return string.gsub(fmt, "%%1", IKST_Economy.formatAmount(amount))
end

function IKST_EconomyBounty.onHitZombie(zombie, attacker)
    if type(isServer) == "function" and type(isClient) == "function" and isClient() and not isServer() then
        return
    end
    if not IKST_Economy.zombieBountyEnabled() then
        return
    end
    if not zombie or not attacker then
        return
    end
    if not instanceof(attacker, "IsoPlayer") then
        return
    end
    if not zombie.getModData then
        return
    end
    local md = zombie:getModData()
    if not md then
        return
    end
    local accountKey = IKST_Identity.accountKey(attacker)
    md[MD_HIT] = accountKey
    md[MD_HIT_TIME] = nowMs()
end

function IKST_EconomyBounty.onZombieDead(zombie)
    if not IKST_Economy.zombieBountyEnabled() then
        return
    end
    if not zombie or not zombie.getModData then
        return
    end
    local md = zombie:getModData()
    if not md or md[MD_PAID] then
        return
    end
    md[MD_PAID] = true

    local killer = resolveKiller(zombie)
    if not killer then
        return
    end
    if not rollChance() then
        return
    end
    local amount = rollAmount()
    if amount <= 0 then
        return
    end
    payBounty(killer, amount)
    IKST.notify(killer, bountyMessage(amount), true)
end

if Events and Events.OnHitZombie and Events.OnHitZombie.Add then
    Events.OnHitZombie.Add(IKST_EconomyBounty.onHitZombie)
end
if Events and Events.OnZombieDead and Events.OnZombieDead.Add then
    Events.OnZombieDead.Add(IKST_EconomyBounty.onZombieDead)
end
