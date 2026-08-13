if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_VehicleClaim"
require "IKST_ClaimPolicy"
require "IKST_Briefing"
require "IKST_BriefingUI"
require "IKST_Arrival"
require "IKST_Unstuck"
require "IKST_Dashboard"
require "IKST_Access"

IKST_JobEveryone = IKST_JobEveryone or {}

-- Everyone landing (mockup: ikst-page-everyone.png). Display + existing
-- handlers only; placeholders in docs/UI-PLACEHOLDERS.md.

local function everyoneBtn(parent, panel, x, y, w, h, label, kind, onClick)
    local btn = IKST_Chrome.newActionButton(x, y, w, h, label, panel, function()
        if onClick then
            onClick()
        end
    end, kind or "chip")
    parent:addChild(btn)
    return btn
end

local function flowLayout(items, cardW, gap)
    local padX = IKST_UI_Layout.s(14)
    local usableW = math.max(40, cardW - (padX * 2))
    local rows = {}
    local curRow = {}
    local curX = 0
    for _, item in ipairs(items) do
        local w = IKST_UI_Layout.buttonWidth(item.label, UIFont.Small, 96)
        if curX > 0 and curX + gap + w > usableW then
            rows[#rows + 1] = curRow
            curRow = {}
            curX = 0
        end
        if curX > 0 then
            curX = curX + gap
        end
        curRow[#curRow + 1] = { item = item, x = padX + curX, w = w }
        curX = curX + w
    end
    if #curRow > 0 then
        rows[#rows + 1] = curRow
    end
    return rows
end

local function buildPillSection(panel, x, y, w, icon, titleKey, titleFallback, items)
    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local rows = flowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    if #rows == 0 then
        contentH = rowH
    end
    local cardH = headerH + contentH + bottomPad
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, IKST.text(titleKey, titleFallback))
    panel:addJobWidget(card)
    local cy = contentY
    for _, row in ipairs(rows) do
        for _, cell in ipairs(row) do
            local item = cell.item
            local kind = "chip"
            if item.primary then
                kind = "primary"
            elseif item.outline then
                kind = "outline"
            elseif item.on then
                kind = "primary"
            end
            everyoneBtn(card, panel, cell.x, cy, cell.w, rowH, item.label, kind, function()
                if item.onClick then
                    item.onClick()
                end
                panel:refreshJobUI()
            end)
        end
        cy = cy + rowH + gap
    end
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

function IKST_JobEveryone.build(panel)
    local p = panel.player
    if not p then
        return 8
    end

    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local padX = IKST_UI_Layout.s(14)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local cc = IKST_Chrome.colors
    local px = math.floor(p:getX())
    local py = math.floor(p:getY())
    local pz = p:getZ()
    local state = IKST.getPlayerState(p)

    if not panel._everyoneClaimsRequested then
        panel._everyoneClaimsRequested = true
        if IKST_JobGuard and IKST_JobGuard.requestClaims then
            IKST_JobGuard.requestClaims(p)
        end
        if IKST_JobGuard and IKST_JobGuard.requestSafehouses then
            IKST_JobGuard.requestSafehouses(p)
        end
    end
    if not panel._everyoneDashRequested then
        panel._everyoneDashRequested = true
        if IKST_Dashboard and IKST_Dashboard.request then
            IKST_Dashboard.request(p)
        end
    end
    if state and state.everyoneOnlineOnly == nil then
        state.everyoneOnlineOnly = false
    end

    local title = IKST.text("IGUI_IKST_WS_Everyone", "Everyone")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local refreshLabel = IKST.text("IGUI_IKST_Dashboard_Refresh", "Refresh")
    local refreshW = IKST_UI_Layout.buttonWidth(refreshLabel, UIFont.Small, 80)
    local onlineLabel = IKST.text("IGUI_IKST_EveryoneTile_OnlineOnly", "Show only online")
    local onlineW = IKST_UI_Layout.buttonWidth(onlineLabel, UIFont.Small, 120)
    local rightEdge = x + w
    local refreshX = rightEdge - refreshW
    local onlineX = refreshX - IKST_UI_Layout.s(8) - onlineW

    local onlineBtn = IKST_Chrome.newActionButton(onlineX, y, onlineW, headerBtnH, onlineLabel, panel, function()
        if state then
            state.everyoneOnlineOnly = not (state.everyoneOnlineOnly == true)
        end
        panel:refreshJobUI()
    end, state and state.everyoneOnlineOnly == true and "primary" or "chip")
    panel:addJobWidget(onlineBtn)

    local refreshBtn = IKST_Chrome.newActionButton(refreshX, y, refreshW, headerBtnH, refreshLabel, panel, function()
        if IKST_JobGuard and IKST_JobGuard.requestClaims then
            IKST_JobGuard.requestClaims(p)
        end
        if IKST_JobGuard and IKST_JobGuard.requestSafehouses then
            IKST_JobGuard.requestSafehouses(p)
        end
        if IKST_Dashboard and IKST_Dashboard.request then
            IKST_Dashboard.request(p)
        end
        panel:refreshJobUI()
    end, "outline")
    panel:addJobWidget(refreshBtn)

    y = y + math.max(26, headerBtnH) + gap

    -- SERVER INFO (display-only)
    local dayNum = "—"
    if type(getGameTime) == "function" then
        local gt = getGameTime()
        if gt and type(gt.getDay) == "function" then
            dayNum = tostring(gt:getDay() + 1)
        end
    end
    local infoH = IKST_Chrome.sectionHeaderH() + IKST_UI_Layout.s(56) + IKST_UI_Layout.s(14)
    local infoCard, infoY = IKST_Chrome.newSectionCardPanel(x, y, w, infoH,
        "media/ui/ikst/tool_servertools.png",
        IKST.text("IGUI_IKST_EveryoneTile_SectionServer", "Server info"))
    panel:addJobWidget(infoCard)
    local cardGap = IKST_UI_Layout.s(8)
    local cardW = math.floor((w - (padX * 2) - (cardGap * 2)) / 3)
    local cardH = math.max(40, IKST_UI_Layout.s(44))
    local snap = IKST_Dashboard and IKST_Dashboard.snapshot
    local onlineVal = snap and tostring(snap.online or 0) or "—"
    local maxVal = snap and tostring(snap.maxPlayers or 0) or "—"
    local stats = {
        { title = IKST.text("IGUI_IKST_EveryoneTile_Online", "Online"), value = onlineVal },
        { title = IKST.text("IGUI_IKST_EveryoneTile_MaxSlots", "Max slots"), value = maxVal },
        { title = IKST.text("IGUI_IKST_EveryoneTile_Day", "Day"), value = dayNum },
    }
    for i, s in ipairs(stats) do
        local cx = padX + (i - 1) * (cardW + cardGap)
        local box = ISPanel:new(cx, infoY, cardW, cardH)
        box:initialise()
        box.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        box.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        box._title = s.title
        box._value = s.value
        box.render = function(bp)
            IKST_Chrome.drawRoundedCard(bp, 0, 0, bp.width, bp.height, { shadow = false, fill = cc.bgToolbar })
            local _, th = IKST_UI_Layout.textSize(bp._title, UIFont.Small)
            bp:drawText(bp._title, 8, 6, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
            bp:drawText(bp._value, 8, 6 + th + 2, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Medium)
        end
        infoCard:addChild(box)
    end
    y = y + infoH + gap

    -- CLAIMS DIRECTORY
    local claims = IKST_JobGuard and IKST_JobGuard.claims or {}
    local shList = IKST_JobGuard and IKST_JobGuard.safehouses or {}
    local rows = {}
    for i, claim in ipairs(claims) do
        if i > 6 then
            break
        end
        if state and state.everyoneOnlineOnly == true
            and IKST_Dashboard and IKST_Dashboard.isClaimOwnerOnline
            and not IKST_Dashboard.isClaimOwnerOnline(claim.owner, claim.ownerLabel) then
            -- skip offline owners when filter on
        else
        rows[#rows + 1] = {
            kind = "vehicle",
            title = tostring(claim.displayLabel or claim.script or ("#" .. tostring(claim.id))),
            sub = (claim.x and claim.y) and (tostring(claim.x) .. ", " .. tostring(claim.y)) or "",
            claim = claim,
        }
        end
    end
    for i, sh in ipairs(shList) do
        if #rows >= 8 then
            break
        end
        if state and state.everyoneOnlineOnly == true
            and IKST_Dashboard and IKST_Dashboard.isClaimOwnerOnline
            and not IKST_Dashboard.isClaimOwnerOnline(sh.owner, sh.ownerLabel) then
            -- skip
        else
        local title = (sh.title and sh.title ~= "") and tostring(sh.title) or tostring(sh.owner or "?")
        rows[#rows + 1] = {
            kind = "safehouse",
            title = title,
            sub = tostring(sh.x or "?") .. ", " .. tostring(sh.y or "?"),
            sh = sh,
        }
        end
    end
    local listRows = math.max(1, #rows)
    local rowH = math.max(40, IKST_UI_Layout.s(44))
    local listCardH = IKST_Chrome.sectionHeaderH() + (listRows * (rowH + IKST_UI_Layout.s(6))) - IKST_UI_Layout.s(6) + IKST_UI_Layout.s(14)
    local listCard, listY = IKST_Chrome.newSectionCardPanel(x, y, w, listCardH,
        "media/ui/ikst/ws_claim.png",
        IKST.text("IGUI_IKST_EveryoneTile_SectionClaims", "Claims directory"))
    panel:addJobWidget(listCard)
    if #rows == 0 then
        local emptyMsg = IKST.text("IGUI_IKST_Everyone_NoClaims", "No vehicle claims loaded — press Refresh.")
        if state and state.everyoneOnlineOnly == true and (#claims > 0 or #shList > 0) then
            emptyMsg = IKST.text("IGUI_IKST_Everyone_NoOnlineClaims", "No claims with online owners.")
        end
        local empty = ISLabel:new(padX, listY + 8, 16, emptyMsg,
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        empty:initialise()
        listCard:addChild(empty)
    else
        local ry = listY
        local viewLabel = IKST.text("IGUI_IKST_EveryoneTile_View", "View")
        local viewW = IKST_UI_Layout.buttonWidth(viewLabel, UIFont.Small, 56)
        local btnH = math.max(24, IKST_UI_Layout.s(28))
        for _, row in ipairs(rows) do
            local nameLbl = ISLabel:new(padX, ry + 4, 16, row.title,
                cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small, true)
            nameLbl:initialise()
            listCard:addChild(nameLbl)
            local subLbl = ISLabel:new(padX, ry + 20, 14, row.sub,
                cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
            subLbl:initialise()
            listCard:addChild(subLbl)
            everyoneBtn(listCard, panel, w - padX - viewW, ry + math.floor((rowH - btnH) / 2),
                viewW, btnH, viewLabel, "chip", function()
                    if panel.enterNav then
                        if row.kind == "safehouse" then
                            panel.guardSelectedSH = row.sh
                            panel:enterNav(IKST.VIEW.claim, "safehouses")
                        else
                            panel:enterNav(IKST.VIEW.claim, "vehicleclaim")
                        end
                    end
                end)
            ry = ry + rowH + IKST_UI_Layout.s(6)
        end
    end
    y = y + listCardH + gap

    -- WAYPOINTS / events (existing player self-service)
    local wpItems = {
        {
            label = IKST.text("IGUI_IKST_EventJoin", "Join event"),
            primary = true,
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.eventJoin, {})
            end,
        },
        {
            label = IKST.text("IGUI_IKST_EventReturn", "Return from event"),
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.eventReturn, {})
            end,
        },
    }
    if IKST_Unstuck and IKST_Unstuck.enabled and IKST_Unstuck.enabled() then
        wpItems[#wpItems + 1] = {
            label = IKST.text("IGUI_IKST_Unstuck", "Unstuck"),
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.unstuck, {})
            end,
        }
    end
    y = buildPillSection(panel, x, y, w, "media/ui/ikst/tool_teleport.png",
        "IGUI_IKST_EveryoneTile_SectionWaypoints", "Waypoints", wpItems)

    -- QUICK ACTIONS
    local quick = {
        {
            label = IKST.text("IGUI_IKST_EveryoneTile_RequestHelp", "Request help"),
            primary = true,
            onClick = function()
                local msg = panel.helpMessageDraft or ""
                IKST.dispatchCommand(p, IKST.CMD.helpRequest, { message = msg })
            end,
        },
        {
            label = IKST.text("IGUI_IKST_EveryoneTile_Report", "Report player"),
            onClick = function()
                local msg = panel.helpMessageDraft or ""
                if panel.helpMsgEntry and type(panel.helpMsgEntry.getText) == "function" then
                    msg = string.gsub(panel.helpMsgEntry:getText() or "", "^%s*(.-)%s*$", "%1")
                    panel.helpMessageDraft = msg
                end
                if msg == "" then
                    IKST.notify(p, IKST.text("IGUI_IKST_Everyone_ReportNeedMsg",
                        "Type who and why in the box, then Report player."), false)
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.reportPlayer, { message = msg })
            end,
        },
    }
    if IKST_Access and type(IKST_Access.canUseStaffTools) == "function" and IKST_Access.canUseStaffTools(p) then
        quick[#quick + 1] = {
            label = IKST.text("IGUI_IKST_SeeTickets", "See tickets"),
            outline = true,
            onClick = function()
                if IKST_TicketsUI and type(IKST_TicketsUI.openInbox) == "function" then
                    IKST_TicketsUI.openInbox(p)
                end
            end,
        }
    end
    quick[#quick + 1] = {
        label = IKST.text("IGUI_IKST_EveryoneTile_Rules", "Server rules"),
        outline = true,
        onClick = function()
            IKST.notify(p, IKST.text("IGUI_IKST_Everyone_RulesInvite",
                "Please read the server briefing. House rules are in the Server rules section."), true)
            if IKST_BriefingUI and IKST_BriefingUI.open then
                IKST_BriefingUI.open(p, "rules")
            end
        end,
    }
    y = buildPillSection(panel, x, y, w, "media/ui/ikst/tool_self.png",
        "IGUI_IKST_EveryoneTile_SectionQuick", "Quick actions", quick)

    -- Help message entry (same handler as before)
    panel:makeJobLabel(x, y, IKST.text("IGUI_IKST_HelpRequest", "Ask staff for help"), UIFont.Small)
    y = y + 16
    local entryW = math.max(120, w - 110)
    panel.helpMsgEntry = ISTextEntryBox:new(panel.helpMessageDraft or "", x, y, entryW, 22)
    panel.helpMsgEntry:initialise()
    panel.helpMsgEntry:instantiate()
    panel:addJobWidget(panel.helpMsgEntry)
    panel:makeJobButton(x + entryW + 8, y, 100, 22, IKST.text("IGUI_IKST_HelpSend", "Send"), function()
        local msg = ""
        if panel.helpMsgEntry and type(panel.helpMsgEntry.getText) == "function" then
            msg = string.gsub(panel.helpMsgEntry:getText() or "", "^%s*(.-)%s*$", "%1")
        end
        panel.helpMessageDraft = msg
        IKST.dispatchCommand(p, IKST.CMD.helpRequest, { message = msg })
    end, false)
    y = y + 30

    if IKST_ClaimPolicy and IKST_ClaimPolicy.limitsSummary then
        panel:makeJobLabel(x, y, IKST_ClaimPolicy.limitsSummary(), UIFont.Small)
        y = y + 20
    end
    panel:makeJobLabel(x, y, string.format("%d, %d, %d", px, py, pz), UIFont.Small)
    y = y + 18

    return y
end
