if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextBox"
require "IKST_Confirm"
require "IKST_Shared"
require "IKST_Claim"
require "IKST_ClaimRequestDraw"
require "IKST_VehicleClaim"
require "IKST_VehicleClaimClient"
require "IKST_VehicleClaimUI"
require "IKST_SafehouseClaimUI"
require "IKST_ClaimPermissionsUI"
require "IKST_SafehouseClaimClient"
require "IKST_SafehouseInviteClient"
require "IKST_SafehousePermissions"
require "IKST_ClaimExplain"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_ActionLog"
require "IKST_JobStaff"
require "IKST_JobLayout"
require "IKST_ClaimIcons"
require "IKST_ClaimPolicy"
require "IKST_Access"

IKST_JobGuard = IKST_JobGuard or {}

-- Safehouse list: one owner = IKST_SafehouseClaimClient (C3). Do not store a second copy.
IKST_JobGuard.claims = {}
IKST_JobGuard.players = {}

function IKST_JobGuard.getSafehouses()
    if IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.safehouses then
        return IKST_SafehouseClaimClient.safehouses
    end
    return {}
end

-- Overview list: server safehouses plus in-progress walk-draw draft (borders != claimed yet).
function IKST_JobGuard.overviewSafehouseRows(player)
    local rows = {}
    for _, sh in ipairs(IKST_JobGuard.getSafehouses() or {}) do
        local label = tostring(sh.title or sh.owner or "?")
        if sh.x and sh.y then
            label = label .. "  @ " .. tostring(sh.x) .. "," .. tostring(sh.y)
        end
        if sh.w and sh.h then
            label = label .. " " .. tostring(sh.w) .. "x" .. tostring(sh.h)
        end
        if sh.isMine == true then
            label = label .. "  [" .. IKST.text("IGUI_IKST_ClaimTile_Mine", "yours") .. "]"
        end
        rows[#rows + 1] = {
            id = IKST_JobGuard.safehouseId(sh),
            label = label,
            data = sh,
        }
    end
    if not player then
        return rows
    end
    local state = IKST.getPlayerState(player)
    if state and state.claimReqA then
        local a = state.claimReqA
        local draw = state.claimReqDraw
        local x = a.x
        local y = a.y
        local z = a.z or 0
        local w = 1
        local h = 1
        local ready = false
        if draw then
            w = draw.w or w
            h = draw.h or h
            x = draw.x or x
            y = draw.y or y
            z = draw.z or z
            ready = draw.ok == true
        end
        local prefix = IKST.text("IGUI_IKST_ClaimOverview_DraftRow", "Draft request")
        if ready then
            prefix = IKST.text("IGUI_IKST_ClaimOverview_DraftReady", "Draft ready — press Mark end")
        elseif draw and draw.reason == "too_small" then
            prefix = IKST.format("IGUI_IKST_ClaimOverview_DraftSmall",
                "Draft — keep walking (min {1})", tostring(IKST_Claim.MIN_DIM))
        end
        local draft = {
            draft = true,
            pending = true,
            x = x, y = y, z = z, w = w, h = h,
            ready = ready,
            title = prefix,
        }
        rows[#rows + 1] = {
            id = "_draft_walkdraw",
            label = prefix .. "  " .. tostring(w) .. "x" .. tostring(h) .. " @ " .. tostring(x) .. "," .. tostring(y),
            data = draft,
        }
    end
    return rows
end

function IKST_JobGuard.countOwnedSafehouses(player)
    local n = 0
    for _, sh in ipairs(IKST_JobGuard.getSafehouses() or {}) do
        if sh and sh.isMine == true then
            n = n + 1
        end
    end
    if n > 0 then
        return n
    end
    if IKST_SafehouseClaimClient and type(IKST_SafehouseClaimClient.mergeMissingOwnedRows) == "function" then
        IKST_SafehouseClaimClient.mergeMissingOwnedRows(player)
        for _, sh in ipairs(IKST_JobGuard.getSafehouses() or {}) do
            if sh and sh.isMine == true then
                n = n + 1
            end
        end
    end
    return n
end

function IKST_JobGuard.requestSafehouses(player)
    IKST.dispatchCommand(player, IKST.CMD.safehouseList, {})
end

function IKST_JobGuard.requestClaims(player)
    local showAll = IKST_Access and IKST_Access.canUseTools(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleClaimList, { all = showAll == true })
end

function IKST_JobGuard.requestNearbyVehicles(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleClaimNearby, {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = player:getZ(),
        radius = IKST.getVehicleNearRadius(),
    })
end

function IKST_JobGuard.resolveVehicleId(panel)
    if panel.guardSelectedClaimId then
        return panel.guardSelectedClaimId
    end
    if panel.guardVehicleId then
        return panel.guardVehicleId
    end
    if panel.selectedVehicleId then
        return panel.selectedVehicleId
    end
    local cache = IKST_JobVehicle and IKST_JobVehicle.listCache or {}
    if cache[1] then
        return cache[1].id
    end
    local p = panel and panel.player
    if p and type(p.getVehicle) == "function" then
        local v = p:getVehicle()
        if v and type(v.getId) == "function" and v:getId() ~= nil then
            return v:getId()
        end
    end
    return nil
end

function IKST_JobGuard.vehicleClaimArgs(panel)
    local targetId = IKST_JobGuard.resolveVehicleId(panel)
    if targetId == nil then
        return nil
    end
    local args = { vehicleId = targetId }
    local want = tostring(targetId)
    for _, row in ipairs(IKST_VehicleClaimClient and IKST_VehicleClaimClient.nearby or {}) do
        if tostring(row.id) == want or row.claimKey == want then
            if row.claimKey and row.claimKey ~= "" then
                args.claimKey = row.claimKey
            end
            break
        end
    end
    if not args.claimKey then
        for _, row in ipairs(IKST_VehicleClaimClient and IKST_VehicleClaimClient.claims or {}) do
            if tostring(row.id) == want or row.claimKey == want then
                if row.claimKey and row.claimKey ~= "" then
                    args.claimKey = row.claimKey
                end
                break
            end
        end
    end
    return args
end

function IKST_JobGuard.vehicleLabel(entry)
    if not entry then
        return "?"
    end
    local label = (entry.script or "?") .. " #" .. tostring(entry.id) .. " (" .. tostring(entry.distance or "?") .. "m)"
    if entry.claimed and entry.ownerLabel then
        label = label .. " [" .. tostring(entry.ownerLabel) .. "]"
    elseif entry.claimNote and entry.claimNote ~= "" then
        label = label .. " [" .. tostring(entry.claimNote) .. "]"
    end
    if entry.hoursRemainingText and entry.hoursRemainingText ~= "" then
        label = label .. " - " .. entry.hoursRemainingText
    end
    return label
end

function IKST_JobGuard.claimLineText(claim, isAdmin)
    if not claim then
        return "?"
    end
    local line = "#" .. tostring(claim.id) .. " " .. tostring(claim.displayLabel or claim.script or "?")
    if claim.hoursRemainingText and claim.hoursRemainingText ~= "" then
        line = line .. " - " .. claim.hoursRemainingText
    end
    if claim.x and claim.y then
        line = line .. " @ " .. claim.x .. "," .. claim.y
    end
    if isAdmin and claim.ownerLabel and not claim.isMine then
        line = line .. " [" .. claim.ownerLabel .. "]"
    end
    return line
end

-- C1: selection identity is bounds-first (matches ClaimClient / claim ModData keys).
-- Online safehouse id is payload only — used as a rematch fallback after refresh.
function IKST_JobGuard.safehouseId(sh)
    if not sh then
        return nil
    end
    local x = tonumber(sh.x)
    local y = tonumber(sh.y)
    local w = tonumber(sh.w)
    local h = tonumber(sh.h)
    if x ~= nil and y ~= nil and w and h and w > 0 and h > 0 then
        if IKST_SafehouseClaimClient and type(IKST_SafehouseClaimClient.boundsKey) == "function" then
            return IKST_SafehouseClaimClient.boundsKey(x, y, w, h)
        end
        return tostring(math.floor(x)) .. "_" .. tostring(math.floor(y)) .. "_"
            .. tostring(math.floor(w)) .. "_" .. tostring(math.floor(h))
    end
    if sh.id ~= nil then
        return "id:" .. tostring(sh.id)
    end
    return nil
end

function IKST_JobGuard.matchSafehouse(selected, list)
    if not selected then
        return nil
    end
    local sid = IKST_JobGuard.safehouseId(selected)
    if sid then
        for _, sh in ipairs(list or {}) do
            if IKST_JobGuard.safehouseId(sh) == sid then
                return sh
            end
        end
    end
    -- Rematch by online id only when bounds key could not pair (stale list shape).
    if selected.id ~= nil then
        local oid = tostring(selected.id)
        for _, sh in ipairs(list or {}) do
            if sh and sh.id ~= nil and tostring(sh.id) == oid then
                return sh
            end
        end
    end
    return nil
end

-- C2: SE selected=0 — rematch explicit selection only; never auto-pick isMine / first row.
function IKST_JobGuard.pickPreferredSafehouse(list, selected)
    return IKST_JobGuard.matchSafehouse(selected, list)
end

function IKST_JobGuard.placeSoftInvite(panel, parent, ax, ay, aw, ah, player)
    local inv = panel._ikstSoftInvite
    if not inv then
        return
    end
    local btnH = IKST_JobLayout.STANDARD_BTN_H or 28
    IKST_JobLayout.placePillGroup(panel, parent, ax, ay, aw, btnH, {
        {
            label = IKST.text("IGUI_IKST_Back", "Back"),
            onClick = function()
                panel._ikstSoftInvite = nil
                panel:refreshJobUI(true)
            end,
        },
    })
    local fieldY = ay + btnH + 6
    local fieldH = math.max(btnH, ah - btnH - 6)
    IKST_JobLayout.placeFieldActionCorner(panel, parent, ax, fieldY, aw, fieldH, {
        { text = panel:draftEntryText("guardInviteUserEntry", ""), fieldName = "guardInviteUserEntry" },
    }, IKST.text("IGUI_IKST_ClaimInvite_Send", "Send invite"), function()
        local name = ""
        if panel.guardInviteUserEntry and type(panel.guardInviteUserEntry.getText) == "function" then
            name = panel.guardInviteUserEntry:getText() or ""
        end
        name = string.gsub(tostring(name), "^%s*(.-)%s*$", "%1")
        if name == "" then
            IKST.notify(player, IKST.text("IGUI_IKST_VehicleClaim_UserRequired", "Enter a username."), false)
            return
        end
        IKST.dispatchCommand(player, IKST.CMD.safehouseInvite, {
            x = inv.x, y = inv.y, w = inv.w, h = inv.h, id = inv.id, owner = inv.owner,
            member = name,
        })
        panel._ikstSoftInvite = nil
        panel:refreshJobUI(true)
    end)
end

function IKST_JobGuard.safehouseActionPills(panel, p, isAdmin, isStaff, state)
    local actionItems = {}
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateSafehouseClaim and IKST_ClaimPolicy.mayCreateSafehouseClaim(p) then
        actionItems[#actionItems + 1] = {
            label = IKST.text("IGUI_IKST_Guard_SH_Claim", "Claim here"),
            primary = true,
            onClick = function()
                local owner = isAdmin and IKST_JobGuard.readEntry(panel.guardShOwnerEntry) or ""
                local w, h = IKST_JobGuard.applyShDimensions(panel, state)
                local here = IKST_JobGuard.coords(p)
                IKST.dispatchCommand(p, IKST.CMD.safehouseClaim, {
                    x = here.x, y = here.y, z = here.z,
                    size = state.guardShSize,
                    w = w,
                    h = h,
                    owner = owner,
                    claimMode = state.guardShClaimMode or IKST_Claim.MODE.square,
                })
                IKST_JobGuard.requestSafehouses(p)
            end,
        }
    elseif IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowSafehouseClaimRequest
        and IKST_ClaimPolicy.mayShowSafehouseClaimRequest(p) then
        local claimState = IKST.getPlayerState(p)
        local reqLabel = IKST.text("IGUI_IKST_ClaimTile_RequestHouse", "Request house")
        local reqPrimary = true
        if claimState and claimState.claimReqA then
            reqLabel = IKST.text("IGUI_IKST_ClaimTile_MarkEnd", "Mark end (B)")
        end
        actionItems[#actionItems + 1] = {
            label = reqLabel,
            primary = reqPrimary,
            onClick = function()
                IKST_JobGuard.onRequestClaimClick(panel)
            end,
        }
    end
    actionItems[#actionItems + 1] = {
        label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
        onClick = function()
            IKST_JobGuard.requestSafehouses(p)
        end,
    }
    if isStaff then
        actionItems[#actionItems + 1] = {
            label = IKST.text("IGUI_IKST_Guard_SH_Borders", "Borders"),
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.toggleSafehouseBorders, {})
            end,
        }
    end
    local sel = panel.guardSelectedSH
    if sel then
        actionItems[#actionItems + 1] = {
            label = IKST.text("IGUI_IKST_Guard_SH_Tp", "TP"),
            onClick = function()
                local row = panel.guardSelectedSH
                if not row then
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.safehouseTp, {
                    x = row.x, y = row.y, z = row.z or 0, w = row.w, h = row.h,
                })
            end,
        }
        local mayManage = sel.canEdit == true or sel.isMine == true or isAdmin
        if mayManage then
            actionItems[#actionItems + 1] = {
                label = IKST.text("IGUI_IKST_ClaimInvite_Invite", "Invite"),
                onClick = function()
                    panel._ikstSoftInvite = {
                        x = sel.x, y = sel.y, w = sel.w, h = sel.h, id = sel.id, owner = sel.owner,
                    }
                    IKST_ClaimPermissionsUI.clearSoft(panel)
                    panel:refreshJobUI(true)
                end,
            }
            if sel.canEdit then
                actionItems[#actionItems + 1] = {
                    label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Perms"),
                    onClick = function()
                        local row = panel.guardSelectedSH
                        if not row then
                            return
                        end
                        panel._ikstSoftInvite = nil
                        local cfg = IKST_ClaimPermissionsUI.safehouseConfig(row.x, row.y, row.w, row.h)
                        IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                        panel:refreshJobUI(true)
                    end,
                }
            end
        end
        if sel.canRelease == true and (sel.isMine == true or isAdmin) then
            actionItems[#actionItems + 1] = {
                label = IKST.text("IGUI_IKST_Guard_SH_Release", "Release"),
                onClick = function()
                    local row = panel.guardSelectedSH
                    if not row then
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.safehouseRelease, {
                        x = row.x, y = row.y, w = row.w, h = row.h, id = row.id, owner = row.owner,
                    })
                    panel.guardSelectedSH = nil
                    IKST_ClaimPermissionsUI.clearSoft(panel)
                    panel._ikstSoftInvite = nil
                    IKST_JobGuard.requestSafehouses(p)
                end,
            }
        end
        if sel.canRespawn then
            actionItems[#actionItems + 1] = {
                label = IKST_JobGuard.respawnChipLabel(sel),
                primary = sel.respawnOn == true,
                onClick = function()
                    IKST_JobGuard.dispatchSafehouseRespawn(p, panel.guardSelectedSH)
                end,
            }
        end
    end
    return actionItems
end

function IKST_JobGuard.claimOverviewActionPills(panel, player)
    local p = player or (panel and panel.player)
    local pills = {}
    if not p then
        return pills
    end
    local claimState = IKST.getPlayerState(p)
    local reqLabel = IKST.text("IGUI_IKST_ClaimTile_RequestHouse", "Request house")
    local reqPrimary = false
    if claimState and claimState.claimReqA then
        reqLabel = IKST.text("IGUI_IKST_ClaimTile_MarkEnd", "Mark end (B)")
        reqPrimary = true
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowSafehouseClaimRequest(p) then
        pills[#pills + 1] = {
            label = reqLabel,
            primary = reqPrimary,
            onClick = function()
                IKST_JobGuard.onRequestClaimClick(panel)
            end,
        }
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowVehicleClaimRequest(p) then
        pills[#pills + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_RequestVehicle", "Request vehicle"),
            onClick = function()
                IKST_JobGuard.onRequestVehicleClaimClick(panel)
            end,
        }
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateSafehouseClaim(p) then
        pills[#pills + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_NewHouse", "+ House claim"),
            primary = true,
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.claim, "safehouses")
                end
            end,
        }
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateVehicleClaim(p) then
        pills[#pills + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_NewVehicle", "+ Vehicle claim"),
            primary = true,
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.claim, "vehicleclaim")
                end
            end,
        }
    end
    local staff = IKST_Access and type(IKST_Access.canUseStaffTools) == "function" and IKST_Access.canUseStaffTools(p)
    if staff then
        if not IKST_JobStaff then
            require "IKST_JobStaff"
        end
        if not panel._claimOverviewRequestsRequested then
            panel._claimOverviewRequestsRequested = true
            if IKST_JobStaff and type(IKST_JobStaff.requestClaimRequests) == "function" then
                IKST_JobStaff.requestClaimRequests(p)
            end
        end
        local pendingN = #(IKST_JobStaff and IKST_JobStaff.claimPending or {})
        local staffLabel = IKST.text("IGUI_IKST_ClaimRequestQueue", "Claim requests")
        if pendingN > 0 then
            staffLabel = staffLabel .. " (" .. tostring(pendingN) .. ")"
        end
        pills[#pills + 1] = {
            label = staffLabel,
            primary = pendingN > 0,
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.claim, "requests")
                end
            end,
        }
    end
    return pills
end

function IKST_JobGuard.safehouseListRows(list)
    local rows = {}
    for _, sh in ipairs(list or {}) do
        local label = tostring(sh.owner or "?") .. " @ " .. tostring(sh.x) .. "," .. tostring(sh.y)
        if sh.w and sh.h and sh.w > 0 and sh.h > 0 then
            label = label .. " (" .. sh.w .. "x" .. sh.h .. ")"
        end
        rows[#rows + 1] = {
            id = IKST_JobGuard.safehouseId(sh),
            label = label,
            data = sh,
        }
    end
    return rows
end

function IKST_JobGuard.memberListRows(sh)
    local rows = {}
    local members = sh and sh.members
    if type(members) ~= "table" then
        return rows
    end
    if members[1] ~= nil then
        for _, name in ipairs(members) do
            rows[#rows + 1] = { id = tostring(name), label = tostring(name), data = name }
        end
        return rows
    end
    for name, _ in pairs(members) do
        rows[#rows + 1] = { id = tostring(name), label = tostring(name), data = name }
    end
    return rows
end

function IKST_JobGuard.claimListRows(claims, isAdmin)
    local rows = {}
    for _, claim in ipairs(claims or {}) do
        rows[#rows + 1] = {
            id = claim.id,
            label = IKST_JobGuard.claimLineText(claim, isAdmin),
            data = claim,
        }
    end
    return rows
end

function IKST_JobGuard.nearbyVehicleRows(nearby)
    local rows = {}
    for _, v in ipairs(nearby or {}) do
        rows[#rows + 1] = {
            id = v.id,
            label = IKST_JobGuard.vehicleLabel(v),
            data = v,
        }
    end
    return rows
end

function IKST_JobGuard.claimLabelForId(vehicleId, player)
    local row = IKST_VehicleClaimClient and IKST_VehicleClaimClient.uiState(vehicleId, player)
    if not row or not row.claimed then
        return ""
    end
    local s = "[" .. tostring(row.ownerLabel or "?")
    if row.displayLabel and row.displayLabel ~= "" then
        s = s .. ": " .. row.displayLabel
    end
    if row.hoursRemainingText and row.hoursRemainingText ~= "" then
        s = s .. " - " .. row.hoursRemainingText
    end
    return s .. "]"
end

function IKST_JobGuard.targetUiState(panel)
    local vid = IKST_JobGuard.resolveVehicleId(panel)
    if not vid or not IKST_VehicleClaimClient then
        return nil, vid
    end
    local vehicle = nil
    local p = panel.player
    if p and type(p.getVehicle) == "function" then
        vehicle = p:getVehicle()
    end
    return IKST_VehicleClaimClient.uiState(vid, p, vehicle), vid
end

function IKST_JobGuard.readEntry(entry)
    if entry and type(entry.getText) == "function" then
        return string.gsub(entry:getText() or "", "^%s*(.-)%s*$", "%1")
    end
    return ""
end

function IKST_JobGuard.parseShDimension(text, fallback)
    if IKST and type(IKST.parseInteger) == "function" then
        return IKST_Claim.clampDimension(IKST.parseInteger(text, fallback), fallback)
    end
    return IKST_Claim.clampDimension(fallback, 13)
end

function IKST_JobGuard.readShDimensions(panel, state)
    state = state or {}
    local fallbackW = state.guardShW or state.guardShSize or 13
    local fallbackH = state.guardShH or state.guardShSize or 13
    local w = fallbackW
    local h = fallbackH
    if panel.guardShWEntry then
        w = IKST_JobGuard.parseShDimension(IKST_JobGuard.readEntry(panel.guardShWEntry), fallbackW)
    end
    if panel.guardShHEntry then
        h = IKST_JobGuard.parseShDimension(IKST_JobGuard.readEntry(panel.guardShHEntry), fallbackH)
    end
    return w, h
end

function IKST_JobGuard.applyShDimensions(panel, state)
    local w, h = IKST_JobGuard.readShDimensions(panel, state)
    state.guardShW = w
    state.guardShH = h
    if w == h then
        state.guardShSize = w
    end
    local player = panel and panel.player
    if player and type(player.getX) == "function" and type(player.getY) == "function"
        and type(player.getZ) == "function" and IKST_Claim and type(IKST_Claim.isIndoorsAt) == "function" then
        if IKST_Claim.isIndoorsAt(math.floor(player:getX()), math.floor(player:getY()), player:getZ()) then
            state.guardShClaimMode = IKST_Claim.MODE.square
        end
    end
    return w, h
end

function IKST_JobGuard.coords(player)
    if not player or type(player.getX) ~= "function" or type(player.getY) ~= "function"
        or type(player.getZ) ~= "function" then
        return { x = 0, y = 0, z = 0 }
    end
    return { x = math.floor(player:getX()), y = math.floor(player:getY()), z = player:getZ() }
end

function IKST_JobGuard.dispatchRadius(panel, cmd, extra)
    local p = panel and panel.player
    if not p or type(p.getX) ~= "function" or type(p.getY) ~= "function" or type(p.getZ) ~= "function" then
        return
    end
    local state = IKST.getPlayerState(p)
    local radius = state and state.guardRadius or IKST.RADIUS_PRESETS.M
    local args = { x = math.floor(p:getX()), y = math.floor(p:getY()), z = p:getZ(), radius = radius }
    if extra then
        for k, v in pairs(extra) do args[k] = v end
    end
    IKST.dispatchCommand(p, cmd, args)
end

function IKST_JobGuard.buildTools(panel, contentTop)
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.buildTools) == "function" then
        return IKST_SoftTool_Claim.buildTools(panel, contentTop)
    end
    return contentTop or 8
end

function IKST_JobGuard.buildSafehouses(panel, contentTop)
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.buildSafehouses) == "function" then
        return IKST_SoftTool_Claim.buildSafehouses(panel, contentTop)
    end
    return contentTop or 8
end

function IKST_JobGuard.buildVehicles(panel, contentTop)
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.buildVehicles) == "function" then
        return IKST_SoftTool_Claim.buildVehicles(panel, contentTop)
    end
    return contentTop or 8
end

function IKST_JobGuard.onRequestClaimClick(panel)
    IKST_JobGuard.startHouseClaimRequest(panel.player, panel)
end

function IKST_JobGuard.startHouseClaimRequest(player, panel)
    local p = player
    if not p then
        return false
    end
    if IKST_ClaimPolicy and not IKST_ClaimPolicy.mayRequestSafehouseClaim(p) then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_Disabled",
            "House claim requests are disabled on this server."), false)
        return false
    end
    local maxClaims = IKST_ClaimPolicy and type(IKST_ClaimPolicy.maxSafehouseClaims) == "function"
        and IKST_ClaimPolicy.maxSafehouseClaims() or 0
    if maxClaims > 0 and IKST_JobGuard.countOwnedSafehouses(p) >= maxClaims then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimOverview_AlreadyClaimed",
            "You already have a safehouse claim. Select it in the list below — you cannot request another."), false)
        return false
    end
    local state = IKST.getPlayerState(p)
    if not state then
        return false
    end
    local c = IKST_JobGuard.coords(p)
    if not state.claimReqA then
        if IKST_ClaimRequestDraw and IKST_ClaimRequestDraw.start then
            IKST_ClaimRequestDraw.start(p, c)
        else
            state.claimReqA = { x = c.x, y = c.y, z = c.z }
        end
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_WalkToB",
            "Corner marked. Walk to the opposite corner - the blue zone is what staff will see - then press Ask staff to claim again."), true)
        if panel and panel.refreshJobUI then
            panel:refreshJobUI()
        end
        return true
    end
    if panel then
        IKST_JobGuard.finishHouseClaimRequest(panel)
        return true
    end
    IKST.notify(p, IKST.text("IGUI_IKST_ClaimTile_RequestHouse", "Request house")
        .. " â€” open IKST Claim Overview to finish the walk-draw request.", true)
    return true
end

function IKST_JobGuard.finishHouseClaimRequest(panel)
    local p = panel.player
    if not p then
        return
    end
    if IKST_ClaimPolicy and not IKST_ClaimPolicy.mayRequestSafehouseClaim(p) then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_Disabled",
            "House claim requests are disabled on this server."), false)
        return
    end
    local state = IKST.getPlayerState(p)
    if not state then
        return
    end
    local c = IKST_JobGuard.coords(p)
    if not state.claimReqA then
        IKST_JobGuard.startHouseClaimRequest(p, panel)
        return
    end
    local a = state.claimReqA
    local ok, err, zx, zy, zw, zh = IKST_Claim.walkDrawRect(a.x, a.y, a.z, c.x, c.y, c.z)
    if not ok then
        local msg = IKST.text("IGUI_IKST_ClaimReq_BadSize", "Zone must be")
            .. " " .. IKST_Claim.sizeRangeLabel()
        if err == "same floor only" then
            msg = IKST.text("IGUI_IKST_ClaimReq_SameFloor", "Both corners must be on the same floor.")
        elseif err == "zone too large" then
            msg = IKST.text("IGUI_IKST_ClaimReq_TooLarge", "Too large (max")
                .. " " .. tostring(IKST_Claim.MAX_DIM) .. " "
                .. IKST.text("IGUI_IKST_ClaimReq_PerSide", "per side")
                .. "). "
                .. IKST.text("IGUI_IKST_ClaimReq_NowSize", "Now")
                .. " " .. tostring(zw) .. "x" .. tostring(zh)
                .. " - " .. IKST.text("IGUI_IKST_ClaimReq_WalkCloser", "walk closer")
        elseif err == "zone too small" then
            msg = IKST.text("IGUI_IKST_ClaimReq_TooSmall", "Keep walking (min")
                .. " " .. tostring(IKST_Claim.MIN_DIM) .. "). "
                .. IKST.text("IGUI_IKST_ClaimReq_NowSize", "Now")
                .. " " .. tostring(zw) .. "x" .. tostring(zh)
        end
        IKST.notify(p, msg, false)
        return
    end
    local confirm = IKST.text("IGUI_IKST_ClaimReq_Confirm",
        "Send this zone to staff for approval? Staff must accept it before it is yours.")
        .. " " .. tostring(zw) .. "x" .. tostring(zh)
        .. " @ " .. tostring(zx) .. "," .. tostring(zy)
    IKST_Confirm.show(confirm, function()
        IKST.dispatchCommand(p, IKST.CMD.claimRequest, {
            x1 = a.x, y1 = a.y, z1 = a.z,
            x2 = c.x, y2 = c.y, z2 = c.z,
        })
        if IKST_ClaimRequestDraw and IKST_ClaimRequestDraw.clear then
            IKST_ClaimRequestDraw.clear(p)
        else
            state.claimReqA = nil
        end
        if panel.refreshJobUI then
            panel:refreshJobUI()
        end
    end, function()
        if IKST_ClaimRequestDraw and IKST_ClaimRequestDraw.clear then
            IKST_ClaimRequestDraw.clear(p)
        else
            state.claimReqA = nil
        end
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_Cancelled", "Claim request cancelled."), true)
        if panel.refreshJobUI then
            panel:refreshJobUI()
        end
    end)
end

function IKST_JobGuard.onRequestVehicleClaimClick(panel)
    local p = panel.player
    if not p then
        return
    end
    if IKST_ClaimPolicy and not IKST_ClaimPolicy.mayRequestVehicleClaim(p) then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_VehicleDisabled",
            "Vehicle claim requests are disabled on this server."), false)
        return
    end
    local claimArgs = IKST_JobGuard.vehicleClaimArgs(panel)
    if not claimArgs or not claimArgs.vehicleId then
        IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
        return
    end
    IKST_Confirm.show(IKST.text("IGUI_IKST_ClaimReq_VehicleConfirm",
        "Send this vehicle to staff for approval?"), function()
        IKST.dispatchCommand(p, IKST.CMD.vehicleClaimRequest, { vehicleId = claimArgs.vehicleId })
    end)
end

function IKST_JobGuard.dispatchSafehouseRespawn(player, sh)
    if not player or not sh then
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.safehouseSetRespawn, {
        x = sh.x, y = sh.y, w = sh.w, h = sh.h, id = sh.id, owner = sh.owner,
        on = not (sh.respawnOn == true),
    })
    IKST_JobGuard.requestSafehouses(player)
end

function IKST_JobGuard.respawnChipLabel(sh)
    if sh and sh.respawnOn then
        return IKST.text("IGUI_IKST_SH_RespawnOn", "Respawn on")
    end
    return IKST.text("IGUI_IKST_SH_RespawnOff", "Respawn off")
end

function IKST_JobGuard.openDisputeBox(player)
    if not player then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(player, IKST.text("IGUI_IKST_ClaimDispute_MpOnly",
            "Disputes need multiplayer. Staff review them in F1 See Tickets."), false)
        return
    end
    if not ISTextBox or type(ISTextBox.new) ~= "function" then
        return
    end
    local playerNum = 0
    if type(player.getPlayerNum) == "function" then
        playerNum = player:getPlayerNum()
    end
    local prompt = IKST.text("IGUI_IKST_ClaimDispute_Prompt",
        "Describe the claim dispute. Staff will see this as a ticket labeled [dispute].")
    local modal = ISTextBox:new(0, 0, 320, 180, prompt, "", nil, function(_, button)
        if not button or button.internal ~= "OK" then
            return
        end
        local parent = button.parent
        local entry = parent and parent.entry
        if not entry or type(entry.getText) ~= "function" then
            return
        end
        local msg = entry:getText()
        msg = tostring(msg or "")
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        if msg == "" then
            IKST.notify(player, IKST.text("IGUI_IKST_ClaimDispute_NeedMsg", "Enter a dispute message."), false)
            return
        end
        IKST.dispatchCommand(player, IKST.CMD.claimDispute, { message = msg })
    end, playerNum)
    modal:initialise()
    if type(modal.setMultipleLine) == "function" then
        modal:setMultipleLine(true)
    end
    if type(modal.setNumberOfLines) == "function" then
        modal:setNumberOfLines(4)
    end
    modal:addToUIManager()
end
function IKST_JobGuard.buildClaimOverview(panel)
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.buildClaimOverview) == "function" then
        return IKST_SoftTool_Claim.buildClaimOverview(panel)
    end
    return 8
end

function IKST_JobGuard.buildClaimRequests(panel)
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.buildClaimRequests) == "function" then
        return IKST_SoftTool_Claim.buildClaimRequests(panel)
    end
    return 8
end

function IKST_JobGuard.build(panel)
    -- Soft Claim paint lives in SoftTool_Claim (IKUI_SoftBody). JobGuard keeps helpers only.
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.build) == "function" then
        return IKST_SoftTool_Claim.build(panel)
    end
    return 8
end

function IKST_JobGuard.onSafehouseListResult(args)
    if IKST_SafehouseClaimClient and type(IKST_SafehouseClaimClient.onSafehouseListResult) == "function" then
        IKST_SafehouseClaimClient.onSafehouseListResult(args)
    end
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end

function IKST_JobGuard.onClaimListResult(args)
    IKST_JobGuard.claims = (args and args.claims) or {}
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end

function IKST_JobGuard.onDumpResult(args)
    IKST_JobGuard.players = (args and args.players) or {}
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end
