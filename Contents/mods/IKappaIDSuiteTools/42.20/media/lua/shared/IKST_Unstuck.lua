-- Player unstuck: find free nearby tile (server-authoritative).

require "IKST_Shared"
require "IKST_Access"
require "IKST_Authority"
require "IKST_Grid"
require "IKST_Policy"
require "IKST_SafeHouse"
require "IKST_SafehouseClaim"
require "IKST_ClaimSocial"

IKST_Unstuck = IKST_Unstuck or {}

function IKST_Unstuck.cooldownMs()
    if IKST_Access and type(IKST_Access.sandboxInt) == "function" then
        return IKST_Access.sandboxInt("UnstuckCooldownSec", 300, 60, 3600) * 1000
    end
    return 300000
end

function IKST_Unstuck.enabled()
    if IKST_Access and type(IKST_Access.sandboxBool) == "function" then
        return IKST_Access.sandboxBool("UnstuckEnabled", false)
    end
    return false
end

local function nowMs()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimeInMillis) == "function" then
        return getTimeInMillis()
    end
    return 0
end

local function squareWalkable(sq)
    if not sq then
        return false
    end
    if type(sq.isSolid) == "function" and sq:isSolid() then
        return false
    end
    if type(sq.isSolidTrans) == "function" and sq:isSolidTrans() then
        return false
    end
    if type(sq.Has) == "function" and IsoFlagType then
        if IsoFlagType.collideN and sq:Has(IsoFlagType.collideN) then
            return false
        end
        if IsoFlagType.collideW and sq:Has(IsoFlagType.collideW) then
            return false
        end
    end
    if type(sq.isVehicleIntersecting) == "function" and sq:isVehicleIntersecting() then
        return false
    end
    return true
end

-- Reject protected tiles and other players' safehouses/claims.
function IKST_Unstuck.destinationAllowed(player, x, y, z)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = tonumber(z) or 0
    if not player then
        return false, "no player"
    end
    if IKST_Policy and type(IKST_Policy.tileBlockReason) == "function" then
        local tileReason = IKST_Policy.tileBlockReason(x, y, z, player, "claim")
        if tileReason then
            return false, tileReason
        end
    end
    local square = nil
    if IKST_Grid and type(IKST_Grid.getSquare) == "function" then
        square = IKST_Grid.getSquare(x, y, z)
    end
    if not square then
        return false, "no square"
    end
    if IKST_SafeHouse and type(IKST_SafeHouse.atSquare) == "function" then
        local sh = IKST_SafeHouse.atSquare(square)
        if sh then
            local allowed = false
            if IKST_SafehouseClaim and type(IKST_SafehouseClaim.playerOwnsVanillaSafehouse) == "function"
                and IKST_SafehouseClaim.playerOwnsVanillaSafehouse(player, sh) then
                allowed = true
            end
            if not allowed and IKST_ClaimSocial and type(IKST_ClaimSocial.safehouseHasMember) == "function" then
                local username = IKST_ClaimSocial.username(player)
                if username and IKST_ClaimSocial.safehouseHasMember(sh, username) then
                    allowed = true
                end
            end
            if not allowed and IKST_Policy and type(IKST_Policy.staffClaimBypass) == "function"
                and IKST_Policy.staffClaimBypass(player) then
                allowed = true
            end
            if not allowed then
                return false, "not_your_claim"
            end
        end
    end
    if IKST_SafehouseClaim and type(IKST_SafehouseClaim.entryForSquare) == "function" then
        local entry = select(1, IKST_SafehouseClaim.entryForSquare(square))
        if entry then
            if type(IKST_SafehouseClaim.isEntryExpired) == "function"
                and IKST_SafehouseClaim.isEntryExpired(entry) then
                return true, nil
            end
            local allowed = false
            if type(IKST_SafehouseClaim.isOwner) == "function" and IKST_SafehouseClaim.isOwner(entry, player) then
                allowed = true
            end
            if not allowed and type(IKST_SafehouseClaim.canAtSquare) == "function"
                and IKST_SafehouseClaim.canAtSquare(player, square, "build") == true then
                allowed = true
            end
            if not allowed and IKST_Policy and type(IKST_Policy.staffClaimBypass) == "function"
                and IKST_Policy.staffClaimBypass(player) then
                allowed = true
            end
            if not allowed then
                return false, "not_your_claim"
            end
        end
    end
    return true, nil
end

function IKST_Unstuck.findFreeTile(player, maxRing)
    if not player or type(player.getX) ~= "function" then
        return nil
    end
    -- Keep unstuck local (adjacent tiles only) so it cannot be used as a warp.
    maxRing = tonumber(maxRing) or 2
    if maxRing > 2 then
        maxRing = 2
    end
    if maxRing < 1 then
        maxRing = 1
    end
    local cx = math.floor(player:getX())
    local cy = math.floor(player:getY())
    local cz = player:getZ() or 0
    if type(getCell) ~= "function" then
        return nil
    end
    local cell = getCell()
    if not cell or type(cell.getGridSquare) ~= "function" then
        return nil
    end
    for ring = 1, maxRing do
        for dx = -ring, ring do
            for dy = -ring, ring do
                if math.abs(dx) == ring or math.abs(dy) == ring then
                    local tx, ty = cx + dx, cy + dy
                    local sq = cell:getGridSquare(tx, ty, cz)
                    if squareWalkable(sq) then
                        local ok = IKST_Unstuck.destinationAllowed(player, tx, ty, cz)
                        if ok then
                            return tx, ty, cz
                        end
                    end
                end
            end
        end
    end
    return nil
end

function IKST_Unstuck.apply(player)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST_Unstuck.enabled() then
        return false, "unstuck disabled"
    end
    if not player then
        return false, "no player"
    end
    local md = nil
    if type(player.getModData) == "function" then
        md = player:getModData()
    end
    if not md then
        return false, "no modData"
    end
    local now = nowMs()
    local untilMs = tonumber(md.IKST_unstuckUntil) or 0
    if untilMs > now then
        local wait = math.ceil((untilMs - now) / 1000)
        return false, "cooldown " .. tostring(wait) .. "s"
    end
    local tx, ty, tz = IKST_Unstuck.findFreeTile(player, 8)
    if not tx then
        return false, "no free tile nearby"
    end
    local destOk, destReason = IKST_Unstuck.destinationAllowed(player, tx, ty, tz)
    if not destOk then
        return false, destReason or "destination blocked"
    end
    if IKST_StaffOps and type(IKST_StaffOps.teleportPlayer) == "function" then
        IKST_StaffOps.teleportPlayer(player, tx, ty, tz)
    elseif type(player.setX) == "function" and type(player.setY) == "function" then
        player:setX(tx + 0.5)
        player:setY(ty + 0.5)
        if type(player.setZ) == "function" then
            player:setZ(tz)
        end
    else
        return false, "teleport unavailable"
    end
    md.IKST_unstuckUntil = now + IKST_Unstuck.cooldownMs()
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "unstuck", tx .. "," .. ty .. "," .. tz, true)
    end
    return true, "unstuck to " .. tx .. "," .. ty
end
