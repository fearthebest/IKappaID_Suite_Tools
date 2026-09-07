-- SoftTool Everyone: soft-shell Everyone workspace painted via IKUI_SoftBody.
-- Dispatch stays on IKST.dispatchCommand / JobGuard request helpers.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "IKST_Shared"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_ClaimPolicy"
require "IKST_Briefing"
require "IKST_Unstuck"
require "IKST_Dashboard"
require "IKST_Access"
require "IKappaID_UI_Framework/IKUI_SoftBody"

IKST_SoftTool_Everyone = IKST_SoftTool_Everyone or {}

local function claimRows(panel, state)
    local claims = IKST_JobGuard and IKST_JobGuard.claims or {}
    local shList = (IKST_JobGuard and type(IKST_JobGuard.getSafehouses) == "function"
        and IKST_JobGuard.getSafehouses()) or {}
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

local function ensureData(panel, p)
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
end

local function openFullCard(panel, title)
    local rect = IKUI_SoftBody.contentRect(panel)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, rect.x, rect.y, rect.w, rect.h, title)
    local areaX = inner
    local areaW = math.max(40, rect.w - inner * 2)
    local areaY = contentY + padY
    local areaH = math.max(btnH, rect.h - contentY - padY * 2)
    return card, areaX, areaY, areaW, areaH, rect
end

function IKST_SoftTool_Everyone.buildOverview(panel)
    local card, ax, ay, aw, ah, rect = openFullCard(panel, IKST.text("IGUI_IKST_EveryoneTile_SectionServer", "Server info"))
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
    local shListCount = (IKST_JobGuard and type(IKST_JobGuard.getSafehouses) == "function"
        and IKST_JobGuard.getSafehouses()) or {}
    local shN = #shListCount
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
    return rect.y + rect.h
end

function IKST_SoftTool_Everyone.buildClaims(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local card, ax, ay, aw, ah, rect = openFullCard(panel, IKST.text("IGUI_IKST_EveryoneTile_SectionClaims", "Claims directory"))
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
    return rect.y + rect.h
end

function IKST_SoftTool_Everyone.buildEvents(panel)
    local p = panel.player
    local card, ax, ay, aw, ah, rect = openFullCard(panel, IKST.text("IGUI_IKST_EveryoneTile_SectionEvents", "Events"))
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
    IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, wpItems)
    return rect.y + rect.h
end

function IKST_SoftTool_Everyone.buildHelp(panel)
    local p = panel.player
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 2, 1 })
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_EveryoneTile_SectionQuick", "Quick actions"))
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
                    if IKST_TicketsUI and type(IKST_TicketsUI.openInbox) == "function" then
                        IKST_TicketsUI.openInbox(p)
                    else
                        IKST.notify(p, IKST.text("IGUI_IKST_EveryoneTile_TicketsHint", "Staff tickets inbox."), true)
                    end
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EveryoneTile_Rules", "Rules"),
                onClick = function()
                    panel.helpShowRules = true
                    if panel.enterNav then
                        panel:enterNav(IKST.VIEW.everyone, "help")
                    else
                        local body = ""
                        if IKST_Briefing and IKST_Briefing.DEFAULT_SECTIONS then
                            for _, sec in ipairs(IKST_Briefing.DEFAULT_SECTIONS) do
                                if sec.id == "rules" then
                                    body = sec.body or ""
                                    break
                                end
                            end
                        end
                        IKST.notify(p, body ~= "" and body or IKST.text("IGUI_IKST_Everyone_RulesInvite",
                            "Please read the server briefing. House rules are in the Server rules section."), true)
                    end
                end,
            },
        }
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, quick)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_HelpRequest", "Help message"))
        if panel.helpShowRules then
            local body = IKST.text("IGUI_IKST_Everyone_RulesInvite",
                "Please read the server briefing. House rules are in the Server rules section.")
            local cache = IKST_BriefingUI and IKST_BriefingUI._cache
            local sections = (cache and cache.sections) or (IKST_Briefing and IKST_Briefing.DEFAULT_SECTIONS)
            if sections then
                for _, sec in ipairs(sections) do
                    if sec.id == "rules" and sec.body then
                        body = sec.body
                        break
                    end
                end
            end
            local lab = ISLabel:new(ax, ay, 16, body, 1, 1, 1, 1, UIFont.Small, true)
            lab:initialise()
            card:addChild(lab)
            panel.helpShowRules = false
        else
            IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
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
    end

    return stackBottom + gap
end

function IKST_SoftTool_Everyone.build(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local state = IKST.getPlayerState(p)
    if state and state.everyoneOnlineOnly == nil then
        state.everyoneOnlineOnly = false
    end
    ensureData(panel, p)
    local tool = (state and state.navTool) or "overview"
    if tool == "claims" then
        return IKST_SoftTool_Everyone.buildClaims(panel)
    end
    if tool == "events" then
        return IKST_SoftTool_Everyone.buildEvents(panel)
    end
    if tool == "help" then
        return IKST_SoftTool_Everyone.buildHelp(panel)
    end
    return IKST_SoftTool_Everyone.buildOverview(panel)
end
