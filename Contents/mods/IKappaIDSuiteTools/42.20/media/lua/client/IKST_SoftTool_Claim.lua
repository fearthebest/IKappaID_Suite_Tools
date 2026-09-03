-- SoftTool Claim: soft-shell Claim workspace painted exclusively via IKUI_SoftBody.
-- Helpers (request/dispatch/pills/lists) stay on IKST_JobGuard.
-- Sections use absolute page coords; pills/fields inside cards use card-local coords.
-- masterDetail always on absolute band/page rects (never card-local ax/ay).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_ClaimPolicy"
require "IKST_Claim"
require "IKST_Confirm"
require "IKappaID_UI/IKUI_SoftBody"
require "IKappaID_UI/IKUI_Chrome"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"

IKST_SoftTool_Claim = IKST_SoftTool_Claim or {}

function IKST_SoftTool_Claim.buildTools(panel, contentTop)
    local p = panel.player

    local rect = IKUI_SoftBody.contentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H

    local function openCol(col, title)
        local card, contentY = IKUI_SoftBody.section(panel, col.x, col.y, col.w, col.h, title)
        local areaX = inner
        local areaW = math.max(40, col.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, col.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    local function fillPlayers(card, ax, ay, aw, ah)
        if not IKST_JobStaff then
            require "IKST_JobStaff"
        end
        if IKST_JobStaff and type(IKST_JobStaff.requestPlayers) == "function" and not panel._catchPlayersRequested then
            panel._catchPlayersRequested = true
            IKST_JobStaff.requestPlayers(p)
        end
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1, true)
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, nil, listH)
        local pillAreaY = listBottom + gapLP
        local pillAreaH = math.max(btnH, pillH)
        if pillAreaY + pillAreaH > ay + ah then
            pillAreaY = math.max(ay, ay + ah - pillAreaH)
        end
        IKUI_SoftBody.pillRow(panel, card, ax, pillAreaY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobStaff.requestPlayers(p)
                end,
            },
        })
    end

    local function fillCatch(card, ax, ay, aw, ah)
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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

    -- Soft-only: list | catch (Aegis softMasterDetail). Dock splitBands removed.
    local left, right = IKUI_SoftBody.masterDetail(rect, 280, 12)
    do
        local card, ax, ay, aw, ah = openCol(left, IKST.text("IGUI_IKST_Util_Players", "Online players"))
        fillPlayers(card, ax, ay, aw, ah)
    end
    do
        local card, ax, ay, aw, ah = openCol(right, IKST.text("IGUI_IKST_Guard_Catch", "Catch"))
        fillCatch(card, ax, ay, aw, ah)
    end
    return rect.y + rect.h
end

function IKST_SoftTool_Claim.buildSafehouses(panel, contentTop)
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

    local rect = IKUI_SoftBody.contentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local inner = IKUI_SoftBody.SECTION_INNER or 8
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H or 36
    local canSelf = IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateSafehouseClaim
        and IKST_ClaimPolicy.mayCreateSafehouseClaim(p)
    local requestOnly = IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowSafehouseClaimRequest
        and IKST_ClaimPolicy.mayShowSafehouseClaimRequest(p)
    -- Request-only: no Size / Claim mode form — A→B walk is the acquire path.
    local showSelfForm = canSelf == true and not requestOnly
    if canSelf and IKST_ClaimPolicy.mayRequestSafehouseClaim
        and IKST_ClaimPolicy.mayRequestSafehouseClaim(p) then
        showSelfForm = true
    end
    -- Size band: one pill row + WxH + Apply (do NOT use compactPillBandH for the pill strip —
    -- that helper includes a section header and blows the budget → fields spill into the next band).
    local headerH = IKUI_SoftBody.sectionHeaderH()
    local sizePillH = btnH + 4
    local sizeFieldH = (IKUI_SoftBody.FIELD_H or 32) + gap + btnH
    local sizeBandH = headerH + inner * 2 + sizePillH + gap + sizeFieldH + 8
    local bandsY = rect.y
    local bandsH = rect.h
    local bands
    local stackBottom
    local soft = true
    if showSelfForm then
        local claimModeH = IKUI_SoftBody.compactPillBandH(1)
        local listBandY = bandsY + claimModeH + gap + sizeBandH + gap
        local listBandH = math.max(80, bandsH - claimModeH - gap - sizeBandH - gap)
        bands = {
            { y = bandsY, h = claimModeH },
            { y = bandsY + claimModeH + gap, h = sizeBandH },
            { y = listBandY, h = listBandH },
        }
        stackBottom = listBandY + listBandH
    else
        local listBandH = math.max(80, bandsH)
        bands = {
            { y = bandsY, h = listBandH },
        }
        stackBottom = bandsY + listBandH
    end
    -- Children of a section card use coords relative to that card.
    local function openBand(band, title)
        local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, title)
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

    if showSelfForm then
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
            IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
        end

        do
            local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Size_Label", "Size"))
            local sizeMap = {
                { label = "S", val = 11 },
                { label = "M", val = 13 },
                { label = "L", val = 21 },
                { label = "XL", val = 31 },
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
            local presetH = sizePillH
            if presetH > ah then
                presetH = math.max(btnH, math.floor(ah * 0.4))
            end
            IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, presetH, items)
            local fieldY = ay + presetH + gap
            local fieldH = math.max(btnH, ah - presetH - gap)
            IKUI_SoftBody.fieldAction(panel, card, ax, fieldY, aw, fieldH, {
                { text = panel:draftEntryText("guardShWEntry", tostring(state.guardShW or 13)), fieldName = "guardShWEntry" },
                { text = panel:draftEntryText("guardShHEntry", tostring(state.guardShH or 13)), fieldName = "guardShHEntry" },
            }, IKST.text("IGUI_IKST_Guard_SH_ApplySize", "Apply"), function()
                IKST_JobGuard.applyShDimensions(panel, state)
                panel:refreshJobUI()
            end)
        end
    end

    -- List | Manage: softMasterDetail on ABSOLUTE band rect (never nest with card-local ax/ay).
    do
        local actionsBand = showSelfForm and bands[3] or bands[1]
        local mdRect = {
            x = rect.x,
            y = actionsBand.y,
            w = rect.w,
            h = actionsBand.h,
        }
        if IKST_ClaimPermissionsUI.hasSoft(panel) then
            local card, ax, ay, aw, ah = openBand(actionsBand,
                IKST.text("IGUI_IKST_ClaimTile_SectionManage", "Manage"))
            IKST_ClaimPermissionsUI.placeSoft(panel, card, ax, ay, aw, ah, p)
        elseif panel._ikstSoftInvite then
            local card, ax, ay, aw, ah = openBand(actionsBand,
                IKST.text("IGUI_IKST_ClaimInvite_Invite", "Invite"))
            IKST_JobGuard.placeSoftInvite(panel, card, ax, ay, aw, ah, p)
        else
            local left, right = IKUI_SoftBody.masterDetail(mdRect, 280, gap)
            local list = IKST_JobGuard.getSafehouses()
            panel.guardSelectedSH = IKST_JobGuard.pickPreferredSafehouse(list, panel.guardSelectedSH)
            local rows = IKST_JobLayout.filterRows(IKST_JobGuard.safehouseListRows(list), panel.guardShFilter)
            if #rows == 0 then
                rows[1] = {
                    id = "_empty",
                    label = IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet. Use Claim here or Refresh."),
                    data = nil,
                }
            end
            local listCard, listCY = IKUI_SoftBody.section(panel, left.x, left.y, left.w, left.h,
                IKST.text("IGUI_IKST_ClaimTile_SectionSafehouse", "Safehouses"))
            local listAx = inner
            local listAw = math.max(40, left.w - inner * 2)
            local listAy = listCY + padY
            local listAh = math.max(btnH, left.h - listCY - padY * 2)
            panel.guardShList = IKST_JobLayout.makeSelectList(panel, listCard, listAx, listAy, listAw, listAh, rows, {
                selectedId = IKST_JobGuard.safehouseId(panel.guardSelectedSH),
                onSelect = function(row)
                    if row and row.data then
                        panel.guardSelectedSH = row.data
                        IKST_ClaimPermissionsUI.clearSoft(panel)
                        panel._ikstSoftInvite = nil
                        panel:refreshJobUI(true)
                    end
                end,
            })
            local actCard, actCY = IKUI_SoftBody.section(panel, right.x, right.y, right.w, right.h,
                IKST.text("IGUI_IKST_ClaimTile_SectionManage", "Manage"))
            local actAx = inner
            local actAw = math.max(40, right.w - inner * 2)
            local actAy = actCY + padY
            local actAh = math.max(btnH, right.h - actCY - padY * 2)
            local actionItems = IKST_JobGuard.safehouseActionPills(panel, p, isAdmin, isStaff, state)
            if #actionItems > 0 then
                IKUI_SoftBody.pillRow(panel, actCard, actAx, actAy, actAw, actAh, actionItems)
            end
        end
    end

    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end

function IKST_SoftTool_Claim.buildVehicles(panel, contentTop)
    local p = panel.player
    local isAdmin = IKST_Access and IKST_Access.canUseTools(p)

    local rect = IKUI_SoftBody.contentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bandsY = rect.y
    local bandsH = rect.h
    local fieldRows = isAdmin and 2 or 1
    local labelH = IKUI_SoftBody.fieldActionBandH(fieldRows)
    local listAreaH = math.max(100, bandsH - labelH - gap)
    local claimsH = math.floor((listAreaH - gap) / 2)
    local nearbyH = listAreaH - claimsH - gap
    if listAreaH >= 166 then
        claimsH = math.max(80, claimsH)
        nearbyH = math.max(80, nearbyH)
        if claimsH + gap + nearbyH > listAreaH then
            claimsH = math.max(80, listAreaH - gap - nearbyH)
        end
    end
    local labelY = bandsY + listAreaH + gap
    local bands = {
        { y = bandsY, h = claimsH },
        { y = bandsY + claimsH + gap, h = nearbyH },
        { y = labelY, h = labelH },
    }
    local stackBottom = labelY + labelH
    local soft = true
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Guard_Vehicle_Claims", "Claims"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1)
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
                    local cfg = IKST_ClaimPermissionsUI.vehicleConfig(selectedClaim.id, selectedClaim.claimKey)
                    IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                    panel:refreshJobUI(true)
                end,
            }
        end
        if soft and IKST_ClaimPermissionsUI.hasSoft(panel) then
            IKST_ClaimPermissionsUI.placeSoft(panel, card, ax, ay, aw, ah, p)
        else
            IKUI_SoftBody.pillRow(panel, card, ax, pillY, aw, pillH, claimActions)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Vehicle_nearby", "Nearby"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1)
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
                    local cfg = IKST_ClaimPermissionsUI.vehicleConfig(vid)
                    IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                    if type(panel.refreshJobUI) == "function" then
                        panel:refreshJobUI(true)
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
        IKUI_SoftBody.pillRow(panel, card, ax, pillY, aw, pillH, vehicleActions)
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
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, fields, actionLabel, onAction)
    end

    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end


function IKST_SoftTool_Claim.buildClaimOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local now = 0
    if getTimestampMs and type(getTimestampMs) == "function" then
        now = getTimestampMs()
    end
    if not panel._claimOverviewListAt or (now - panel._claimOverviewListAt) > 1500 then
        panel._claimOverviewListAt = now
        IKST_JobGuard.requestSafehouses(p)
        IKST_JobGuard.requestClaims(p)
    end
    if IKST_SafehouseClaimClient and type(IKST_SafehouseClaimClient.mergeMissingOwnedRows) == "function" then
        IKST_SafehouseClaimClient.mergeMissingOwnedRows(p)
    end

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = 6
    local btnW, btnH = IKUI_SoftBody.standardPillSize(rect.w - (IKUI_SoftBody.SECTION_INNER * 2))
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    -- SoftTool is soft-shell only: HubNav owns tool rail (no in-body Claim title row).
    local softNav = true
    local overviewCtas = IKST_JobGuard.claimOverviewActionPills(panel, p)

    local bandsY = rect.y
    local bandsH = rect.h
    local bandRect = { x = rect.x, y = bandsY, w = rect.w, h = bandsH }
    local ctaRows = 1
    if #overviewCtas > 3 then
        ctaRows = 2
    end
    local ctaH = IKUI_SoftBody.compactPillBandH(math.max(1, ctaRows))
    local quickH = IKUI_SoftBody.compactPillBandH(1)
    local listAreaY = bandsY + ctaH + gap
    local listAreaH = math.max(100, bandsH - ctaH - quickH - gap * 2)
    local shBandH = math.floor((listAreaH - gap) / 2)
    local vehBandH = listAreaH - shBandH - gap
    if listAreaH >= 166 then
        shBandH = math.max(80, shBandH)
        vehBandH = math.max(80, vehBandH)
        if shBandH + gap + vehBandH > listAreaH then
            shBandH = math.max(80, listAreaH - gap - vehBandH)
        end
    end
    local bands = {
        { y = bandsY, h = ctaH },
        { y = listAreaY, h = shBandH },
        { y = listAreaY + shBandH + gap, h = vehBandH },
        { y = listAreaY + listAreaH + gap, h = quickH },
    }
    local stackBottom = bands[4].y + bands[4].h
    local soft = true

    local function openBand(band, titleText)
        local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, titleText)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    local shBandIndex = 1
    local vehBandIndex = 2
    local quickBandIndex = 3
    if softNav then
        do
            local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_ClaimTile_SectionGet", "Get a claim"))
            if not panel._ikstInviteListAsked then
                panel._ikstInviteListAsked = true
                if IKST_SafehouseInviteClient and type(IKST_SafehouseInviteClient.requestList) == "function" then
                    IKST_SafehouseInviteClient.requestList(p)
                end
            end
            local inviteItems = {}
            local pending = IKST_SafehouseInviteClient and IKST_SafehouseInviteClient.pending or {}
            for i = 1, #pending do
                local inv = pending[i]
                if inv and inv.x ~= nil then
                    inviteItems[#inviteItems + 1] = {
                        label = IKST.text("IGUI_IKST_ClaimInvite_Accept", "Accept") .. ": " .. tostring(inv.from or inv.owner or "?"),
                        primary = true,
                        onClick = function()
                            IKST.dispatchCommand(p, IKST.CMD.safehouseInviteRespond, {
                                accept = true,
                                x = inv.x, y = inv.y, w = inv.w, h = inv.h, id = inv.id, owner = inv.owner,
                            })
                        end,
                    }
                    inviteItems[#inviteItems + 1] = {
                        label = IKST.text("IGUI_IKST_ClaimInvite_Decline", "Decline") .. ": " .. tostring(inv.from or inv.owner or "?"),
                        onClick = function()
                            IKST.dispatchCommand(p, IKST.CMD.safehouseInviteRespond, {
                                accept = false,
                                x = inv.x, y = inv.y, w = inv.w, h = inv.h, id = inv.id, owner = inv.owner,
                            })
                        end,
                    }
                end
            end
            local allCtas = {}
            for i = 1, #inviteItems do
                allCtas[#allCtas + 1] = inviteItems[i]
            end
            for i = 1, #overviewCtas do
                allCtas[#allCtas + 1] = overviewCtas[i]
            end
            if #allCtas > 0 then
                IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, allCtas)
            else
                local empty = ISLabel:new(ax, ay, 16,
                    IKST.text("IGUI_IKST_ClaimTile_NoPlayerClaimPath",
                        "House claims use staff approval on this server (or self-service is off)."),
                    1, 1, 1, 1, UIFont.Small, true)
                empty:initialise()
                card:addChild(empty)
            end
        end
        shBandIndex = 2
        vehBandIndex = 3
        quickBandIndex = 4
    end

    do
        local overviewShRows = IKST_JobGuard.overviewSafehouseRows(p)
        if panel.guardSelectedSH and panel.guardSelectedSH.draft ~= true then
            panel.guardSelectedSH = IKST_JobGuard.pickPreferredSafehouse(
                IKST_JobGuard.getSafehouses(), panel.guardSelectedSH)
        end
        if not panel.guardSelectedSH then
            for i = 1, #overviewShRows do
                local row = overviewShRows[i]
                if row and row.data and row.data.draft == true then
                    panel.guardSelectedSH = row.data
                    break
                end
            end
        end
        if #overviewShRows == 0 then
            overviewShRows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_Guard_SH_None", "No safehouses yet."),
                data = nil,
            }
        end
        local filtered = IKST_JobLayout.filterRows(overviewShRows, panel.guardShFilter)

        local function buildShActionPills(sh)
            local shPills = {}
            if not sh then
                return shPills
            end
            if sh.draft == true then
                shPills[#shPills + 1] = {
                    label = IKST.text("IGUI_IKST_ClaimTile_MarkEnd", "Mark end (B)"),
                    primary = sh.ready == true,
                    onClick = function()
                        IKST_JobGuard.onRequestClaimClick(panel)
                    end,
                }
                shPills[#shPills + 1] = {
                    label = IKST.text("IGUI_IKST_Cancel", "Cancel"),
                    onClick = function()
                        if IKST_ClaimRequestDraw and type(IKST_ClaimRequestDraw.clear) == "function" then
                            IKST_ClaimRequestDraw.clear(p)
                        else
                            local st = IKST.getPlayerState(p)
                            if st then
                                st.claimReqA = nil
                                st.claimReqDraw = nil
                            end
                        end
                        panel.guardSelectedSH = nil
                        panel:refreshJobUI(true)
                    end,
                }
                return shPills
            end
            local mayManage = sh.canEdit == true or sh.isMine == true
                or (IKST_Access and type(IKST_Access.canUseTools) == "function" and IKST_Access.canUseTools(p))
            if mayManage then
                shPills[#shPills + 1] = {
                    label = IKST.text("IGUI_IKST_ClaimInvite_Invite", "Invite"),
                    onClick = function()
                        panel._ikstSoftInvite = {
                            x = sh.x, y = sh.y, w = sh.w, h = sh.h, id = sh.id, owner = sh.owner,
                        }
                        IKST_ClaimPermissionsUI.clearSoft(panel)
                        panel:refreshJobUI(true)
                    end,
                }
                shPills[#shPills + 1] = {
                    label = IKST.text("IGUI_IKST_SH_Members", "Members"),
                    onClick = function()
                        local cfg = IKST_ClaimPermissionsUI.safehouseConfig(sh.x, sh.y, sh.w, sh.h)
                        if IKST_SafehousePermissions then
                            cfg.defaultScope = IKST_SafehousePermissions.GROUP_MEMBER
                        end
                        panel._ikstSoftInvite = nil
                        IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                        panel:refreshJobUI(true)
                    end,
                }
                if sh.canEdit then
                    shPills[#shPills + 1] = {
                        label = IKST.text("IGUI_IKST_VehicleClaim_Perms", "Perms"),
                        primary = true,
                        onClick = function()
                            local cfg = IKST_ClaimPermissionsUI.safehouseConfig(sh.x, sh.y, sh.w, sh.h)
                            panel._ikstSoftInvite = nil
                            IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                            panel:refreshJobUI(true)
                        end,
                    }
                end
            end
            if sh.canRespawn then
                shPills[#shPills + 1] = {
                    label = IKST_JobGuard.respawnChipLabel(sh),
                    primary = sh.respawnOn == true,
                    onClick = function()
                        IKST_JobGuard.dispatchSafehouseRespawn(p, sh)
                    end,
                }
            end
            if sh.canRelease == true and (sh.isMine == true
                or (IKST_Access and type(IKST_Access.canUseTools) == "function" and IKST_Access.canUseTools(p))) then
                shPills[#shPills + 1] = {
                    label = IKST.text("IGUI_IKST_Guard_SH_Release", "Release"),
                    onClick = function()
                        IKST_Confirm.showDestructive(
                            IKST.text("IGUI_IKST_ClaimTile_ConfirmAbandonSH", "Release this safehouse claim?"),
                            function()
                                IKST.dispatchCommand(p, IKST.CMD.safehouseRelease, {
                                    x = sh.x, y = sh.y, w = sh.w, h = sh.h, id = sh.id, owner = sh.owner,
                                })
                                panel.guardSelectedSH = nil
                                IKST_ClaimPermissionsUI.clearSoft(panel)
                                IKST_JobGuard.requestSafehouses(p)
                            end
                        )
                    end,
                }
            end
            return shPills
        end

        -- Soft: SE Claims Manager shape — list | selection CTAs (Aegis softMasterDetail).
        do
            local band = bands[shBandIndex]
            local mdRect = { x = rect.x, y = band.y, w = rect.w, h = band.h }
            local left, right = IKUI_SoftBody.masterDetail(mdRect, 280, gap)
            local listCard, listCY = IKUI_SoftBody.section(panel, left.x, left.y, left.w, left.h,
                IKST.text("IGUI_IKST_ClaimTile_SectionSafehouse", "Safehouses"))
            local listAx = inner
            local listAw = math.max(40, left.w - inner * 2)
            local listAy = listCY + padY
            local listAh = math.max(btnH, left.h - listCY - padY * 2)
            local shBox = IKST_JobLayout.makeSelectList(panel, listCard, listAx, listAy, listAw, listAh, filtered, {
                selectedId = IKST_JobGuard.safehouseId(panel.guardSelectedSH),
                onSelect = function(row)
                    if row and row.data then
                        panel.guardSelectedSH = row.data
                        IKST_ClaimPermissionsUI.clearSoft(panel)
                        panel:refreshJobUI(true)
                    end
                end,
            })
            panel.guardOverviewShList = shBox

            local actCard, actCY = IKUI_SoftBody.section(panel, right.x, right.y, right.w, right.h,
                IKST.text("IGUI_IKST_ClaimTile_SectionManage", "Manage"))
            local actAx = inner
            local actAw = math.max(40, right.w - inner * 2)
            local actAy = actCY + padY
            local actAh = math.max(btnH, right.h - actCY - padY * 2)
            if IKST_ClaimPermissionsUI.hasSoft(panel) then
                IKST_ClaimPermissionsUI.placeSoft(panel, actCard, actAx, actAy, actAw, actAh, p)
            elseif panel._ikstSoftInvite then
                IKST_JobGuard.placeSoftInvite(panel, actCard, actAx, actAy, actAw, actAh, p)
            else
                local sh = panel.guardSelectedSH
                local shPills = buildShActionPills(sh)
                if #shPills > 0 then
                    IKUI_SoftBody.pillRow(panel, actCard, actAx, actAy, actAw, actAh, shPills)
                else
                    local hint = IKST.text("IGUI_IKST_ClaimTile_SelectToManage",
                        "Select your claim to manage members or release.")
                    if #overviewShRows == 0 or (overviewShRows[1] and overviewShRows[1].id == "_empty") then
                        hint = IKST.text("IGUI_IKST_ClaimTile_AcquireHint",
                            "Use Get a claim above (or Claim → Safehouses) to request or claim.")
                    elseif panel.guardSelectedSH and panel.guardSelectedSH.draft == true then
                        hint = IKST.format("IGUI_IKST_ClaimOverview_DraftHint",
                            "Orange borders are a draft only. Walk until at least {1}x{1}, then Mark end to send to staff.",
                            tostring(IKST_Claim.MIN_DIM))
                    end
                    local empty = ISLabel:new(actAx, actAy, 16, hint, 1, 1, 1, 1, UIFont.Small, true)
                    empty:initialise()
                    actCard:addChild(empty)
                end
            end
        end
    end

    do
        local band = bands[vehBandIndex]
        local mdRect = { x = rect.x, y = band.y, w = rect.w, h = band.h }
        local left, right = IKUI_SoftBody.masterDetail(mdRect, 280, gap)
        local vList = IKST_JobGuard.claims or {}
        local stillListed = false
        if panel.guardSelectedClaimId ~= nil then
            for _, claim in ipairs(vList) do
                if claim.id == panel.guardSelectedClaimId then
                    stillListed = true
                    break
                end
            end
        end
        if not stillListed then
            panel.guardSelectedClaimId = nil
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
        local listCard, listCY = IKUI_SoftBody.section(panel, left.x, left.y, left.w, left.h,
            IKST.text("IGUI_IKST_ClaimTile_SectionVehicle", "Vehicle claim"))
        local listAx = inner
        local listAw = math.max(40, left.w - inner * 2)
        local listAy = listCY + padY
        local listAh = math.max(btnH, left.h - listCY - padY * 2)
        panel.guardOverviewVList = IKST_JobLayout.makeSelectList(panel, listCard, listAx, listAy, listAw, listAh, filtered, {
            selectedId = panel.guardSelectedClaimId,
            onSelect = function(row)
                if row and row.data then
                    panel.guardSelectedClaimId = row.id
                    panel.guardVehicleId = row.id
                    panel.selectedVehicleId = row.id
                    IKST_ClaimPermissionsUI.clearSoft(panel)
                    panel:refreshJobUI(true)
                end
            end,
        })

        local selectedClaim
        for _, claim in ipairs(vList) do
            if claim.id == panel.guardSelectedClaimId then
                selectedClaim = claim
                break
            end
        end
        local actCard, actCY = IKUI_SoftBody.section(panel, right.x, right.y, right.w, right.h,
            IKST.text("IGUI_IKST_ClaimTile_SectionManage", "Manage"))
        local actAx = inner
        local actAw = math.max(40, right.w - inner * 2)
        local actAy = actCY + padY
        local actAh = math.max(btnH, right.h - actCY - padY * 2)
        if IKST_ClaimPermissionsUI.hasSoft(panel) then
            IKST_ClaimPermissionsUI.placeSoft(panel, actCard, actAx, actAy, actAw, actAh, p)
        else
            local vPills = {}
            if selectedClaim then
                local mayManage = selectedClaim.canEdit == true or selectedClaim.isMine == true
                    or (IKST_Access and type(IKST_Access.canUseTools) == "function" and IKST_Access.canUseTools(p))
                if mayManage then
                    vPills[#vPills + 1] = {
                        label = IKST.text("IGUI_IKST_SH_Members", "Members"),
                        onClick = function()
                            local cfg = IKST_ClaimPermissionsUI.vehicleConfig(selectedClaim.id, selectedClaim.claimKey)
                            IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                            panel:refreshJobUI(true)
                        end,
                    }
                    if selectedClaim.canEdit then
                        vPills[#vPills + 1] = {
                            label = IKST.text("IGUI_IKST_ClaimTile_Keys", "Keys"),
                            primary = true,
                            onClick = function()
                                local cfg = IKST_ClaimPermissionsUI.vehicleConfig(selectedClaim.id, selectedClaim.claimKey)
                                IKST_ClaimPermissionsUI.beginSoft(panel, cfg)
                                panel:refreshJobUI(true)
                            end,
                        }
                    end
                end
                if selectedClaim.canRelease then
                    vPills[#vPills + 1] = {
                        label = IKST.text("IGUI_IKST_ClaimTile_Abandon", "Abandon"),
                        onClick = function()
                            IKST_Confirm.showDestructive(
                                IKST.text("IGUI_IKST_ClaimTile_ConfirmAbandonVeh", "Abandon this vehicle claim?"),
                                function()
                                    IKST.dispatchCommand(p, IKST.CMD.vehicleReleaseClaim, { vehicleId = selectedClaim.id })
                                    panel.guardSelectedClaimId = nil
                                    IKST_ClaimPermissionsUI.clearSoft(panel)
                                    IKST_JobGuard.requestClaims(p)
                                end
                            )
                        end,
                    }
                end
            end
            if #vPills > 0 then
                IKUI_SoftBody.pillRow(panel, actCard, actAx, actAy, actAw, actAh, vPills)
            else
                local empty = ISLabel:new(actAx, actAy, 16,
                    IKST.text("IGUI_IKST_ClaimTile_SelectToManage",
                        "Select your claim to manage members or release."),
                    1, 1, 1, 1, UIFont.Small, true)
                empty:initialise()
                actCard:addChild(empty)
            end
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[quickBandIndex], IKST.text("IGUI_IKST_ClaimTile_SectionQuick", "Quick tools"))
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
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, quickItems)
    end

    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end

function IKST_SoftTool_Claim.buildClaimRequests(panel)
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

    local rect = IKUI_SoftBody.contentRect(panel)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local note = ISLabel:new(rect.x, rect.y, 18,
        IKST.text("IGUI_IKST_ClaimRequestHelp",
            "Player walk-draw zones waiting for staff approve/deny. Not vanilla F1 tickets."),
        0.75, 0.78, 0.82, 1, UIFont.Small, true)
    note:initialise()
    panel:addJobWidget(note)

    local bandY = rect.y + 26
    local bandH = math.max(120, rect.h - 26)
    local card, contentY = IKUI_SoftBody.section(panel, rect.x, bandY, rect.w, bandH,
        IKST.text("IGUI_IKST_ClaimRequestQueue", "Claim requests"))
    local ax = inner
    local aw = math.max(40, rect.w - inner * 2)
    local ay = contentY + padY
    local ah = math.max(btnH + 48, bandH - contentY - padY * 2)
    if IKST_JobStaff and type(IKST_JobStaff.placeClaimRequestQueue) == "function" then
        IKST_JobStaff.placeClaimRequestQueue(panel, card, ax, ay, aw, ah, p)
    end
    return rect.y + rect.h
end


function IKST_SoftTool_Claim.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    -- Ensure soft content rect is available for SoftBody.contentRect.
    local _rect = IKUI_SoftBody.contentRect(panel)

    if state.navTool == "requests" then
        state.guardMode = "requests"
        return IKST_SoftTool_Claim.buildClaimRequests(panel)
    end
    if state.navTool == "overview" or not state.navTool then
        state.navTool = "overview"
        state.guardMode = "overview"
        return IKST_SoftTool_Claim.buildClaimOverview(panel)
    end
    local tool = state.navTool
    if tool == "safehouses" then
        state.guardMode = "safehouses"
        return IKST_SoftTool_Claim.buildSafehouses(panel, 8)
    elseif tool == "vehicleclaim" then
        state.guardMode = "vehicles"
        return IKST_SoftTool_Claim.buildVehicles(panel, 8)
    elseif tool == "catch" then
        state.guardMode = "tools"
        return IKST_SoftTool_Claim.buildTools(panel, 8)
    end
    state.navTool = "overview"
    state.guardMode = "overview"
    return IKST_SoftTool_Claim.buildClaimOverview(panel)
end
