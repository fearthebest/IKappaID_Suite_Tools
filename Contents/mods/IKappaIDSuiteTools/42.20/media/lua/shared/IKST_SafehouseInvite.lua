-- Safehouse member invites (SE-style Accept/Decline). Server-authoritative pending list.
-- Not fully transmitted ModData — invitee gets deliverClientCommand payloads.

require "IKST_Shared"
require "IKST_Identity"

IKST_SafehouseInvite = IKST_SafehouseInvite or {}
IKST_SafehouseInvite.KEY = "IKST.SafehouseInvites"

function IKST_SafehouseInvite.store()
    local data = ModData.getOrCreate(IKST_SafehouseInvite.KEY)
    data.byInvitee = data.byInvitee or {}
    return data
end

function IKST_SafehouseInvite.inviteeKey(username)
    if not username or username == "" then
        return nil
    end
    return string.lower(tostring(username))
end

function IKST_SafehouseInvite.boundsMatch(a, b)
    if not a or not b then
        return false
    end
    return math.floor(tonumber(a.x) or 0) == math.floor(tonumber(b.x) or 0)
        and math.floor(tonumber(a.y) or 0) == math.floor(tonumber(b.y) or 0)
        and math.floor(tonumber(a.w) or 0) == math.floor(tonumber(b.w) or 0)
        and math.floor(tonumber(a.h) or 0) == math.floor(tonumber(b.h) or 0)
end

function IKST_SafehouseInvite.listForInvitee(username)
    local key = IKST_SafehouseInvite.inviteeKey(username)
    if not key then
        return {}
    end
    local data = IKST_SafehouseInvite.store()
    local rows = data.byInvitee[key]
    if type(rows) ~= "table" then
        return {}
    end
    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        if row and row.x ~= nil and row.y ~= nil and row.w and row.h then
            out[#out + 1] = row
        end
    end
    return out
end

function IKST_SafehouseInvite.addPending(inviteeUsername, entry)
    local key = IKST_SafehouseInvite.inviteeKey(inviteeUsername)
    if not key or not entry then
        return false, "bad invite"
    end
    local data = IKST_SafehouseInvite.store()
    local list = data.byInvitee[key]
    if type(list) ~= "table" then
        list = {}
        data.byInvitee[key] = list
    end
    for i = 1, #list do
        if IKST_SafehouseInvite.boundsMatch(list[i], entry) then
            list[i] = entry
            return true, "updated"
        end
    end
    if #list >= 8 then
        return false, "too many invites"
    end
    list[#list + 1] = entry
    return true, "invited"
end

function IKST_SafehouseInvite.removePending(inviteeUsername, bounds)
    local key = IKST_SafehouseInvite.inviteeKey(inviteeUsername)
    if not key then
        return false
    end
    local data = IKST_SafehouseInvite.store()
    local list = data.byInvitee[key]
    if type(list) ~= "table" then
        return false
    end
    local kept = {}
    local removed = false
    for i = 1, #list do
        if IKST_SafehouseInvite.boundsMatch(list[i], bounds) then
            removed = true
        else
            kept[#kept + 1] = list[i]
        end
    end
    data.byInvitee[key] = kept
    if #kept == 0 then
        data.byInvitee[key] = nil
    end
    return removed
end
