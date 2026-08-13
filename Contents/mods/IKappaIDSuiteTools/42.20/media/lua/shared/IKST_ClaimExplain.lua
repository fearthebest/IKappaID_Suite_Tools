-- Claim block explanations (shared preview + UI). Server still re-validates on claim.
-- Zombie/player counts use IsoCell.getZombieList / online players (JavaDocs), not getObjectList.

require "IKST_Shared"

IKST_ClaimExplain = IKST_ClaimExplain or {}

local BUFFER = 2

local function inRect(ox, oy, x, y, x2, y2)
    return ox >= x and ox < x2 and oy >= y and oy < y2
end

local function forEachJavaList(list, visitor)
    if not list or type(list.size) ~= "function" or type(list.get) ~= "function" then
        return
    end
    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if item then
            visitor(item)
        end
    end
end

function IKST_ClaimExplain.countInRect(x, y, w, h, player)
    x = math.floor(tonumber(x) or 0) - BUFFER
    y = math.floor(tonumber(y) or 0) - BUFFER
    w = math.floor(tonumber(w) or 1) + BUFFER * 2
    h = math.floor(tonumber(h) or 1) + BUFFER * 2
    local x2 = x + w
    local y2 = y + h
    local zombies, players = 0, 0
    local cell = type(getCell) == "function" and getCell() or nil
    if cell and type(cell.getZombieList) == "function" then
        forEachJavaList(cell:getZombieList(), function(zombie)
            if type(zombie.getX) == "function" and type(zombie.getY) == "function" then
                if inRect(zombie:getX(), zombie:getY(), x, y, x2, y2) then
                    zombies = zombies + 1
                end
            end
        end)
    end
    local function countPlayer(p)
        if not p or p == player then
            return
        end
        if type(p.getX) ~= "function" or type(p.getY) ~= "function" then
            return
        end
        if inRect(p:getX(), p:getY(), x, y, x2, y2) then
            players = players + 1
        end
    end
    if type(getOnlinePlayers) == "function" then
        forEachJavaList(getOnlinePlayers(), countPlayer)
    end
    if players == 0 and type(getSpecificPlayer) == "function" then
        countPlayer(getSpecificPlayer(0))
    end
    local inside = false
    if player and type(player.getX) == "function" then
        local px, py = player:getX(), player:getY()
        if inRect(px, py, x, y, x2, y2) then
            local sq = type(player.getCurrentSquare) == "function" and player:getCurrentSquare() or nil
            if sq and type(sq.isOutside) == "function" then
                inside = not sq:isOutside()
            elseif sq and type(sq.Has) == "function" and IsoFlagType and IsoFlagType.exterior then
                inside = not sq:Has(IsoFlagType.exterior)
            else
                inside = true
            end
        end
    end
    return zombies, players, inside
end

function IKST_ClaimExplain.linesForRect(player, x, y, w, h)
    local lines = {}
    local zombies, players, inside = IKST_ClaimExplain.countInRect(x, y, w, h, player)
    if zombies > 0 then
        lines[#lines + 1] = IKST.text("IGUI_IKST_ClaimTip_Zombies", "Zombies in zone") .. ": " .. tostring(zombies)
    end
    if players > 0 then
        lines[#lines + 1] = IKST.text("IGUI_IKST_ClaimTip_Players", "Other players in zone") .. ": " .. tostring(players)
    end
    if not inside then
        lines[#lines + 1] = IKST.text("IGUI_IKST_ClaimTip_StandInside", "Stand inside the building to claim")
    end
    if #lines == 0 then
        lines[#lines + 1] = IKST.text("IGUI_IKST_ClaimTip_AllClear", "Area looks clear for a claim attempt")
    end
    return lines, zombies, players, inside
end

function IKST_ClaimExplain.summaryForRect(player, x, y, w, h)
    local lines = IKST_ClaimExplain.linesForRect(player, x, y, w, h)
    return table.concat(lines, " · ")
end
