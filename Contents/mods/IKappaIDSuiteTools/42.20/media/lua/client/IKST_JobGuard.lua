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
require "IKST_SafehousePermissions"
require "IKST_ClaimExplain"
require "IKappaID_UI/IKUI_Chrome"
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

function IKST_JobGuard.buildTools(panel, contentTop)
    local p = panel.player

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 2, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Util_Players", "Online players"))
        if not IKST_JobStaff then
            require "IKST_JobStaff"
        end
        if IKST_JobStaff and type(IKST_JobStaff.requestPlayers) == "function" and not panel._catchPlayersRequested then
            panel._catchPlayersRequested = true
            IKST_JobStaff.requestPlayers(p)
        end
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1, true)
        local rows = IKST_JobLayout.rowsForListHeight(listH)
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, rows)
        local pillAreaY = listBottom + gapLP
        local pillAreaH = math.max(btnH, pillH)
        if pillAreaY + pillAreaH > ay + ah then
            pillAreaY = math.max(ay, ay + ah - pillAreaH)
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, pillAreaY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobStaff.requestPlayers(p)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Guard_Catch", "Catch"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Guard_Catch", "Catch"),
                primary = true,
                onClick = function()
                    local t = IKST_JobStaff.getSelectedTarget(panel)
                    if not t then
                        IKST.notify(p, IKST.text("IGUI_IKST_SelectPlayerFirst", "Select a player first."), false)
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.catchTarget, { target = t.id })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_Release", "Release"),
                onClick = function()
                    local t = IKST_JobStaff.getSelectedTarget(panel)
                    if not t then
                        IKST.notify(p, IKST.text("IGUI_IKST_SelectPlayerFirst", "Select a player first."), false)
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.releaseTarget, { target = t.id })
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobGuard.buildSafehouses(panel, contentTop)
    local p = panel.player
    local isAdmin = IKST_Access and IKST_Access.canUseTools(p)
    local isStaff = IKST_Access and IKST_Access.canUseStaffTools(p)
    local c = IKST_JobGuard.coords(p)
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end
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

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 4, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    if isAdmin then
        panel.guardShOwnerEntry = ISTextEntryBox:new(panel:draftEntryText("guardShOwnerEntry", ""), -2000, -2000, 40, 20)
        panel.guardShOwnerEntry:initialise()
        panel.guardShOwnerEntry:instantiate()
        panel:addJobWidget(panel.guardShOwnerEntry)
        if type(panel.guardShOwnerEntry.setVisible) == "function" then
            panel.guardShOwnerEntry:setVisible(false)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_SectionClaimMode", "Claim mode"))
        local items = {}
        if isAdmin and indoors then
            items = {
                {
                    label = IKST.text("IGUI_IKST_Guard_SH_ModeBuilding", "Player claim"),
                    primary = claimMode == IKST_Claim.MODE.building,
                    onClick = function()
                        state.guardShClaimMode = IKST_Claim.MODE.building
                        panel:refreshJobUI()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_Guard_SH_ModeSquare", "Admin claim"),
                    primary = claimMode == IKST_Claim.MODE.square,
                    onClick = function()
                        state.guardShClaimMode = IKST_Claim.MODE.square
                        panel:refreshJobUI()
                    end,
                },
            }
        elseif isAdmin then
            items = {
                {
                    label = IKST.text("IGUI_IKST_Guard_SH_ModeSquare", "Admin claim"),
                    primary = true,
                    onClick = function()
                        state.guardShClaimMode = IKST_Claim.MODE.square
                        panel:refreshJobUI()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_Guard_SH_ModeBuilding", "Player claim"),
                    onClick = function()
                        state.guardShClaimMode = IKST_Claim.MODE.building
                        panel:refreshJobUI()
                    end,
                },
            }
        else
            items = {
                {
                    label = IKST.text("IGUI_IKST_Guard_SH_ModeBuilding", "Player claim"),
                    primary = true,
                    onClick = function()
                        state.guardShClaimMode = IKST_Claim.MODE.building
                        panel:refreshJobUI()
                    end,
                },
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Size_Label", "Size"))
        local sizeMap = {
            { label = "S", val = 11 },
            { label = "M", val = 13 },
            { label = "L", val = 21 },
            { label = "XL", val = 31 },
            { label = "Custom", val = 60 },
        }
        local items = {}
        for i = 1, #sizeMap do
            local row = sizeMap[i]
            local preset = row.val
            local w0, h0 = state.guardShW or preset, state.guardShH or preset
            local presetActive = w0 == preset and h0 == preset
            items[#items + 1] = {
                label = row.label,
                primary = presetActive,
                onClick = function()
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
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Guard_SH_Custom", "Custom WxH"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = panel:draftEntryText("guardShWEntry", tostring(state.guardShW or 13)), fieldName = "guardShWEntry" },
            { text = panel:draftEntryText("guardShHEntry", tostring(state.guardShH or 13)), fieldName = "guardShHEntry" },
        }, IKST.text("IGUI_IKST_Guard_SH_ApplySize", "Apply"), function()
            IKST_JobGuard.applyShDimensions(panel, state)
            panel:refreshJobUI()
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_Guard_SH_Claim", "Actions"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local tipText = ""
        if IKST_ClaimExplain and type(IKST_ClaimExplain.summaryForRect) == "function" then
            local here = IKST_JobGuard.coords(p)
            local tw = tonumber(state.guardShW) or tonumber(state.guardShSize) or 13
            local th = tonumber(state.guardShH) or tonumber(state.guardShSize) or 13
            local cx = math.floor((here.x or 0) - tw / 2)
            local cy = math.floor((here.y or 0) - th / 2)
            if type(IKST_ClaimExplain.linesForRectWithRules) == "function" then
                tipText = table.concat(IKST_ClaimExplain.linesForRectWithRules(p, cx, cy, tw, th), " | ")
            else
                tipText = IKST_ClaimExplain.summaryForRect(p, cx, cy, tw, th) or ""
            end
        end
        local tipH = 0
        if tipText ~= nil and tipText ~= "" then
            tipH = 16
            listH = math.max(36, listH - tipH - 2)
        end
        local pillY = ay + listH + tipH + ((tipH > 0) and 2 or 0) + gapLP
        local pillH = math.max(btnH, pillH)
        local list = IKST_JobGuard.safehouses or {}
        panel.guardSelectedSH = IKST_JobGuard.matchSafehouse(panel.guardSelectedSH, list)
        local rows = IKST_JobLayout.filterRows(IKST_JobGuard.safehouseListRows(list), panel.guardShFilter)
        if #rows == 0 then
            rows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet. Use Claim here or Refresh."),
                data = nil,
            }
        end
        local shList = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, rows, {
            selectedId = IKST_JobGuard.safehouseId(panel.guardSelectedSH),
            onSelect = function(row)
                if row and row.data then
                    panel.guardSelectedSH = row.data
                    panel:refreshJobUI(true)
                end
            end,
        })
        panel.guardShList = shList

        if tipH > 0 then
            local tipLab = ISLabel:new(ax, ay + listH + 1, tipH, tipText, 0.85, 0.85, 0.85, 1, UIFont.Small, true)
            tipLab:initialise()
            tipLab:instantiate()
            card:addChild(tipLab)
        end

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
            if sel.canEdit then
                actionItems[#actionItems + 1] = {
                    label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Perms"),
                    onClick = function()
                        local row = panel.guardSelectedSH
                        if row and IKST_SafehouseClaimUI and type(IKST_SafehouseClaimUI.open) == "function" then
                            IKST_SafehouseClaimUI.open(p, row.x, row.y, row.w, row.h)
                        end
                    end,
                }
            end
            if sel.canRelease then
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
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillH, actionItems)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobGuard.buildVehicles(panel, contentTop)
    local p = panel.player
    local isAdmin = IKST_Access and IKST_Access.canUseTools(p)

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 3, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Guard_Vehicle_Claims", "Claims"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local pillY = ay + listH + gapLP
        local pillH = math.max(btnH, pillH)
        local claims = IKST_JobGuard.claims or {}
        local rows = IKST_JobLayout.filterRows(IKST_JobGuard.claimListRows(claims, isAdmin), panel.guardClaimFilter)
        if #rows == 0 then
            rows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_ClaimTile_NoVehicles", "No vehicle claims yet."),
                data = nil,
            }
        end
        local claimList = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, rows, {
            selectedId = panel.guardSelectedClaimId,
            onSelect = function(row)
                if row and row.data then
                    panel.guardSelectedClaimId = row.id
                    panel.guardVehicleId = row.id
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end
            end,
        })
        panel.guardClaimList = claimList

        local selectedClaim
        for _, claim in ipairs(claims) do
            if claim.id == panel.guardSelectedClaimId then
                selectedClaim = claim
                break
            end
        end
        local claimActions = {
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobGuard.requestNearbyVehicles(p)
                    IKST_JobGuard.requestClaims(p)
                end,
            },
        }
        if selectedClaim and selectedClaim.canRelease then
            claimActions[#claimActions + 1] = {
                label = IKST.text("IGUI_IKST_Guard_ReleaseClaim", "Unclaim"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, { vehicleId = selectedClaim.id })
                end,
            }
        end
        if selectedClaim and selectedClaim.canEdit then
            claimActions[#claimActions + 1] = {
                label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Perms"),
                onClick = function()
                    if IKST_VehicleClaimUI and type(IKST_VehicleClaimUI.open) == "function" then
                        IKST_VehicleClaimUI.open(p, selectedClaim.id)
                    end
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillH, claimActions)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Vehicle_nearby", "Nearby"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local pillY = ay + listH + gapLP
        local pillH = math.max(btnH, pillH)
        local nearby = IKST_VehicleClaimClient and IKST_VehicleClaimClient.nearby or IKST_JobVehicle and IKST_JobVehicle.listCache or {}
        local nearRows = IKST_JobGuard.nearbyVehicleRows(nearby)
        if #nearRows == 0 then
            nearRows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."),
                data = nil,
            }
        end
        local nearList = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, nearRows, {
            selectedId = panel.guardVehicleId,
            onSelect = function(row)
                if row and row.data then
                    panel.guardSelectedClaimId = nil
                    panel.guardVehicleId = row.id
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end
            end,
        })
        panel.guardNearbyList = nearList

        local uiState, vid = IKST_JobGuard.targetUiState(panel)
        local canClaim = uiState and uiState.canClaim == true
        local canRelease = uiState and uiState.canRelease == true
        local canEdit = uiState and uiState.canEdit == true
        local vehicleActions = {}
        if canClaim then
            vehicleActions[#vehicleActions + 1] = {
                label = IKST.text("IGUI_IKST_Guard_Claim", "Claim vehicle"),
                primary = true,
                onClick = function()
                    local claimArgs = IKST_JobGuard.vehicleClaimArgs(panel)
                    if not claimArgs then
                        IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                        return
                    end
                    claimArgs.owner = isAdmin and IKST_JobGuard.readEntry(panel.guardVehicleOwnerEntry) or ""
                    claimArgs.label = IKST_JobGuard.readEntry(panel.guardVehicleLabelEntry)
                    IKST.dispatchCommand(p, IKST.CMD.vehicleClaim, claimArgs)
                end,
            }
        elseif IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowVehicleClaimRequest
            and IKST_ClaimPolicy.mayShowVehicleClaimRequest(p) and vid then
            vehicleActions[#vehicleActions + 1] = {
                label = IKST.text("IGUI_IKST_ClaimTile_RequestVehicle", "Request vehicle claim"),
                primary = true,
                onClick = function()
                    IKST_JobGuard.onRequestVehicleClaimClick(panel)
                end,
            }
        end
        if canRelease then
            vehicleActions[#vehicleActions + 1] = {
                label = IKST.text("IGUI_IKST_Guard_ReleaseClaim", "Release claim"),
                onClick = function()
                    local claimArgs = IKST_JobGuard.vehicleClaimArgs(panel)
                    if not claimArgs then
                        IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, claimArgs)
                end,
            }
        end
        if vid and (canEdit or isAdmin) then
            vehicleActions[#vehicleActions + 1] = {
                label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions"),
                onClick = function()
                    if IKST_VehicleClaimUI and type(IKST_VehicleClaimUI.open) == "function" then
                        IKST_VehicleClaimUI.open(p, vid)
                    end
                end,
            }
        end
        if #vehicleActions == 0 then
            vehicleActions[1] = {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh nearby"),
                onClick = function()
                    IKST_JobGuard.requestNearbyVehicles(p)
                    IKST_JobGuard.requestClaims(p)
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillH, vehicleActions)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Guard_Vehicle_Label", "Label & transfer"))
        local uiState, vid = IKST_JobGuard.targetUiState(panel)
        local canEdit = uiState and uiState.canEdit == true
        local fields = {
            { text = panel:draftEntryText("guardVehicleLabelEntry", ""), fieldName = "guardVehicleLabelEntry" },
        }
        if isAdmin then
            fields[#fields + 1] = {
                text = panel:draftEntryText("guardVehicleOwnerEntry", ""),
                fieldName = "guardVehicleOwnerEntry",
            }
        end
        local actionLabel = IKST.text("IGUI_IKST_Guard_SetClaimLabel", "Set label")
        local onAction = function()
            local claimArgs = IKST_JobGuard.vehicleClaimArgs(panel)
            if not claimArgs then
                IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                return
            end
            claimArgs.label = IKST_JobGuard.readEntry(panel.guardVehicleLabelEntry)
            IKST.dispatchCommand(p, IKST.CMD.vehicleClaimSetLabel, claimArgs)
        end
        if isAdmin then
            actionLabel = IKST.text("IGUI_IKST_Guard_TransferClaim", "Transfer")
            onAction = function()
                local claimArgs = IKST_JobGuard.vehicleClaimArgs(panel)
                local newOwner = IKST_JobGuard.readEntry(panel.guardVehicleOwnerEntry)
                if not claimArgs then
                    IKST.notify(p, IKST.text("IGUI_IKST_Guard_Vehicle_None", "No vehicle nearby."), false)
                    return
                end
                if newOwner == "" then
                    claimArgs.label = IKST_JobGuard.readEntry(panel.guardVehicleLabelEntry)
                    IKST.dispatchCommand(p, IKST.CMD.vehicleClaimSetLabel, claimArgs)
                    return
                end
                claimArgs.owner = newOwner
                IKST.dispatchCommand(p, IKST.CMD.vehicleClaimTransfer, claimArgs)
                IKST_JobGuard.requestClaims(p)
                panel:refreshJobUI()
            end
        elseif not (vid and uiState and uiState.claimed and (canEdit or isAdmin)) then
            actionLabel = IKST.text("IGUI_IKST_RefreshList", "Refresh")
            onAction = function()
                IKST_JobGuard.requestNearbyVehicles(p)
                IKST_JobGuard.requestClaims(p)
            end
        end
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, fields, actionLabel, onAction)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
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
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_MpOnly",
            "Claim requests need multiplayer. Staff review them under Claim requests."), false)
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
        .. " — open IKST Claim Overview to finish the walk-draw request.", true)
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
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_MpOnly",
            "Claim requests need multiplayer. Staff review them under Claim requests."), false)
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
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimReq_MpOnly",
            "Claim requests need multiplayer. Staff review them under Claim requests."), false)
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
    local p = panel.player
    if not p then
        return 8
    end
    if not panel._claimOverviewListsRequested then
        panel._claimOverviewListsRequested = true
        IKST_JobGuard.requestSafehouses(p)
        IKST_JobGuard.requestClaims(p)
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local headerH = 36
    local btnW, btnH = IKST_JobLayout.standardPillSize(panel)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y

    local title = ISLabel:new(rect.x, rect.y, headerH, IKST.text("IGUI_IKST_WS_Claim", "Claim"), 1, 1, 1, 1, UIFont.Large, true)
    title:initialise()
    panel:addJobWidget(title)

    local claimState = IKST.getPlayerState(p)
    local reqLabel = IKST.text("IGUI_IKST_ClaimTile_RequestHouse", "Request house")
    local reqPrimary = false
    if claimState and claimState.claimReqA then
        reqLabel = IKST.text("IGUI_IKST_ClaimTile_MarkEnd", "Mark end (B)")
        reqPrimary = true
    end
    local ox, gridW = IKST_JobLayout.packFrame(rect.x, rect.w, btnW)
    local headerY = rect.y + math.floor((headerH - btnH) / 2)
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
        IKST_JobLayout.placePill(panel, panel, {
            x = ox,
            y = headerY,
            w = btnW,
            h = btnH,
        }, staffLabel, function()
            if panel.enterNav then
                panel:enterNav(IKST.VIEW.claim, "requests")
            end
        end, pendingN > 0)
    end
    local pillSpecs = {}
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowSafehouseClaimRequest(p) then
        pillSpecs[#pillSpecs + 1] = {
            label = reqLabel,
            primary = reqPrimary,
            fn = function()
                IKST_JobGuard.onRequestClaimClick(panel)
            end,
        }
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowVehicleClaimRequest(p) then
        pillSpecs[#pillSpecs + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_RequestVehicle", "Request vehicle"),
            fn = function()
                IKST_JobGuard.onRequestVehicleClaimClick(panel)
            end,
        }
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateSafehouseClaim(p) then
        pillSpecs[#pillSpecs + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_NewHouse", "+ House claim"),
            primary = true,
            fn = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.claim, "safehouses")
                end
            end,
        }
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateVehicleClaim(p) then
        pillSpecs[#pillSpecs + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_NewVehicle", "+ Vehicle claim"),
            primary = true,
            fn = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.claim, "vehicleclaim")
                end
            end,
        }
    end
    local pillX = ox + gridW - btnW
    for i = #pillSpecs, 1, -1 do
        local spec = pillSpecs[i]
        IKST_JobLayout.placePill(panel, panel, {
            x = pillX,
            y = headerY,
            w = btnW,
            h = btnH,
        }, spec.label, spec.fn, spec.primary)
        pillX = pillX - btnW - IKST_JobLayout.BTN_GAP
    end

    local bandsY = rect.y + headerH + gap
    local bandsH = rect.h - headerH - gap
    local bands = IKST_JobLayout.splitBands(bandsY, bandsH, 3, gap)

    local function openBand(band, titleText)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, titleText)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_ClaimTile_SectionSafehouse", "Safehouse claim"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local pillY = ay + listH + gapLP
        local pillH = math.max(btnH, pillH)
        local shList = IKST_JobGuard.safehouses or {}
        panel.guardSelectedSH = IKST_JobGuard.matchSafehouse(panel.guardSelectedSH, shList)
        if not panel.guardSelectedSH and #shList > 0 then
            panel.guardSelectedSH = shList[1]
        end
        local overviewShRows = {}
        for _, sh in ipairs(shList) do
            local label = tostring(sh.title or sh.owner or "?")
            if sh.x and sh.y then
                label = label .. "  -  " .. tostring(sh.x) .. ", " .. tostring(sh.y)
            end
            overviewShRows[#overviewShRows + 1] = {
                id = IKST_JobGuard.safehouseId(sh),
                label = label,
                data = sh,
            }
        end
        if #overviewShRows == 0 then
            overviewShRows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet."),
                data = nil,
            }
        end
        local filtered = IKST_JobLayout.filterRows(overviewShRows, panel.guardShFilter)
        local shBox = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, filtered, {
            selectedId = IKST_JobGuard.safehouseId(panel.guardSelectedSH),
            onSelect = function(row)
                if row and row.data then
                    panel.guardSelectedSH = row.data
                    panel:refreshJobUI(true)
                end
            end,
        })
        panel.guardOverviewShList = shBox

        local sh = panel.guardSelectedSH
        local shPills = {
            {
                label = IKST.text("IGUI_IKST_SH_Members", "Members"),
                onClick = function()
                    if not sh then
                        return
                    end
                    if IKST_SafehouseClaimUI and type(IKST_SafehouseClaimUI.open) == "function" then
                        local memberScope = nil
                        if IKST_SafehousePermissions then
                            memberScope = IKST_SafehousePermissions.GROUP_MEMBER
                        end
                        IKST_SafehouseClaimUI.open(p, sh.x, sh.y, sh.w, sh.h, memberScope)
                    end
                end,
            },
        }
        if sh and sh.canEdit then
            shPills[#shPills + 1] = {
                label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Perms"),
                primary = true,
                onClick = function()
                    if IKST_SafehouseClaimUI and type(IKST_SafehouseClaimUI.open) == "function" then
                        IKST_SafehouseClaimUI.open(p, sh.x, sh.y, sh.w, sh.h)
                    end
                end,
            }
        end
        if sh and sh.canRespawn then
            shPills[#shPills + 1] = {
                label = IKST_JobGuard.respawnChipLabel(sh),
                primary = sh.respawnOn == true,
                onClick = function()
                    IKST_JobGuard.dispatchSafehouseRespawn(p, sh)
                end,
            }
        end
        if sh and sh.canRelease then
            shPills[#shPills + 1] = {
                label = IKST.text("IGUI_IKST_ClaimTile_Abandon", "Abandon"),
                onClick = function()
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
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillH, shPills)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_ClaimTile_SectionVehicle", "Vehicle claim"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local pillY = ay + listH + gapLP
        local pillH = math.max(btnH, pillH)
        local vList = IKST_JobGuard.claims or {}
        if panel.guardSelectedClaimId == nil and #vList > 0 then
            panel.guardSelectedClaimId = vList[1].id
        end
        local overviewVRows = {}
        for _, claim in ipairs(vList) do
            local label = tostring(claim.displayLabel or claim.script or ("#" .. tostring(claim.id or "?")))
            if claim.x and claim.y then
                label = label .. "  -  " .. tostring(claim.x) .. ", " .. tostring(claim.y)
            end
            overviewVRows[#overviewVRows + 1] = { id = claim.id, label = label, data = claim }
        end
        if #overviewVRows == 0 then
            overviewVRows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_ClaimTile_NoVehicles", "No vehicle claims yet."),
                data = nil,
            }
        end
        local filtered = IKST_JobLayout.filterRows(overviewVRows, panel.guardClaimFilter)
        local vBox = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, filtered, {
            selectedId = panel.guardSelectedClaimId,
            onSelect = function(row)
                if row and row.data then
                    panel.guardSelectedClaimId = row.id
                    panel.guardVehicleId = row.id
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end
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
        local vPills = {
            {
                label = IKST.text("IGUI_IKST_SH_Members", "Members"),
                onClick = function()
                    if selectedClaim and IKST_VehicleClaimUI and type(IKST_VehicleClaimUI.open) == "function" then
                        IKST_VehicleClaimUI.open(p, selectedClaim.id)
                    end
                end,
            },
        }
        if selectedClaim and selectedClaim.canEdit then
            vPills[#vPills + 1] = {
                label = IKST.text("IGUI_IKST_ClaimTile_Keys", "Keys"),
                primary = true,
                onClick = function()
                    if IKST_VehicleClaimUI and type(IKST_VehicleClaimUI.open) == "function" then
                        IKST_VehicleClaimUI.open(p, selectedClaim.id)
                    end
                end,
            }
        end
        if selectedClaim and selectedClaim.canRelease then
            vPills[#vPills + 1] = {
                label = IKST.text("IGUI_IKST_ClaimTile_Abandon", "Abandon"),
                onClick = function()
                    IKST_Confirm.showDestructive(
                        IKST.text("IGUI_IKST_ClaimTile_ConfirmAbandonVeh", "Abandon this vehicle claim?"),
                        function()
                            IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, { vehicleId = selectedClaim.id })
                            IKST_JobGuard.requestClaims(p)
                        end
                    )
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillH, vPills)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_ClaimTile_SectionQuick", "Quick tools"))
        local isStaff = IKST_Access and type(IKST_Access.canUseStaffTools) == "function" and IKST_Access.canUseStaffTools(p)
        local quickItems = {}
        if isStaff then
            quickItems[#quickItems + 1] = {
                label = IKST.text("IGUI_IKST_ClaimTile_Catch", "Catch"),
                primary = true,
                onClick = function()
                    local t = IKST_JobStaff.getSelectedTarget(panel)
                    if t then
                        IKST.dispatchCommand(p, IKST.CMD.catchTarget, { target = t.id })
                    elseif panel.enterNav then
                        panel:enterNav(IKST.VIEW.claim, "catch")
                    end
                end,
            }
        end
        quickItems[#quickItems + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_ListAll", "List all"),
            onClick = function()
                IKST_JobGuard.requestSafehouses(p)
                IKST_JobGuard.requestClaims(p)
                IKST.notify(p, IKST.text("IGUI_IKST_ClaimTile_ListAllDone", "Refreshing claim lists..."), true)
                panel:refreshJobUI()
            end,
        }
        quickItems[#quickItems + 1] = {
            label = IKST.text("IGUI_IKST_ClaimTile_Dispute", "Dispute"),
            onClick = function()
                IKST_JobGuard.openDisputeBox(p)
            end,
        }
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, quickItems)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobGuard.buildClaimRequests(panel)
    local p = panel.player
    if not p then
        return 8
    end
    if not IKST_JobStaff then
        require "IKST_JobStaff"
    end
    if not panel._claimRequestsRequested then
        panel._claimRequestsRequested = true
        if IKST_JobStaff and type(IKST_JobStaff.requestClaimRequests) == "function" then
            IKST_JobStaff.requestClaimRequests(p)
        end
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H
    local title = ISLabel:new(rect.x, rect.y, 28,
        IKST.text("IGUI_IKST_ClaimRequestQueue", "Claim requests"), 1, 1, 1, 1, UIFont.Large, true)
    title:initialise()
    panel:addJobWidget(title)

    local note = ISLabel:new(rect.x, rect.y + 28, 18,
        IKST.text("IGUI_IKST_ClaimRequestHelp",
            "Player walk-draw zones waiting for staff approve/deny. Not vanilla F1 tickets."),
        0.75, 0.78, 0.82, 1, UIFont.Small, true)
    note:initialise()
    panel:addJobWidget(note)

    local bandY = rect.y + 52
    local bandH = math.max(120, rect.h - 52)
    local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, bandY, rect.w, bandH, nil,
        IKST.text("IGUI_IKST_ClaimRequestQueue", "Claim requests"))
    local ax = inner
    local aw = math.max(40, rect.w - inner * 2)
    local ay = contentY + padY
    local ah = math.max(btnH + 48, bandH - contentY - padY * 2)
    if IKST_JobStaff and type(IKST_JobStaff.placeClaimRequestQueue) == "function" then
        IKST_JobStaff.placeClaimRequestQueue(panel, card, ax, ay, aw, ah, p)
    end
    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobGuard.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end

    if panel.view == IKST.VIEW.claim and state.navTool == "requests" then
        state.guardMode = "requests"
        return IKST_JobGuard.buildClaimRequests(panel)
    end

    if panel.view == IKST.VIEW.claim and (state.navTool == "overview" or not state.navTool) then
        state.navTool = "overview"
        state.guardMode = "overview"
        return IKST_JobGuard.buildClaimOverview(panel)
    end

    if panel.view == IKST.VIEW.server and state.navTool == "safehouses" then
        state.guardMode = "safehouses"
        return IKST_JobGuard.buildSafehouses(panel, 8)
    end

    local tab = panel.view
    if tab == IKST.VIEW.safehouses then
        state.guardMode = "safehouses"
    elseif not state.guardMode or state.guardMode == "overview" then
        state.guardMode = "safehouses"
    end
    local isStaff = IKST_Access and type(IKST_Access.canUseStaffTools) == "function" and IKST_Access.canUseStaffTools(panel.player)
    if not isStaff and (state.guardMode == "tools" or state.guardMode == "tiles"
        or state.guardMode == "containers" or state.guardMode == "farming" or state.guardMode == "protect") then
        state.guardMode = "safehouses"
    end

    local y = 8
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

    local mode = state.guardMode
    if mode == "tools" then
        return IKST_JobGuard.buildTools(panel, y)
    elseif mode == "safehouses" then
        return IKST_JobGuard.buildSafehouses(panel, y)
    elseif mode == "vehicles" then
        return IKST_JobGuard.buildVehicles(panel, y)
    elseif mode == "tiles" or mode == "containers" or mode == "farming" or mode == "protect" then
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
