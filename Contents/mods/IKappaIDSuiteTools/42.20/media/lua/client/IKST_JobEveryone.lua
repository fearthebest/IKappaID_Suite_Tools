if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
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

local function claimRows(panel, state)
    local claims = IKST_JobGuard and IKST_JobGuard.claims or {}
    local shList = IKST_JobGuard and IKST_JobGuard.safehouses or {}
    local rows = {}
    for i = 1, #claims do
        local claim = claims[i]
        if state and state.everyoneOnlineOnly == true
            and IKST_Dashboard and type(IKST_Dashboard.isClaimOwnerOnline) == "function"
            and not IKST_Dashboard.isClaimOwnerOnline(claim.owner, claim.ownerLabel) then
            -- skip offline
        else
            rows[#rows + 1] = {
                id = "v:" .. tostring(claim.id or i),
                label = tostring(claim.displayLabel or claim.script or ("#" .. tostring(claim.id))),
                kind = "vehicle",
                claim = claim,
            }
        end
    end
    for i = 1, #shList do
        local sh = shList[i]
        if state and state.everyoneOnlineOnly == true
            and IKST_Dashboard and type(IKST_Dashboard.isClaimOwnerOnline) == "function"
            and not IKST_Dashboard.isClaimOwnerOnline(sh.owner, sh.ownerLabel) then
            -- skip
        else
            local title = (sh.title and sh.title ~= "") and tostring(sh.title) or tostring(sh.owner or "?")
            rows[#rows + 1] = {
                id = "s:" .. tostring(sh.owner or i) .. ":" .. tostring(sh.x or 0),
                label = title .. "  (" .. tostring(sh.x or "?") .. ", " .. tostring(sh.y or "?") .. ")",
                kind = "safehouse",
                sh = sh,
            }
        end
    end
    return rows
end

function IKST_JobEveryone.build(panel)
    local p = panel.player
    if not p then
        return 8
    end

    local state = IKST.getPlayerState(p)
    if state and state.everyoneOnlineOnly == nil then
        state.everyoneOnlineOnly = false
    end

    if not panel._everyoneClaimsRequested then
        panel._everyoneClaimsRequested = true
        if IKST_JobGuard and type(IKST_JobGuard.requestClaims) == "function" then
            IKST_JobGuard.requestClaims(p)
        end
        if IKST_JobGuard and type(IKST_JobGuard.requestSafehouses) == "function" then
            IKST_JobGuard.requestSafehouses(p)
        end
    end
    if not panel._everyoneDashRequested then
        panel._everyoneDashRequested = true
        if IKST_Dashboard and type(IKST_Dashboard.request) == "function" then
            IKST_Dashboard.request(p)
        end
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 5, gap)
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_EveryoneTile_SectionServer", "Server info"))
        local dayNum = "-"
        if type(getGameTime) == "function" then
            local gt = getGameTime()
            if gt and type(gt.getDay) == "function" then
                dayNum = tostring(gt:getDay() + 1)
            end
        end
        local snap = IKST_Dashboard and IKST_Dashboard.snapshot
        local onlineVal = snap and tostring(snap.online or 0) or "-"
        local maxVal = snap and tostring(snap.maxPlayers or 0) or "-"
        local claimN = #(IKST_JobGuard and IKST_JobGuard.claims or {})
        local shN = #(IKST_JobGuard and IKST_JobGuard.safehouses or {})
        local note = IKST.text("IGUI_IKST_EveryoneTile_Online", "Online") .. " " .. onlineVal
            .. " / " .. maxVal
            .. "  -  " .. IKST.text("IGUI_IKST_EveryoneTile_Day", "Day") .. " " .. dayNum
            .. "  -  " .. IKST.text("IGUI_IKST_EveryoneTile_SectionClaims", "Claims") .. " " .. tostring(claimN + shN)
        local line = ISLabel:new(ax, ay, 16, note, 1, 1, 1, 1, UIFont.Small, true)
        line:initialise()
        card:addChild(line)
        if IKST_ClaimPolicy and type(IKST_ClaimPolicy.limitsSummary) == "function" then
            local lim = ISLabel:new(ax, ay + 18, 16, IKST_ClaimPolicy.limitsSummary(), 1, 1, 1, 1, UIFont.Small, true)
            lim:initialise()
            card:addChild(lim)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_EveryoneTile_SectionClaims", "Claims directory"))
        local rows = claimRows(panel, state)
        if #rows == 0 then
            local emptyMsg = IKST.text("IGUI_IKST_Everyone_NoClaims", "No vehicle claims loaded - press Refresh.")
            if state and state.everyoneOnlineOnly == true then
                emptyMsg = IKST.text("IGUI_IKST_Everyone_NoOnlineClaims", "No claims with online owners.")
            end
            local empty = ISLabel:new(ax, ay, 16, emptyMsg, 1, 1, 1, 1, UIFont.Small, true)
            empty:initialise()
            card:addChild(empty)
        else
            local visible = math.max(4, math.floor(ah / math.max(18, IKST_JobLayout.listItemHeight())))
            IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, IKST_JobLayout.selectListHeight(visible), rows, {
                onSelect = function(row)
                    if not panel.enterNav then
                        return
                    end
                    if row.kind == "safehouse" then
                        panel.guardSelectedSH = row.sh
                        panel:enterNav(IKST.VIEW.claim, "safehouses")
                    else
                        panel:enterNav(IKST.VIEW.claim, "vehicleclaim")
                    end
                end,
            })
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_EveryoneTile_SectionEvents", "Events"))
        local wpItems = {
            {
                label = IKST.text("IGUI_IKST_EventJoin", "Join event"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.eventJoin, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EventReturn", "Return"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.eventReturn, {})
                end,
            },
        }
        if IKST_Unstuck and type(IKST_Unstuck.enabled) == "function" and IKST_Unstuck.enabled() then
            wpItems[#wpItems + 1] = {
                label = IKST.text("IGUI_IKST_Unstuck", "Unstuck"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.unstuck, {})
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, wpItems)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_EveryoneTile_SectionQuick", "Quick actions"))
        local quick = {
            {
                label = IKST.text("IGUI_IKST_EveryoneTile_RequestHelp", "Request help"),
                onClick = function()
                    local msg = panel.helpMessageDraft or ""
                    if panel.helpMsgEntry and type(panel.helpMsgEntry.getText) == "function" then
                        msg = string.gsub(panel.helpMsgEntry:getText() or "", "^%s*(.-)%s*$", "%1")
                        panel.helpMessageDraft = msg
                    end
                    IKST.dispatchCommand(p, IKST.CMD.helpRequest, { message = msg })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EveryoneTile_Report", "Report"),
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
            {
                label = IKST.text("IGUI_IKST_SeeTickets", "Tickets"),
                onClick = function()
                    if IKST_Access and type(IKST_Access.canUseStaffTools) == "function"
                        and IKST_Access.canUseStaffTools(p)
                        and IKST_TicketsUI and type(IKST_TicketsUI.openInbox) == "function" then
                        IKST_TicketsUI.openInbox(p)
                    else
                        IKST.notify(p, IKST.text("IGUI_IKST_EveryoneTile_TicketsHint", "Staff tickets inbox."), true)
                    end
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EveryoneTile_Rules", "Rules"),
                onClick = function()
                    IKST.notify(p, IKST.text("IGUI_IKST_Everyone_RulesInvite",
                        "Please read the server briefing. House rules are in the Server rules section."), true)
                    if IKST_BriefingUI and type(IKST_BriefingUI.open) == "function" then
                        IKST_BriefingUI.open(p, "rules")
                    end
                end,
            },
        }
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, quick)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[5], IKST.text("IGUI_IKST_HelpRequest", "Help message"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = panel.helpMessageDraft or "", fieldName = "helpMsgEntry" },
        }, IKST.text("IGUI_IKST_HelpSend", "Send"), function()
            local msg = ""
            if panel.helpMsgEntry and type(panel.helpMsgEntry.getText) == "function" then
                msg = string.gsub(panel.helpMsgEntry:getText() or "", "^%s*(.-)%s*$", "%1")
            end
            panel.helpMessageDraft = msg
            IKST.dispatchCommand(p, IKST.CMD.helpRequest, { message = msg })
        end)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end
