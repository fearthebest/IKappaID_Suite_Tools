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
require "IKST_VehicleClaim"
require "IKST_VehicleClaimClient"
require "IKST_VehicleClaimUI"
require "IKST_SafehouseClaimUI"
require "IKST_SafehousePermissions"
require "IKST_ClaimExplain"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_JobStaff"
require "IKST_JobLayout"
require "IKST_ClaimIcons"
require "IKST_ClaimPolicy"
require "IKST_Access"

IKST_JobGuard = IKST_JobGuard or {}

IKST_JobGuard.safehouses = {}
IKST_JobGuard.claims = {}
IKST_JobGuard.players = {}

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
    return nil
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
        label = label .. " · " .. entry.hoursRemainingText
    end
    return label
end

function IKST_JobGuard.claimLineText(claim, isAdmin)
    if not claim then
        return "?"
    end
    local line = "#" .. tostring(claim.id) .. " " .. tostring(claim.displayLabel or claim.script or "?")
    if claim.hoursRemainingText and claim.hoursRemainingText ~= "" then
        line = line .. " · " .. claim.hoursRemainingText
    end
    if claim.x and claim.y then
        line = line .. " @ " .. claim.x .. "," .. claim.y
    end
    if isAdmin and claim.ownerLabel and not claim.isMine then
        line = line .. " [" .. claim.ownerLabel .. "]"
    end
    return line
end

function IKST_JobGuard.safehouseId(sh)
    if not sh then
        return nil
    end
    if sh.id ~= nil then
        return sh.id
    end
    return tostring(sh.x) .. "," .. tostring(sh.y) .. "," .. tostring(sh.w or 0) .. "," .. tostring(sh.h or 0)
end

function IKST_JobGuard.matchSafehouse(selected, list)
    if not selected then
        return nil
    end
    local sid = IKST_JobGuard.safehouseId(selected)
    for _, sh in ipairs(list or {}) do
        if IKST_JobGuard.safehouseId(sh) == sid then
            return sh
        end
    end
    return nil
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
        s = s .. " · " .. row.hoursRemainingText
    end
    return s .. "]"
end

function IKST_JobGuard.targetUiState(panel)
    local vid = IKST_JobGuard.resolveVehicleId(panel)
    if not vid or not IKST_VehicleClaimClient then
        return nil, vid
    end
    return IKST_VehicleClaimClient.uiState(vid, panel.player), vid
end

function IKST_JobGuard.readEntry(entry)
    if entry and entry.getText then
        return string.gsub(entry:getText() or "", "^%s*(.-)%s*$", "%1")
    end
    return ""
end

function IKST_JobGuard.parseShDimension(text, fallback)
    local n = tonumber((tostring(text or "")):match("^%s*(%d+)"))
    if not n then
        return IKST_Claim.clampDimension(fallback, 13)
    end
    return IKST_Claim.clampDimension(n, fallback)
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
    if IKST_Claim.isIndoorsAt(math.floor(panel.player:getX()), math.floor(panel.player:getY()), panel.player:getZ()) then
        state.guardShClaimMode = IKST_Claim.MODE.square
    end
    return w, h
end

function IKST_JobGuard.coords(player)
    return { x = math.floor(player:getX()), y = math.floor(player:getY()), z = player:getZ() }
end

function IKST_JobGuard.dispatchRadius(panel, cmd, extra)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local radius = state and state.guardRadius or IKST.RADIUS_PRESETS.M
    local args = { x = math.floor(p:getX()), y = math.floor(p:getY()), z = p:getZ(), radius = radius }
    if extra then
        for k, v in pairs(extra) do args[k] = v end
    end
    IKST.dispatchCommand(p, cmd, args)
end

function IKST_JobGuard.buildTools(panel, y)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Guard_Catch", "Catch target"), function()
        local t = IKST_JobStaff.getSelectedTarget(panel)
        if t then IKST.dispatchCommand(p, IKST.CMD.catchTarget, { target = t.id }) end
    end, true)
    panel:makeJobButton(118, y, 100, 24, IKST.text("IGUI_IKST_Guard_Release", "Release"), function()
        local t = IKST_JobStaff.getSelectedTarget(panel)
        if t then IKST.dispatchCommand(p, IKST.CMD.releaseTarget, { target = t.id }) end
    end, false)
    y = y + 28
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Guard_Creative", "Creative"), function()
        IKST.dispatchCommand(p, IKST.CMD.toggleCreative, {})
    end, false)
    panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_Guard_UnlimAmmo", "Unlim ammo"), function()
        IKST.dispatchCommand(p, IKST.CMD.toggleUnlimitedAmmo, {})
    end, false)
    y = y + 28
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Guard_Lightbulbs", "Lightbulbs"), function()
        IKST_JobGuard.dispatchRadius(panel, IKST.CMD.lightbulbsArea, nil)
    end, false)
    panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_Guard_DumpPlayers", "Dump players"), function()
        IKST.dispatchCommand(p, IKST.CMD.dumpPlayers, {})
    end, false)
    y = y + 28
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_ChatNote", "Chat: /catch /release /power /water /creative /backup /restore /ikst"), UIFont.Small)
    return y + 22
end

function IKST_JobGuard.buildSafehouses(panel, y)
    local p = panel.player
    local isAdmin = IKST_Access and IKST_Access.canUseTools(p)
    local isStaff = IKST_Access and IKST_Access.canUseStaffTools(p)
    local c = IKST_JobGuard.coords(p)
    local state = IKST.getPlayerState(p)
    if not state.guardShSize then
        state.guardShSize = 13
    end
    if not state.guardShW then
        state.guardShW = state.guardShSize
    end
    if not state.guardShH then
        state.guardShH = state.guardShSize
    end
    local indoors = IKST_Claim.isIndoorsAt(c.x, c.y, c.z)
    if isAdmin then
        if indoors and not state.guardShClaimMode then
            state.guardShClaimMode = IKST_Claim.MODE.building
        end
        if not indoors then
            state.guardShClaimMode = IKST_Claim.MODE.square
        end
    else
        state.guardShClaimMode = IKST_Claim.MODE.building
    end
    local claimMode = state.guardShClaimMode or IKST_Claim.MODE.square

    if not isAdmin then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ClaimReq_ResidentialOnly",
            "Stand inside a house. Players may only request residential buildings."), UIFont.Small)
        y = y + 18
    elseif indoors then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_IndoorNote", "Inside a building — pick claim type, then size."), UIFont.Small)
        y = y + 18
        panel:makeJobButton(12, y, 120, 22, IKST.text("IGUI_IKST_Guard_SH_ModeSquare", "Sized square"), function()
            state.guardShClaimMode = IKST_Claim.MODE.square
            panel:refreshJobUI()
        end, claimMode == IKST_Claim.MODE.square)
        panel:makeJobButton(138, y, 120, 22, IKST.text("IGUI_IKST_Guard_SH_ModeBuilding", "Whole building"), function()
            state.guardShClaimMode = IKST_Claim.MODE.building
            panel:refreshJobUI()
        end, claimMode == IKST_Claim.MODE.building)
        y = y + 28
    else
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_OutdoorNote", "Outdoors: centered rect on you (size or custom W×H)."), UIFont.Small)
        y = y + 18
    end
    local presetSpecs = {}
    for _, preset in ipairs({ 11, 13, 21, 31, 60 }) do
        local w, h = state.guardShW or preset, state.guardShH or preset
        local presetActive = w == preset and h == preset and (state.guardShSize == preset or not state.guardShSize)
        presetSpecs[#presetSpecs + 1] = {
            label = tostring(preset),
            w = 48,
            primary = presetActive,
            fn = function()
                state.guardShSize = preset
                state.guardShW = preset
                state.guardShH = preset
                if indoors then
                    state.guardShClaimMode = IKST_Claim.MODE.square
                end
                panel:refreshJobUI()
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, presetSpecs, 6, 22)
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_Custom", "Custom W×H") .. " (" .. IKST_Claim.sizeRangeLabel() .. "):", UIFont.Small)
    y = y + 16
    panel:makeJobLabel(12, y + 4, "W", UIFont.Small)
    panel.guardShWEntry = ISTextEntryBox:new(panel:draftEntryText("guardShWEntry", tostring(state.guardShW or 13)), 28, y, 56, 22)
    panel.guardShWEntry:initialise()
    panel.guardShWEntry:instantiate()
    panel:addJobWidget(panel.guardShWEntry)
    panel:makeJobLabel(92, y + 4, "H", UIFont.Small)
    panel.guardShHEntry = ISTextEntryBox:new(panel:draftEntryText("guardShHEntry", tostring(state.guardShH or 13)), 108, y, 56, 22)
    panel.guardShHEntry:initialise()
    panel.guardShHEntry:instantiate()
    panel:addJobWidget(panel.guardShHEntry)
    panel:makeJobButton(172, y, 72, 22, IKST.text("IGUI_IKST_Guard_SH_ApplySize", "Apply"), function()
        IKST_JobGuard.applyShDimensions(panel, state)
        panel:refreshJobUI()
    end, false)
    y = y + 28
    if isAdmin then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_Owner", "Owner (blank = you):"), UIFont.Small)
        y = y + 16
        panel.guardShOwnerEntry = ISTextEntryBox:new(panel:draftEntryText("guardShOwnerEntry", ""), 12, y, 160, 22)
        panel.guardShOwnerEntry:initialise()
        panel.guardShOwnerEntry:instantiate()
        panel:addJobWidget(panel.guardShOwnerEntry)
        y = y + 28
    end
    local previewW, previewH = IKST_JobGuard.readShDimensions(panel, state)
    local px, py, pw, ph, pz, _, previewKind = IKST_Claim.safehousePreviewRect(
        c.x, c.y, c.z, state.guardShSize, claimMode, previewW, previewH)
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Preview", "Preview") .. ": " .. IKST_Claim.formatRectLabel(px, py, pw, ph, previewKind), UIFont.Small)
    y = y + 20
    -- Claim action before optional tip: tip scan used to throw and hide this button entirely.
    local claimActions = {}
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateClaim and IKST_ClaimPolicy.mayCreateClaim(p) then
        claimActions[#claimActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_SH_Claim", "Claim here"),
            w = 130,
            primary = true,
            icon = IKST_ClaimIcons.SAFEHOUSE_CLAIM,
            fn = function()
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
    else
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ClaimReq_StaffOnly",
            "Staff must approve new claims. Use Request claim on Overview."), UIFont.Small)
        y = y + 18
    end
    if #claimActions > 0 then
        y = IKST_JobLayout.flowRow(panel, y, claimActions, 6, 24)
    end
    local tip = IKST_ClaimExplain and type(IKST_ClaimExplain.summaryForRect) == "function"
        and IKST_ClaimExplain.summaryForRect(p, px, py, pw, ph) or nil
    if type(tip) == "string" and tip ~= "" then
        panel:makeJobLabel(12, y, tip, UIFont.Small)
        y = y + 20
    end
    local shListActions = {
        { label = IKST.text("IGUI_IKST_RefreshList", "Refresh"), w = 100, fn = function() IKST_JobGuard.requestSafehouses(p) end },
    }
    if isStaff then
        shListActions[#shListActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_SH_Borders", "Borders"),
            w = 100,
            fn = function() IKST.dispatchCommand(p, IKST.CMD.toggleSafehouseBorders, {}) end,
        }
        shListActions[#shListActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_Backup", "Backup"),
            w = 100,
            fn = function() IKST.dispatchCommand(p, IKST.CMD.backupSafehouses, {}) end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, shListActions, 6, 24)
    if isStaff then
        y = IKST_JobLayout.flowRow(panel, y, {
            { label = IKST.text("IGUI_IKST_Guard_Restore", "Restore SH"), w = 120, fn = function() IKST.dispatchCommand(p, IKST.CMD.restoreSafehouses, {}) end },
        }, 6, 24)
    end
    local list = IKST_JobGuard.safehouses or {}
    panel.guardSelectedSH = IKST_JobGuard.matchSafehouse(panel.guardSelectedSH, list)
    if #list == 0 then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet. Use Claim here or Refresh."), UIFont.Small)
        y = y + 20
    else
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ListFilter", "Filter"), UIFont.Small)
        y = y + 16
        local listW = panel.contentW or (panel.width - 24)
        local _, fy = IKST_JobLayout.makeFilterEntry(panel, nil, IKST_JobLayout.MARGIN, y, listW, "guardShFilter", function()
            local rows = IKST_JobLayout.filterRows(IKST_JobGuard.safehouseListRows(list), panel.guardShFilter)
            IKST_JobLayout.refillSelectList(panel.guardShList, rows, IKST_JobGuard.safehouseId(panel.guardSelectedSH))
        end)
        y = fy
        local rows = IKST_JobLayout.filterRows(IKST_JobGuard.safehouseListRows(list), panel.guardShFilter)
        local shList, ly = IKST_JobLayout.makeSelectList(panel, nil, IKST_JobLayout.MARGIN, y, listW,
            IKST_JobLayout.selectListHeight(8), rows, {
                selectedId = IKST_JobGuard.safehouseId(panel.guardSelectedSH),
                onSelect = function(row)
                    panel.guardSelectedSH = row.data
                    panel:refreshJobUI(true)
                end,
            })
        panel.guardShList = shList
        y = ly + 8
    end
    if panel.guardSelectedSH then
        local sel = panel.guardSelectedSH
        if sel.members then
            local memberRows = IKST_JobGuard.memberListRows(sel)
            if #memberRows > 0 then
                panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SH_Members", "Members") .. ":", UIFont.Small)
                y = y + 16
                local memList, mly = IKST_JobLayout.makeSelectList(panel, nil, IKST_JobLayout.MARGIN, y,
                    panel.contentW or (panel.width - 24), IKST_JobLayout.selectListHeight(math.min(6, math.max(4, #memberRows))),
                    memberRows, {
                        selectedId = panel.guardSelectedMember,
                        onSelect = function(row)
                            panel.guardSelectedMember = row.id
                            if panel.guardShMemberEntry and type(panel.guardShMemberEntry.setText) == "function" then
                                panel.guardShMemberEntry:setText(tostring(row.data or row.id))
                            end
                        end,
                    })
                panel.guardMemberList = memList
                y = mly + 4
            end
        end
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SH_AddMember", "Add member username:"), UIFont.Small)
        y = y + 16
        if sel.canEdit then
            panel.guardShMemberEntry = ISTextEntryBox:new(panel:draftEntryText("guardShMemberEntry", ""), 12, y, 160, 22)
            panel.guardShMemberEntry:initialise()
            panel.guardShMemberEntry:instantiate()
            panel:addJobWidget(panel.guardShMemberEntry)
            panel:makeJobButton(180, y, 90, 22, IKST.text("IGUI_IKST_SH_Add", "Add"), function()
                local member = IKST_JobGuard.readEntry(panel.guardShMemberEntry)
                if member == "" then
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.safehouseAddMember, {
                    x = sel.x, y = sel.y, w = sel.w, h = sel.h, id = sel.id, owner = sel.owner, member = member,
                })
                IKST_JobGuard.requestSafehouses(p)
            end, false)
            y = y + 28
        end
        y = IKST_JobLayout.flowRow(panel, y, {
            { label = IKST.text("IGUI_IKST_Guard_SH_Tp", "TP"), w = 90, primary = true, fn = function()
                local sel = panel.guardSelectedSH
                IKST.dispatchCommand(p, IKST.CMD.safehouseTp, {
                    x = sel.x, y = sel.y, z = sel.z or 0, w = sel.w, h = sel.h,
                })
            end },
        }, 6, 24)
        local releaseActions = {}
        if sel.canRelease then
            releaseActions[#releaseActions + 1] = {
                label = IKST.text("IGUI_IKST_Guard_SH_Release", "Release"),
                w = 100,
                icon = IKST_ClaimIcons.SAFEHOUSE_UNCLAIM,
                fn = function()
                    local selRow = panel.guardSelectedSH
                    IKST.dispatchCommand(p, IKST.CMD.safehouseRelease, {
                        x = selRow.x, y = selRow.y, w = selRow.w, h = selRow.h, id = selRow.id, owner = selRow.owner,
                    })
                    panel.guardSelectedSH = nil
                    IKST_JobGuard.requestSafehouses(p)
                end,
            }
        end
        if sel.canEdit then
            releaseActions[#releaseActions + 1] = {
                label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"),
                w = 110,
                icon = IKST_ClaimIcons.PERMS,
                fn = function()
                    local selRow = panel.guardSelectedSH
                    if IKST_SafehouseClaimUI and IKST_SafehouseClaimUI.open then
                        IKST_SafehouseClaimUI.open(p, selRow.x, selRow.y, selRow.w, selRow.h)
                    end
                end,
            }
        end
        if sel.canRespawn then
            releaseActions[#releaseActions + 1] = {
                label = IKST_JobGuard.respawnChipLabel(sel),
                w = 120,
                primary = sel.respawnOn == true,
                fn = function()
                    IKST_JobGuard.dispatchSafehouseRespawn(p, panel.guardSelectedSH)
                end,
            }
        end
        if #releaseActions > 0 then
            y = IKST_JobLayout.flowRow(panel, y, releaseActions, 6, 24)
        end
        if sel.canEdit then
            y = IKST_JobLayout.flowRow(panel, y, {
                { label = IKST.text("IGUI_IKST_SH_RemoveMember", "Remove member"), w = 130, fn = function()
                    local selRow = panel.guardSelectedSH
                    local member = IKST_JobGuard.readEntry(panel.guardShMemberEntry)
                    if member == "" then
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.safehouseRemoveMember, {
                        x = selRow.x, y = selRow.y, w = selRow.w, h = selRow.h, id = selRow.id, owner = selRow.owner, member = member,
                    })
                    IKST_JobGuard.requestSafehouses(p)
                end },
            }, 6, 24)
        end
    end
    return y
end

function IKST_JobGuard.buildVehicles(panel, y)
    local p = panel.player
    local isAdmin = IKST_Access and IKST_Access.canUseTools(p)
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh nearby"), function()
        IKST_JobGuard.requestNearbyVehicles(p)
        IKST_JobGuard.requestClaims(p)
    end, false)
    y = y + 28
    local claims = IKST_JobGuard.claims or {}
    local claimsTitle = isAdmin
        and IKST.text("IGUI_IKST_Guard_Vehicle_ClaimsAdmin", "Vehicle claims (server list):")
        or IKST.text("IGUI_IKST_Guard_Vehicle_Claims", "Your claims (click to target):")
    if #claims > 0 then
        panel:makeJobLabel(12, y, claimsTitle, UIFont.Small)
        y = y + 18
        local contentW = panel.contentW or (panel.width - 24)
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ListFilter", "Filter"), UIFont.Small)
        y = y + 16
        local _, fy = IKST_JobLayout.makeFilterEntry(panel, nil, IKST_JobLayout.MARGIN, y, contentW, "guardClaimFilter", function()
            local rows = IKST_JobLayout.filterRows(IKST_JobGuard.claimListRows(claims, isAdmin), panel.guardClaimFilter)
            IKST_JobLayout.refillSelectList(panel.guardClaimList, rows, panel.guardSelectedClaimId)
        end)
        y = fy
        local claimRows = IKST_JobLayout.filterRows(IKST_JobGuard.claimListRows(claims, isAdmin), panel.guardClaimFilter)
        local claimList, cly = IKST_JobLayout.makeSelectList(panel, nil, IKST_JobLayout.MARGIN, y, contentW,
            IKST_JobLayout.selectListHeight(8), claimRows, {
                selectedId = panel.guardSelectedClaimId,
                onSelect = function(row)
                    panel.guardSelectedClaimId = row.id
                    panel.guardVehicleId = row.id
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end,
            })
        panel.guardClaimList = claimList
        y = cly + 8
        local selectedClaim
        for _, claim in ipairs(claims) do
            if claim.id == panel.guardSelectedClaimId then
                selectedClaim = claim
                break
            end
        end
        if selectedClaim then
            local claimActions = {}
            if selectedClaim.canRelease then
                claimActions[#claimActions + 1] = {
                    label = IKST.text("IGUI_IKST_Guard_ReleaseClaim", "Unclaim"),
                    w = 80,
                    fn = function()
                        IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, { vehicleId = selectedClaim.id })
                    end,
                }
            end
            if selectedClaim.canEdit then
                claimActions[#claimActions + 1] = {
                    label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Perms"),
                    w = 80,
                    fn = function()
                        if IKST_VehicleClaimUI and IKST_VehicleClaimUI.open then
                            IKST_VehicleClaimUI.open(p, selectedClaim.id)
                        end
                    end,
                }
            end
            if #claimActions > 0 then
                y = IKST_JobLayout.flowRow(panel, y, claimActions, 6, 24)
            end
        end
    end
    local nearby = IKST_VehicleClaimClient and IKST_VehicleClaimClient.nearby or IKST_JobVehicle.listCache or {}
    if #nearby == 0 then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby. Stand next to one or use Vehicle Wrangler list."), UIFont.Small)
        y = y + 20
    else
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Vehicle_nearby", "Nearby"), UIFont.Small)
        y = y + 16
        local nearRows = IKST_JobGuard.nearbyVehicleRows(nearby)
        local nearList, nly = IKST_JobLayout.makeSelectList(panel, nil, IKST_JobLayout.MARGIN, y,
            panel.contentW or (panel.width - 24), IKST_JobLayout.selectListHeight(8), nearRows, {
                selectedId = panel.guardVehicleId,
                onSelect = function(row)
                    panel.guardSelectedClaimId = nil
                    panel.guardVehicleId = row.id
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end,
            })
        panel.guardNearbyList = nearList
        y = nly + 8
    end
    local uiState, vid = IKST_JobGuard.targetUiState(panel)
    if vid then
        local claimNote = IKST_JobGuard.claimLabelForId(vid, p)
        local targetText = IKST.text("IGUI_IKST_Guard_Vehicle_Target", "Target") .. ": #" .. tostring(vid)
        if claimNote ~= "" then
            targetText = targetText .. " " .. claimNote
        elseif uiState and uiState.claimed and uiState.ownerLabel then
            targetText = targetText .. " [" .. IKST.text("IGUI_IKST_VehicleClaim_Info", "Owner")
                .. ": " .. tostring(uiState.ownerLabel) .. "]"
        end
        panel:makeJobLabel(12, y, targetText, UIFont.Small)
        y = y + 18
    end
    if isAdmin then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_Vehicle_Owner", "Claim owner (blank = you):"), UIFont.Small)
        y = y + 16
        panel.guardVehicleOwnerEntry = ISTextEntryBox:new(panel:draftEntryText("guardVehicleOwnerEntry", ""), 12, y, 140, 22)
        panel.guardVehicleOwnerEntry:initialise()
        panel.guardVehicleOwnerEntry:instantiate()
        panel:addJobWidget(panel.guardVehicleOwnerEntry)
    end
    local labelX = isAdmin and 160 or 12
    local labelEntryX = isAdmin and 200 or 52
    local labelEntryW = IKST_JobLayout.clampWidth(panel, labelEntryX, (panel.contentW or 264) - (labelEntryX - IKST_JobLayout.MARGIN))
    panel:makeJobLabel(labelX, y + 4, IKST.text("IGUI_IKST_Guard_Vehicle_Label", "Label:"), UIFont.Small)
    panel.guardVehicleLabelEntry = ISTextEntryBox:new(panel:draftEntryText("guardVehicleLabelEntry", ""), labelEntryX, y, labelEntryW, 22)
    panel.guardVehicleLabelEntry:initialise()
    panel.guardVehicleLabelEntry:instantiate()
    panel:addJobWidget(panel.guardVehicleLabelEntry)
    y = y + 28
    local canClaim = uiState and uiState.canClaim == true
    local canRelease = uiState and uiState.canRelease == true
    local canEdit = uiState and uiState.canEdit == true
    local vehicleActions = {}
    if canClaim then
        vehicleActions[#vehicleActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_Claim", "Claim vehicle"),
            w = 120,
            primary = true,
            icon = IKST_ClaimIcons.VEHICLE_CLAIM,
            fn = function()
                local targetId = IKST_JobGuard.resolveVehicleId(panel)
                if not targetId then
                    IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.vehicleClaim, {
                    vehicleId = targetId,
                    owner = isAdmin and IKST_JobGuard.readEntry(panel.guardVehicleOwnerEntry) or "",
                    label = IKST_JobGuard.readEntry(panel.guardVehicleLabelEntry),
                })
            end,
        }
    end
    if canRelease then
        vehicleActions[#vehicleActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_ReleaseClaim", "Release claim"),
            w = 120,
            icon = IKST_ClaimIcons.VEHICLE_UNCLAIM,
            fn = function()
                local targetId = IKST_JobGuard.resolveVehicleId(panel)
                if not targetId then
                    IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, { vehicleId = targetId })
            end,
        }
    end
    if isAdmin then
        vehicleActions[#vehicleActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_TransferClaim", "Transfer"),
            w = 100,
            fn = function()
                local targetId = IKST_JobGuard.resolveVehicleId(panel)
                local newOwner = IKST_JobGuard.readEntry(panel.guardVehicleOwnerEntry)
                if not targetId then
                    IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                    return
                end
                if newOwner == "" then
                    IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_OwnerRequired", "Enter new owner username."), false)
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.vehicleClaimTransfer, { vehicleId = targetId, owner = newOwner })
                IKST_JobGuard.requestClaims(p)
                panel:refreshJobUI()
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, vehicleActions, 6, 24)
    local secondaryActions = {}
    if vid and uiState and uiState.claimed and (canEdit or isAdmin) then
        secondaryActions[#secondaryActions + 1] = {
            label = IKST.text("IGUI_IKST_Guard_SetClaimLabel", "Set label"),
            w = 120,
            fn = function()
                local targetId = IKST_JobGuard.resolveVehicleId(panel)
                if not targetId then
                    IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.vehicleClaimSetLabel, {
                    vehicleId = targetId,
                    label = IKST_JobGuard.readEntry(panel.guardVehicleLabelEntry),
                })
            end,
        }
    end
    if vid and (canEdit or isAdmin) then
        secondaryActions[#secondaryActions + 1] = {
            label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"),
            w = 130,
            icon = IKST_ClaimIcons.PERMS,
            fn = function()
                if IKST_VehicleClaimUI and IKST_VehicleClaimUI.open then
                    IKST_VehicleClaimUI.open(p, vid)
                end
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, secondaryActions, 6, 24)
    -- Staff vehicle protect/unprotect: server handlers exist (IKST_ProtectOps); use World/Protection tab.
    -- Do not dispatch until GuardOps + ServerGate implement ownership checks.
    return y
end

-- Claim landing page (mockup: ikst-page-claim.png): section cards with claim
-- rows + quick tools. Request claim files a staff ticket; it never auto-claims.
local function claimOverviewBtn(parent, panel, x, y, w, h, label, kind, onClick)
    local btn = IKST_Chrome.newActionButton(x, y, w, h, label, panel, function()
        if onClick then
            onClick()
        end
    end, kind or "chip")
    parent:addChild(btn)
    return btn
end

local function claimOverviewRowH()
    return math.max(44, IKST_UI_Layout.s(48))
end

local function safehouseTitle(sh)
    if sh.title and sh.title ~= "" then
        return tostring(sh.title)
    end
    return tostring(sh.owner or "?")
end

local function safehouseSub(sh)
    local coords = tostring(sh.x or "?") .. ", " .. tostring(sh.y or "?")
    local members = sh.members
    local count = 0
    if type(members) == "table" then
        for _ in pairs(members) do
            count = count + 1
        end
    end
    if count > 0 then
        return coords .. "  ·  " .. tostring(count) .. " "
            .. IKST.text("IGUI_IKST_SH_Members", "Members")
    end
    return coords
end

local function vehicleTitle(claim)
    return tostring(claim.displayLabel or claim.script or ("#" .. tostring(claim.id or "?")))
end

local function vehicleSub(claim)
    local parts = {}
    if claim.id ~= nil then
        parts[#parts + 1] = "#" .. tostring(claim.id)
    end
    if claim.x and claim.y then
        parts[#parts + 1] = tostring(claim.x) .. ", " .. tostring(claim.y)
    end
    if claim.hoursRemainingText and claim.hoursRemainingText ~= "" then
        parts[#parts + 1] = claim.hoursRemainingText
    end
    if claim.ownerLabel and claim.ownerLabel ~= "" and not claim.isMine then
        parts[#parts + 1] = tostring(claim.ownerLabel)
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, "  ·  ")
end

function IKST_JobGuard.onRequestClaimClick(panel)
    local p = panel.player
    if not p then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_MpOnly",
            "Claim requests need multiplayer. Staff review them in F1 See Tickets."), false)
        return
    end
    local state = IKST.getPlayerState(p)
    if not state then
        return
    end
    local c = IKST_JobGuard.coords(p)
    if not state.claimReqA then
        local b = IKST_Claim.buildingAt(c.x, c.y, c.z)
        if not b or not IKST_Claim.isResidentialBuilding(b) then
            IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_ResidentialOnly",
                "Stand inside a house. Players may only request residential buildings."), false)
            return
        end
        state.claimReqA = { x = c.x, y = c.y, z = c.z }
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_WalkToB",
            "Start marked. Walk to another room in this house, then press Request claim again."), true)
        if panel.refreshJobUI then
            panel:refreshJobUI()
        end
        return
    end
    local a = state.claimReqA
    local ok, err, zx, zy, zw, zh = IKST_Claim.playerResidentialRect(a.x, a.y, a.z, c.x, c.y, c.z)
    if not ok then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_ResidentialOnly",
            "Stand inside a house. Players may only request residential buildings."), false)
        return
    end
    local confirm = IKST.text("IGUI_IKST_ClaimReq_Confirm",
        "Send this house to staff for approval? It is not auto-approved.")
        .. " " .. tostring(zw) .. "x" .. tostring(zh)
        .. " @ " .. tostring(zx) .. "," .. tostring(zy)
    IKST_Confirm.show(confirm, function()
        IKST.dispatchCommand(p, IKST.CMD.claimRequest, {
            x1 = a.x, y1 = a.y, z1 = a.z,
            x2 = c.x, y2 = c.y, z2 = c.z,
        })
        state.claimReqA = nil
        if panel.refreshJobUI then
            panel:refreshJobUI()
        end
    end, function()
        state.claimReqA = nil
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_Cancelled", "Claim request cancelled."), true)
        if panel.refreshJobUI then
            panel:refreshJobUI()
        end
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
    local p = panel.player
    if not p then
        return 8
    end
    if not panel._claimOverviewListsRequested then
        panel._claimOverviewListsRequested = true
        IKST_JobGuard.requestSafehouses(p)
        IKST_JobGuard.requestClaims(p)
    end

    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local padX = IKST_UI_Layout.s(14)
    local rowH = claimOverviewRowH()
    local btnH = math.max(26, IKST_UI_Layout.s(30))
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local cc = IKST_Chrome.colors

    local title = IKST.text("IGUI_IKST_WS_Claim", "Claim")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local newLabel = IKST.text("IGUI_IKST_ClaimTile_NewClaim", "+ New claim")
    local newW = IKST_UI_Layout.buttonWidth(newLabel, UIFont.Small, 100)
    local claimState = IKST.getPlayerState(p)
    local reqLabel = IKST.text("IGUI_IKST_ClaimTile_RequestClaim", "Request claim")
    local reqKind = "chip"
    if claimState and claimState.claimReqA then
        reqLabel = IKST.text("IGUI_IKST_ClaimTile_MarkEnd", "Mark end (B)")
        reqKind = "primary"
    end
    local reqW = IKST_UI_Layout.buttonWidth(reqLabel, UIFont.Small, 120)
    local rightEdge = x + w
    local newX = rightEdge - newW
    local reqX = newX - IKST_UI_Layout.s(8) - reqW

    local reqBtn = IKST_Chrome.newActionButton(reqX, y, reqW, headerBtnH, reqLabel, panel, function()
        IKST_JobGuard.onRequestClaimClick(panel)
    end, reqKind)
    panel:addJobWidget(reqBtn)

    local newBtn = IKST_Chrome.newActionButton(newX, y, newW, headerBtnH, newLabel, panel, function()
        if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateClaim and IKST_ClaimPolicy.mayCreateClaim(p) then
            if panel.enterNav then
                panel:enterNav(IKST.VIEW.claim, "safehouses")
            end
        else
            IKST_JobGuard.onRequestClaimClick(panel)
        end
    end, "primary")
    panel:addJobWidget(newBtn)

    y = y + math.max(26, headerBtnH) + gap

    -- SAFEHOUSE CLAIM
    local shList = IKST_JobGuard.safehouses or {}
    panel.guardSelectedSH = IKST_JobGuard.matchSafehouse(panel.guardSelectedSH, shList)
    if not panel.guardSelectedSH and #shList > 0 then
        panel.guardSelectedSH = shList[1]
    end
    local shHeaderH = IKST_Chrome.sectionHeaderH()
    local shBottom = IKST_UI_Layout.s(14)
    local innerW = math.max(80, w - (padX * 2))
    local listH = IKST_JobLayout.selectListHeight(8)
    local shContentH = 40
    if #shList > 0 then
        shContentH = 16 + 22 + 6 + listH + 8 + btnH
    end
    local shCardH = shHeaderH + shContentH + shBottom
    local shCard, shContentY = IKST_Chrome.newSectionCardPanel(x, y, w, shCardH,
        "media/ui/ikst/safehouse_claim.png",
        IKST.text("IGUI_IKST_ClaimTile_SectionSafehouse", "Safehouse claim"))
    panel:addJobWidget(shCard)

    if #shList == 0 then
        local empty = ISLabel:new(padX, shContentY + 8, 16,
            IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet. Use Claim here or Refresh."),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        empty:initialise()
        shCard:addChild(empty)
    else
        local filterLbl = ISLabel:new(padX, shContentY, 16, IKST.text("IGUI_IKST_ListFilter", "Filter"),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        filterLbl:initialise()
        shCard:addChild(filterLbl)
        local overviewShRows = {}
        for _, sh in ipairs(shList) do
            local sub = safehouseSub(sh)
            local label = safehouseTitle(sh)
            if sub ~= "" then
                label = label .. "  ·  " .. sub
            end
            overviewShRows[#overviewShRows + 1] = {
                id = IKST_JobGuard.safehouseId(sh),
                label = label,
                data = sh,
            }
        end
        local _, fy = IKST_JobLayout.makeFilterEntry(panel, shCard, padX, shContentY + 16, innerW, "guardShFilter", function()
            local filtered = IKST_JobLayout.filterRows(overviewShRows, panel.guardShFilter)
            IKST_JobLayout.refillSelectList(panel.guardOverviewShList, filtered, IKST_JobGuard.safehouseId(panel.guardSelectedSH))
        end)
        local filtered = IKST_JobLayout.filterRows(overviewShRows, panel.guardShFilter)
        local shBox, listBottom = IKST_JobLayout.makeSelectList(panel, shCard, padX, fy, innerW, listH, filtered, {
            selectedId = IKST_JobGuard.safehouseId(panel.guardSelectedSH),
            onSelect = function(row)
                panel.guardSelectedSH = row.data
                panel:refreshJobUI(true)
            end,
        })
        panel.guardOverviewShList = shBox
        local sh = panel.guardSelectedSH
        if sh then
            local btnY = listBottom + 8
            local bx = padX
            local membersLabel = IKST.text("IGUI_IKST_SH_Members", "Members")
            local permsLabel = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions")
            local abandonLabel = IKST.text("IGUI_IKST_ClaimTile_Abandon", "Abandon")
            local respawnLabel = IKST_JobGuard.respawnChipLabel(sh)
            local membersW = IKST_UI_Layout.buttonWidth(membersLabel, UIFont.Small, 72)
            local permsW = IKST_UI_Layout.buttonWidth(permsLabel, UIFont.Small, 88)
            local abandonW = IKST_UI_Layout.buttonWidth(abandonLabel, UIFont.Small, 72)
            local respawnW = IKST_UI_Layout.buttonWidth(respawnLabel, UIFont.Small, 88)
            local btnGap = IKST_UI_Layout.s(6)
            claimOverviewBtn(shCard, panel, bx, btnY, membersW, btnH, membersLabel, "chip", function()
                panel.guardSelectedSH = sh
                if IKST_SafehouseClaimUI and IKST_SafehouseClaimUI.open then
                    local memberScope = nil
                    if IKST_SafehousePermissions then
                        memberScope = IKST_SafehousePermissions.GROUP_MEMBER
                    end
                    IKST_SafehouseClaimUI.open(p, sh.x, sh.y, sh.w, sh.h, memberScope)
                end
            end)
            bx = bx + membersW + btnGap
            if sh.canEdit then
                claimOverviewBtn(shCard, panel, bx, btnY, permsW, btnH, permsLabel, "primary", function()
                    if IKST_SafehouseClaimUI and IKST_SafehouseClaimUI.open then
                        IKST_SafehouseClaimUI.open(p, sh.x, sh.y, sh.w, sh.h)
                    end
                end)
                bx = bx + permsW + btnGap
            end
            if sh.canRespawn then
                local respawnKind = sh.respawnOn and "primary" or "chip"
                claimOverviewBtn(shCard, panel, bx, btnY, respawnW, btnH, respawnLabel, respawnKind, function()
                    IKST_JobGuard.dispatchSafehouseRespawn(p, sh)
                end)
                bx = bx + respawnW + btnGap
            end
            if sh.canRelease then
                claimOverviewBtn(shCard, panel, bx, btnY, abandonW, btnH, abandonLabel, "danger", function()
                    IKST_Confirm.showDestructive(
                        IKST.text("IGUI_IKST_ClaimTile_ConfirmAbandonSH", "Abandon this safehouse claim?"),
                        function()
                            IKST.dispatchCommand(p, IKST.CMD.safehouseRelease, {
                                x = sh.x, y = sh.y, w = sh.w, h = sh.h, id = sh.id, owner = sh.owner,
                            })
                            panel.guardSelectedSH = nil
                            IKST_JobGuard.requestSafehouses(p)
                        end
                    )
                end)
            end
        end
    end
    y = y + shCardH + gap

    -- VEHICLE CLAIM
    local vList = IKST_JobGuard.claims or {}
    if panel.guardSelectedClaimId == nil and #vList > 0 then
        panel.guardSelectedClaimId = vList[1].id
    end
    local vContentH = 40
    if #vList > 0 then
        vContentH = 16 + 22 + 6 + listH + 8 + btnH
    end
    local vCardH = shHeaderH + vContentH + shBottom
    local vCard, vContentY = IKST_Chrome.newSectionCardPanel(x, y, w, vCardH,
        "media/ui/ikst/vehicle_claim.png",
        IKST.text("IGUI_IKST_ClaimTile_SectionVehicle", "Vehicle claim"))
    panel:addJobWidget(vCard)

    if #vList == 0 then
        local empty = ISLabel:new(padX, vContentY + 8, 16,
            IKST.text("IGUI_IKST_ClaimTile_NoVehicles", "No vehicle claims yet."),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        empty:initialise()
        vCard:addChild(empty)
    else
        local filterLbl = ISLabel:new(padX, vContentY, 16, IKST.text("IGUI_IKST_ListFilter", "Filter"),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        filterLbl:initialise()
        vCard:addChild(filterLbl)
        local overviewVRows = {}
        for _, claim in ipairs(vList) do
            local sub = vehicleSub(claim)
            local label = vehicleTitle(claim)
            if sub ~= "" then
                label = label .. "  ·  " .. sub
            end
            overviewVRows[#overviewVRows + 1] = { id = claim.id, label = label, data = claim }
        end
        local _, fy = IKST_JobLayout.makeFilterEntry(panel, vCard, padX, vContentY + 16, innerW, "guardClaimFilter", function()
            local filtered = IKST_JobLayout.filterRows(overviewVRows, panel.guardClaimFilter)
            IKST_JobLayout.refillSelectList(panel.guardOverviewVList, filtered, panel.guardSelectedClaimId)
        end)
        local filtered = IKST_JobLayout.filterRows(overviewVRows, panel.guardClaimFilter)
        local vBox, listBottom = IKST_JobLayout.makeSelectList(panel, vCard, padX, fy, innerW, listH, filtered, {
            selectedId = panel.guardSelectedClaimId,
            onSelect = function(row)
                panel.guardSelectedClaimId = row.id
                panel.guardVehicleId = row.id
                panel.selectedVehicleId = row.id
                panel:refreshJobUI(true)
            end,
        })
        panel.guardOverviewVList = vBox
        local selectedClaim
        for _, claim in ipairs(vList) do
            if claim.id == panel.guardSelectedClaimId then
                selectedClaim = claim
                break
            end
        end
        if selectedClaim then
            local claimId = selectedClaim.id
            local btnY = listBottom + 8
            local bx = padX
            local keysLabel = IKST.text("IGUI_IKST_ClaimTile_Keys", "Keys")
            local membersLabel = IKST.text("IGUI_IKST_SH_Members", "Members")
            local abandonLabel = IKST.text("IGUI_IKST_ClaimTile_Abandon", "Abandon")
            local keysW = IKST_UI_Layout.buttonWidth(keysLabel, UIFont.Small, 64)
            local membersW = IKST_UI_Layout.buttonWidth(membersLabel, UIFont.Small, 72)
            local abandonW = IKST_UI_Layout.buttonWidth(abandonLabel, UIFont.Small, 72)
            local btnGap = IKST_UI_Layout.s(6)
            claimOverviewBtn(vCard, panel, bx, btnY, membersW, btnH, membersLabel, "chip", function()
                if IKST_VehicleClaimUI and IKST_VehicleClaimUI.open then
                    IKST_VehicleClaimUI.open(p, claimId)
                end
            end)
            bx = bx + membersW + btnGap
            if selectedClaim.canEdit then
                claimOverviewBtn(vCard, panel, bx, btnY, keysW, btnH, keysLabel, "primary", function()
                    if IKST_VehicleClaimUI and IKST_VehicleClaimUI.open then
                        IKST_VehicleClaimUI.open(p, claimId)
                    end
                end)
                bx = bx + keysW + btnGap
            end
            if selectedClaim.canRelease then
                claimOverviewBtn(vCard, panel, bx, btnY, abandonW, btnH, abandonLabel, "danger", function()
                    IKST_Confirm.showDestructive(
                        IKST.text("IGUI_IKST_ClaimTile_ConfirmAbandonVeh", "Abandon this vehicle claim?"),
                        function()
                            IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, { vehicleId = claimId })
                            IKST_JobGuard.requestClaims(p)
                        end
                    )
                end)
            end
        end
    end
    y = y + vCardH + gap

    -- QUICK TOOLS
    local isStaff = IKST_Access and IKST_Access.canUseStaffTools and IKST_Access.canUseStaffTools(p)
    local quickItems = {}
    if isStaff then
        quickItems[#quickItems + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_Catch", "Catch intruder (ADMIN ONLY)"),
            kind = "chip",
            onClick = function()
                local t = IKST_JobStaff.getSelectedTarget(panel)
                if t then
                    IKST.dispatchCommand(p, IKST.CMD.catchTarget, { target = t.id })
                else
                    if panel.enterNav then
                        panel:enterNav(IKST.VIEW.claim, "catch")
                    end
                end
            end,
        }
    end
    quickItems[#quickItems + 1] = {
        label = IKST.text("IGUI_IKST_ClaimTile_ListAll", "List all claims"),
        kind = "chip",
        onClick = function()
            IKST_JobGuard.requestSafehouses(p)
            IKST_JobGuard.requestClaims(p)
            IKST.notify(p, IKST.text("IGUI_IKST_ClaimTile_ListAllDone", "Refreshing claim lists…"), true)
            panel:refreshJobUI()
        end,
    }
    quickItems[#quickItems + 1] = {
        label = IKST.text("IGUI_IKST_ClaimTile_Dispute", "Dispute resolver"),
        kind = "chip",
        onClick = function()
            IKST_JobGuard.openDisputeBox(p)
        end,
    }

    local qGap = IKST_UI_Layout.s(8)
    local qBtnH = math.max(28, IKST_UI_Layout.s(32))
    local qHeaderH = IKST_Chrome.sectionHeaderH()
    local qCardH = qHeaderH + (#quickItems * (qBtnH + qGap)) - qGap + shBottom
    local qCard, qContentY = IKST_Chrome.newSectionCardPanel(x, y, w, qCardH,
        "media/ui/ikst/tool_catch.png",
        IKST.text("IGUI_IKST_ClaimTile_SectionQuick", "Quick tools"))
    panel:addJobWidget(qCard)
    local qY = qContentY
    local qBtnW = math.max(80, w - (padX * 2))
    for _, item in ipairs(quickItems) do
        claimOverviewBtn(qCard, panel, padX, qY, qBtnW, qBtnH, item.label, item.kind or "chip", item.onClick)
        qY = qY + qBtnH + qGap
    end
    y = y + qCardH + gap

    return y
end

function IKST_JobGuard.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end

    if panel.view == IKST.VIEW.claim and (state.navTool == "overview" or not state.navTool) then
        state.navTool = "overview"
        state.guardMode = "overview"
        return IKST_JobGuard.buildClaimOverview(panel)
    end

    if panel.view == IKST.VIEW.server and state.navTool == "safehouses" then
        state.guardMode = "safehouses"
        local y = IKST_JobGuard.buildSafehouses(panel, 8)
        return y
    end

    local tab = panel.view
    if tab == IKST.VIEW.safehouses then
        state.guardMode = "safehouses"
    elseif not state.guardMode or state.guardMode == "overview" then
        state.guardMode = "safehouses"
    end
    local isStaff = IKST_Access and IKST_Access.canUseStaffTools and IKST_Access.canUseStaffTools(panel.player)
    if not isStaff and (state.guardMode == "tools" or state.guardMode == "tiles"
        or state.guardMode == "containers" or state.guardMode == "farming" or state.guardMode == "protect") then
        state.guardMode = "safehouses"
    end

    local y = 8
    if IKST_ClaimPolicy and IKST_ClaimPolicy.limitsSummary then
        panel:makeJobLabel(12, y, IKST_ClaimPolicy.limitsSummary(), UIFont.Small)
        y = y + 22
    end
    local modes = {
        { id = "safehouses", label = IKST.text("IGUI_IKST_Claim_Safehouse", "Safehouses") },
        { id = "vehicles", label = IKST.text("IGUI_IKST_Claim_Vehicle", "Vehicles") },
    }
    if isStaff then
        modes[#modes + 1] = { id = "tools", label = IKST.text("IGUI_IKST_Guard_Catch", "Catch") }
    end
    local specs = {}
    for _, m in ipairs(modes) do
        specs[#specs + 1] = {
            label = m.label,
            w = getTextManager():MeasureStringX(UIFont.Small, m.label) + 18,
            primary = state.guardMode == m.id,
            fn = function()
                state.guardMode = m.id
                panel:refreshJobUI()
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, specs, 6, 24)
    y = y + 8

    local mode = state.guardMode
    if mode == "tools" then
        y = IKST_JobGuard.buildTools(panel, y)
    elseif mode == "safehouses" then
        y = IKST_JobGuard.buildSafehouses(panel, y)
    elseif mode == "vehicles" then
        y = IKST_JobGuard.buildVehicles(panel, y)
    elseif mode == "tiles" or mode == "containers" or mode == "farming" or mode == "protect" then
        -- Protection belongs under Tiles workspace; bounce staff there.
        if panel.enterNav then
            panel:enterNav(IKST.VIEW.tiles, "protect")
            return y
        end
    end

    return y
end

function IKST_JobGuard.onSafehouseListResult(args)
    IKST_JobGuard.safehouses = (args and args.safehouses) or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then IKST_JobsPanel.instance:refreshJobUI() end
end

function IKST_JobGuard.onClaimListResult(args)
    IKST_JobGuard.claims = (args and args.claims) or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then IKST_JobsPanel.instance:refreshJobUI() end
end

function IKST_JobGuard.onDumpResult(args)
    IKST_JobGuard.players = (args and args.players) or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then IKST_JobsPanel.instance:refreshJobUI() end
end
