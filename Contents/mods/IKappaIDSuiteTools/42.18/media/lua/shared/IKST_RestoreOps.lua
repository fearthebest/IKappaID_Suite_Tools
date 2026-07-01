-- Rich character snapshot for recovery journal (skills, traits, recipes).

require "IKST_Shared"
require "IKST_ClaimPolicy"

IKST_RestoreOps = IKST_RestoreOps or {}

IKST_RestoreOps.PARENT_PERKS = {
    Agility = true, Passiv = true, Survivalist = true,
    Crafting = true, Firearm = true, Combat = true,
}

function IKST_RestoreOps.journalEnabled()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteTools
    if not sv or sv.RecoveryJournalEnabled == nil then
        return true
    end
    return sv.RecoveryJournalEnabled == true
end

function IKST_RestoreOps.username(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getDisplayName then
        local name = player:getDisplayName()
        if name and name ~= "" then
            return name
        end
    end
    return nil
end

function IKST_RestoreOps.eachPerk(visitor)
    if not PerkFactory or not PerkFactory.PerkList or not visitor then
        return
    end
    local list = PerkFactory.PerkList
    if list.size and list.get then
        for i = 0, list:size() - 1 do
            local perk = list:get(i)
            if perk then
                visitor(perk)
            end
        end
    end
end

function IKST_RestoreOps.perkId(perk)
    if not perk then
        return nil
    end
    if perk.getId then
        return perk:getId()
    end
    if perk.getType then
        return perk:getType()
    end
    return tostring(perk)
end

function IKST_RestoreOps.capturePlayer(player)
    if not player then
        return nil
    end
    local snap = {
        version = 1,
        username = IKST_RestoreOps.username(player),
        time = getGameTime and getGameTime() and getGameTime().getWorldAgeHours and getGameTime():getWorldAgeHours() or 0,
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        skills = {},
        traits = {},
        recipes = {},
        books = {},
    }

    local xp = player.getXp and player:getXp() or nil
    IKST_RestoreOps.eachPerk(function(perk)
        local perkId = IKST_RestoreOps.perkId(perk)
        if perkId and not IKST_RestoreOps.PARENT_PERKS[perkId] then
            local level = player.getPerkLevel and player:getPerkLevel(perk) or 0
            local currentXP = 0
            if xp and xp.getXP then
                currentXP = xp:getXP(perk) or 0
            end
            snap.skills[#snap.skills + 1] = {
                id = perkId,
                level = level,
                xp = currentXP,
            }
        end
    end)

    if player.getTraits then
        local traits = player:getTraits()
        if traits and traits.size and traits.get then
            for i = 0, traits:size() - 1 do
                local trait = traits:get(i)
                if trait then
                    snap.traits[#snap.traits + 1] = tostring(trait)
                end
            end
        end
    end

    if player.getKnownRecipes then
        local recipes = player:getKnownRecipes()
        if recipes and recipes.size and recipes.get then
            for i = 0, recipes:size() - 1 do
                local recipe = recipes:get(i)
                if recipe then
                    snap.recipes[#snap.recipes + 1] = tostring(recipe)
                end
            end
        elseif type(recipes) == "table" then
            for _, recipe in ipairs(recipes) do
                snap.recipes[#snap.recipes + 1] = tostring(recipe)
            end
        end
    end

    if player.getAlreadyReadBook then
        local books = player:getAlreadyReadBook()
        if books and books.size and books.get then
            for i = 0, books:size() - 1 do
                local book = books:get(i)
                if book then
                    snap.books[#snap.books + 1] = tostring(book)
                end
            end
        end
    end

    if player.getBodyDamage then
        local bd = player:getBodyDamage()
        snap.health = bd.getOverallBodyHealth and bd:getOverallBodyHealth() or 100
        snap.infected = bd.IsInfected and bd:IsInfected() or false
    end

    if player.getStats and CharacterStat then
        local st = player:getStats()
        if st and st.get then
            snap.hunger = st:get(CharacterStat.HUNGER) or 0
            snap.thirst = st:get(CharacterStat.THIRST) or 0
        end
    end

    if player.getModData then
        local md = player:getModData()
        snap.caught = md.IKST_caught == true
    end

    return snap
end

function IKST_RestoreOps.perkFromId(perkId)
    if not perkId or not Perks or not Perks.FromString then
        return nil
    end
    return Perks.FromString(perkId)
end

function IKST_RestoreOps.setPerkLevel(player, perkId, level)
    local perk = IKST_RestoreOps.perkFromId(perkId)
    if not perk or not player or not player.getPerkLevel then
        return
    end
    local maxLevel = IKST.RESTORE_MAX_PERK_LEVEL or 10
    level = math.max(0, math.min(maxLevel, math.floor(tonumber(level) or 0)))
    while player:getPerkLevel(perk) < level do
        if player.LevelPerk then
            player:LevelPerk(perk, false)
        else
            break
        end
    end
    while player:getPerkLevel(perk) > level do
        if player.LoseLevel then
            player:LoseLevel(perk)
        else
            break
        end
    end
    local xp = player.getXp and player:getXp() or nil
    if xp and xp.setXPToLevel then
        xp:setXPToLevel(perk, level)
    end
end

function IKST_RestoreOps.applySnapshot(player, snap)
    if not player or not snap then
        return false, "no snapshot"
    end

    if IKST_StaffOps then
        if IKST_StaffOps.heal then
            IKST_StaffOps.heal(player)
        end
        if IKST_StaffOps.feed then
            IKST_StaffOps.feed(player)
        end
        if snap.infected and IKST_StaffOps.cure then
            IKST_StaffOps.cure(player)
        end
        if snap.x and IKST_StaffOps.teleportPlayer then
            IKST_StaffOps.teleportPlayer(player, snap.x, snap.y, snap.z or 0)
        end
    end

    for _, row in ipairs(snap.skills or {}) do
        if row.id then
            IKST_RestoreOps.setPerkLevel(player, row.id, row.level or 0)
        end
    end

    if player.getTraits then
        local traits = player:getTraits()
        if traits and traits.clear then
            traits:clear()
        end
        for _, traitId in ipairs(snap.traits or {}) do
            if traits and traits.add then
                traits:add(traitId)
            end
        end
    end

    if player.getKnownRecipes and snap.recipes then
        for _, recipeId in ipairs(snap.recipes) do
            if player.learnRecipe then
                player:learnRecipe(recipeId)
            end
        end
    end

    return true, "restored from journal"
end

function IKST_RestoreOps.snapshotOnItem(item, snap)
    if not item or not snap or not item.getModData then
        return false
    end
    local md = item:getModData()
    md.IKST_restoreSnapshot = snap
    if item.transmitModData then
        item:transmitModData()
    end
    return true
end

function IKST_RestoreOps.snapshotFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    return md.IKST_restoreSnapshot
end

function IKST_RestoreOps.isJournalItem(item)
    return item and item.getFullType and item:getFullType() == IKST.JOURNAL_TYPE
end

function IKST_RestoreOps.findItemById(player, itemId)
    if not player or not itemId or not player.getInventory then
        return nil
    end
    local inv = player:getInventory()
    if not inv or not inv.getItemById then
        return nil
    end
    return inv:getItemById(itemId)
end
