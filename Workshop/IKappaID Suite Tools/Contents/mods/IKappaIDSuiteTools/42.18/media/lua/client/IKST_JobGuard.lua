if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Claim"
require "IKST_VehicleClaim"
require "IKST_VehicleClaimUI"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_JobStaff"
require "IKST_JobLayout"
require "IKST_ClaimIcons"

IKST_JobGuard = IKST_JobGuard or {}
IKST_JobProtect = IKST_JobGuard

IKST_JobGuard.safehouses = {}
IKST_JobGuard.claims = {}
IKST_JobGuard.players = {}

function IKST_JobGuard.requestSafehouses(player)
    IKST.dispatchCommand(player, IKST.CMD.safehouseList, {})
end

function IKST_JobGuard.requestClaims(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleClaimList, { all = true })
end

function IKST_JobGuard.requestNearbyVehicles(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleList, {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = player:getZ(),
        radius = IKST.getVehicleNearRadius(),
    })
end

function IKST_JobGuard.resolveVehicleId(panel)
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
    local claim = IKST_VehicleClaim.get(entry.id)
    if claim then
        label = label .. " " .. IKST_VehicleClaim.claimLabel(claim)
    end
    return label
end

function IKST_JobGuard.claimLabelForId(vehicleId)
    return IKST_VehicleClaim.claimLabel(IKST_VehicleClaim.get(vehicleId))
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
    if indoors and not state.guardShClaimMode then
        state.guardShClaimMode = IKST_Claim.MODE.square
    end
    if not indoors then
        state.guardShClaimMode = IKST_Claim.MODE.square
    end
    local claimMode = state.guardShClaimMode or IKST_Claim.MODE.square

    if indoors then
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
    local sx = 12
    for _, preset in ipairs({ 11, 13, 21, 31, 60 }) do
        local w, h = state.guardShW or preset, state.guardShH or preset
        local presetActive = w == preset and h == preset and (state.guardShSize == preset or not state.guardShSize)
        panel:makeJobButton(sx, y, 48, 22, tostring(preset), function()
            state.guardShSize = preset
            state.guardShW = preset
            state.guardShH = preset
            if indoors then
                state.guardShClaimMode = IKST_Claim.MODE.square
            end
            panel:refreshJobUI()
        end, presetActive)
        sx = sx + 52
    end
    y = y + 28
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_Custom", "Custom W×H") .. " (" .. IKST_Claim.sizeRangeLabel() .. "):", UIFont.Small)
    y = y + 16
    panel:makeJobLabel(12, y + 4, "W", UIFont.Small)
    panel.guardShWEntry = ISTextEntryBox:new(tostring(state.guardShW or 13), 28, y, 56, 22)
    panel.guardShWEntry:initialise()
    panel.guardShWEntry:instantiate()
    panel:addJobWidget(panel.guardShWEntry)
    panel:makeJobLabel(92, y + 4, "H", UIFont.Small)
    panel.guardShHEntry = ISTextEntryBox:new(tostring(state.guardShH or 13), 108, y, 56, 22)
    panel.guardShHEntry:initialise()
    panel.guardShHEntry:instantiate()
    panel:addJobWidget(panel.guardShHEntry)
    panel:makeJobButton(172, y, 72, 22, IKST.text("IGUI_IKST_Guard_SH_ApplySize", "Apply"), function()
        IKST_JobGuard.applyShDimensions(panel, state)
        panel:refreshJobUI()
    end, false)
    y = y + 28
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_Owner", "Owner (blank = you):"), UIFont.Small)
    y = y + 16
    panel.guardShOwnerEntry = ISTextEntryBox:new("", 12, y, 160, 22)
    panel.guardShOwnerEntry:initialise()
    panel.guardShOwnerEntry:instantiate()
    panel:addJobWidget(panel.guardShOwnerEntry)
    y = y + 28
    local previewW, previewH = IKST_JobGuard.readShDimensions(panel, state)
    local px, py, pw, ph, pz, _, previewKind = IKST_Claim.safehousePreviewRect(
        c.x, c.y, c.z, state.guardShSize, claimMode, previewW, previewH)
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Preview", "Preview") .. ": " .. IKST_Claim.formatRectLabel(px, py, pw, ph, previewKind), UIFont.Small)
    y = y + 24
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_Guard_SH_Claim", "Claim here"),
            w = 130,
            primary = true,
            icon = IKST_ClaimIcons.SAFEHOUSE_CLAIM,
            fn = function()
                local owner = IKST_JobGuard.readEntry(panel.guardShOwnerEntry)
                local w, h = IKST_JobGuard.applyShDimensions(panel, state)
                IKST.dispatchCommand(p, IKST.CMD.safehouseClaim, {
                    x = c.x, y = c.y, z = c.z,
                    size = state.guardShSize,
                    w = w,
                    h = h,
                    owner = owner,
                    claimMode = state.guardShClaimMode or IKST_Claim.MODE.square,
                })
                IKST_JobGuard.requestSafehouses(p)
            end,
        },
    }, 6, 24)
    y = IKST_JobLayout.flowRow(panel, y, {
        { label = IKST.text("IGUI_IKST_RefreshList", "Refresh"), w = 100, fn = function() IKST_JobGuard.requestSafehouses(p) end },
        { label = IKST.text("IGUI_IKST_Guard_SH_Borders", "Borders"), w = 100, fn = function() IKST.dispatchCommand(p, IKST.CMD.toggleSafehouseBorders, {}) end },
        { label = IKST.text("IGUI_IKST_Guard_Backup", "Backup"), w = 100, fn = function() IKST.dispatchCommand(p, IKST.CMD.backupSafehouses, {}) end },
    }, 6, 24)
    y = IKST_JobLayout.flowRow(panel, y, {
        { label = IKST.text("IGUI_IKST_Guard_Restore", "Restore SH"), w = 120, fn = function() IKST.dispatchCommand(p, IKST.CMD.restoreSafehouses, {}) end },
    }, 6, 24)
    local list = IKST_JobGuard.safehouses or {}
    if #list == 0 then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet. Use Claim here or Refresh."), UIFont.Small)
        y = y + 20
    end
    for i, sh in ipairs(list) do
        if i > 10 then break end
        local label = (sh.owner or "?") .. " @ " .. sh.x .. "," .. sh.y
        if sh.w and sh.h and sh.w > 0 and sh.h > 0 then
            label = label .. " (" .. sh.w .. "x" .. sh.h .. ")"
        end
        panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
            panel.guardSelectedSH = sh
            panel:refreshJobUI()
        end, panel.guardSelectedSH == sh)
        y = y + 24
    end
    if panel.guardSelectedSH then
        local sel = panel.guardSelectedSH
        if sel.members and #sel.members > 0 then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SH_Members", "Members") .. ":", UIFont.Small)
            y = y + 16
            for i, member in ipairs(sel.members) do
                if i > 8 then
                    break
                end
                panel:makeJobLabel(20, y, member, UIFont.Small)
                y = y + 16
            end
            y = y + 4
        end
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SH_AddMember", "Add member username:"), UIFont.Small)
        y = y + 16
        panel.guardShMemberEntry = ISTextEntryBox:new("", 12, y, 160, 22)
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
        y = IKST_JobLayout.flowRow(panel, y, {
            { label = IKST.text("IGUI_IKST_Guard_SH_Tp", "TP"), w = 90, primary = true, fn = function()
                local sel = panel.guardSelectedSH
                IKST.dispatchCommand(p, IKST.CMD.safehouseTp, {
                    x = sel.x, y = sel.y, z = sel.z or 0, w = sel.w, h = sel.h,
                })
            end },
            { label = IKST.text("IGUI_IKST_Guard_SH_Release", "Release"), w = 100, icon = IKST_ClaimIcons.SAFEHOUSE_UNCLAIM, fn = function()
                local sel = panel.guardSelectedSH
                IKST.dispatchCommand(p, IKST.CMD.safehouseRelease, {
                    x = sel.x, y = sel.y, w = sel.w, h = sel.h, id = sel.id, owner = sel.owner,
                })
                panel.guardSelectedSH = nil
                IKST_JobGuard.requestSafehouses(p)
            end },
            { label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"), w = 110, icon = IKST_ClaimIcons.PERMS, fn = function()
                local sel = panel.guardSelectedSH
                if IKST_SafehouseClaimUI and IKST_SafehouseClaimUI.open then
                    IKST_SafehouseClaimUI.open(p, sel.x, sel.y, sel.w, sel.h)
                end
            end },
        }, 6, 24)
        y = IKST_JobLayout.flowRow(panel, y, {
            { label = IKST.text("IGUI_IKST_SH_RemoveMember", "Remove member"), w = 130, fn = function()
                local sel = panel.guardSelectedSH
                local member = IKST_JobGuard.readEntry(panel.guardShMemberEntry)
                if member == "" then
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.safehouseRemoveMember, {
                    x = sel.x, y = sel.y, w = sel.w, h = sel.h, id = sel.id, owner = sel.owner, member = member,
                })
                IKST_JobGuard.requestSafehouses(p)
            end },
        }, 6, 24)
    end
    return y
end

function IKST_JobGuard.buildVehicles(panel, y)
    local p = panel.player
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh nearby"), function()
        IKST_JobGuard.requestNearbyVehicles(p)
        IKST_JobGuard.requestClaims(p)
    end, false)
    y = y + 28
    local nearby = IKST_JobVehicle.listCache or {}
    if #nearby == 0 then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby. Stand next to one or use Vehicle Wrangler list."), UIFont.Small)
        y = y + 20
    end
    for i, v in ipairs(nearby) do
        if i > 6 then
            break
        end
        local label = IKST_JobGuard.vehicleLabel(v)
        panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
            panel.guardVehicleId = v.id
            panel.selectedVehicleId = v.id
            panel:refreshJobUI()
        end, panel.guardVehicleId == v.id or (not panel.guardVehicleId and i == 1))
        y = y + 24
    end
    local vid = IKST_JobGuard.resolveVehicleId(panel)
    if vid then
        local claimNote = IKST_JobGuard.claimLabelForId(vid)
        local targetText = IKST.text("IGUI_IKST_Guard_Vehicle_Target", "Target") .. ": #" .. tostring(vid)
        if claimNote ~= "" then
            targetText = targetText .. " " .. claimNote
        end
        panel:makeJobLabel(12, y, targetText, UIFont.Small)
        y = y + 18
    end
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_Vehicle_Owner", "Claim owner (blank = you):"), UIFont.Small)
    y = y + 16
    panel.guardVehicleOwnerEntry = ISTextEntryBox:new("", 12, y, 140, 22)
    panel.guardVehicleOwnerEntry:initialise()
    panel.guardVehicleOwnerEntry:instantiate()
    panel:addJobWidget(panel.guardVehicleOwnerEntry)
    local labelX = 160
    local labelEntryX = 200
    local labelEntryW = IKST_JobLayout.clampWidth(panel, labelEntryX, (panel.contentW or 264) - (labelEntryX - IKST_JobLayout.MARGIN))
    panel:makeJobLabel(labelX, y + 4, IKST.text("IGUI_IKST_Guard_Vehicle_Label", "Label:"), UIFont.Small)
    panel.guardVehicleLabelEntry = ISTextEntryBox:new("", labelEntryX, y, labelEntryW, 22)
    panel.guardVehicleLabelEntry:initialise()
    panel.guardVehicleLabelEntry:instantiate()
    panel:addJobWidget(panel.guardVehicleLabelEntry)
    y = y + 28
    local vehicleActions = {
        {
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
                    owner = IKST_JobGuard.readEntry(panel.guardVehicleOwnerEntry),
                    label = IKST_JobGuard.readEntry(panel.guardVehicleLabelEntry),
                })
                IKST_JobGuard.requestClaims(p)
                panel:refreshJobUI()
            end,
        },
        {
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
                IKST_JobGuard.requestClaims(p)
                panel:refreshJobUI()
            end,
        },
        {
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
        },
    }
    y = IKST_JobLayout.flowRow(panel, y, vehicleActions, 6, 24)
    local secondaryActions = {
        {
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
                IKST_JobGuard.requestClaims(p)
            end,
        },
    }
    if vid then
        local claim = IKST_VehicleClaim.get(vid)
        if claim and IKST_VehicleClaim.playerMayEdit(claim, p) then
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
    end
    y = IKST_JobLayout.flowRow(panel, y, secondaryActions, 6, 24)
    panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_Protect_Vehicle", "Staff protect"), function()
        if vid then
            IKST.dispatchCommand(p, IKST.CMD.protectVehicle, { vehicleId = vid })
        end
    end, false)
    panel:makeJobButton(158, y, 140, 24, IKST.text("IGUI_IKST_Protect_Unvehicle", "Unprotect"), function()
        if vid then
            IKST.dispatchCommand(p, IKST.CMD.unprotectVehicle, { vehicleId = vid })
        end
    end, false)
    y = y + 30
    for i, claim in ipairs(IKST_JobGuard.claims or {}) do
        if i > 8 then break end
        local line = "#" .. tostring(claim.id) .. " " .. IKST_VehicleClaim.claimLabel(claim)
        if claim.x and claim.y then
            line = line .. " @ " .. claim.x .. "," .. claim.y
        end
        panel:makeJobLabel(12, y, line, UIFont.Small)
        y = y + 18
    end
    return y
end

function IKST_JobGuard.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end

    if panel.view == IKST.VIEW.server and state.navTool == "safehouses" then
        state.guardMode = "safehouses"
        local y = IKST_JobGuard.buildSafehouses(panel, 8)
        panel.logPanel = IKST_ActionLog.dock(panel, panel.player, y)
        return y
    end

    local tab = panel.view
    if tab == IKST.VIEW.safehouses then
        state.guardMode = "safehouses"
    elseif not state.guardMode then
        state.guardMode = "safehouses"
    end

    local y = 8
    local mode = state.guardMode

    if mode == "tools" then
        y = IKST_JobGuard.buildTools(panel, y)
    elseif mode == "safehouses" then
        y = IKST_JobGuard.buildSafehouses(panel, y)
    elseif mode == "vehicles" then
        y = IKST_JobGuard.buildVehicles(panel, y)
    end

    panel.logPanel = IKST_ActionLog.dock(panel, panel.player, y)
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

IKST_JobProtect.build = IKST_JobGuard.build
