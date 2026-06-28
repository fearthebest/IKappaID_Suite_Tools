if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Claim"
require "IKST_PreviewOverlay"
require "IKST_JobGuard"
require "IKST_JobsPanel"

IKST_Preview = IKST_Preview or {}

local function playerCoords(player)
    return math.floor(player:getX()), math.floor(player:getY()), player:getZ()
end

function IKST_Preview.syncForPanel(panel)
    if not panel or not panel.player or not IKST_PreviewOverlay then
        if IKST_PreviewOverlay and IKST_PreviewOverlay.clearJob then
            IKST_PreviewOverlay.clearJob()
        end
        return
    end

    local player = panel.player
    local state = IKST.getPlayerState(player)
    local view = IKST_HubNav and IKST_HubNav.effectiveView(panel, state) or panel.view
    local cx, cy, cz = playerCoords(player)

    if view == IKST.VIEW.cleanup then
        IKST_PreviewOverlay.clearJob()
        if IKST_PreviewOverlay.clearBatch then
            IKST_PreviewOverlay.clearBatch()
        end
        return
    end

    if IKST_PreviewOverlay.clearBatch then
        IKST_PreviewOverlay.clearBatch()
    end

    if view == IKST.VIEW.threat then
        IKST_PreviewOverlay.setJobRadius(cx, cy, cz, panel.threatRadius or IKST.RADIUS_PRESETS.M, "warn")
        return
    end

    if view == IKST.VIEW.automation and state then
        IKST_PreviewOverlay.setJobRadius(cx, cy, cz, state.autoRadius or IKST.RADIUS_PRESETS.M, "protect")
        return
    end

    if view == IKST.VIEW.vehicle then
        local vid = panel.selectedVehicleId
        if not vid and IKST_JobVehicle and IKST_JobVehicle.listCache and IKST_JobVehicle.listCache[1] then
            vid = IKST_JobVehicle.listCache[1].id
        end
        if vid then
            IKST_PreviewOverlay.setJobVehicle(vid, "claim")
        else
            IKST_PreviewOverlay.clearJob()
        end
        return
    end

    if view == IKST.VIEW.inspector and state and state.lastInspect then
        local li = state.lastInspect
        local sq = IKST_Grid.getSquare(li.x, li.y, li.z or 0)
        if sq then
            IKST_PreviewOverlay.setJobSquare(sq, "accent")
        else
            IKST_PreviewOverlay.clearJob()
        end
        return
    end

    if view == IKST.VIEW.guard and state then
        local mode = state.guardMode or "tools"
        if mode == "safehouses" then
            local size = state.guardShSize or 13
            local claimMode = state.guardShClaimMode or IKST_Claim.MODE.square
            local shW, shH = state.guardShW or size, state.guardShH or size
            if IKST_JobGuard and IKST_JobGuard.readShDimensions and panel.guardShWEntry then
                shW, shH = IKST_JobGuard.readShDimensions(panel, state)
            end
            local rects = {}
            local px, py, pw, ph, pz, _, previewKind = IKST_Claim.safehousePreviewRect(cx, cy, cz, size, claimMode, shW, shH)
            rects[#rects + 1] = {
                x = px, y = py, w = pw, h = ph, z = pz,
                color = previewKind == IKST_Claim.MODE.building and "accent" or "claim",
            }
            if panel.guardSelectedSH then
                local sel = panel.guardSelectedSH
                rects[#rects + 1] = {
                    x = sel.x, y = sel.y,
                    w = sel.w and sel.w > 0 and sel.w or 1,
                    h = sel.h and sel.h > 0 and sel.h or 1,
                    z = sel.z or 0,
                    color = "warn",
                }
            end
            IKST_PreviewOverlay.setJobRects(rects)
            return
        end
        if mode == "tiles" or mode == "farming" then
            IKST_PreviewOverlay.setJobRadius(cx, cy, cz, state.guardRadius or IKST.RADIUS_PRESETS.M, "protect")
            return
        end
        if mode == "blueprints" then
            local half = 5
            IKST_PreviewOverlay.setJobRectBorder(cx - half, cy - half, 11, 11, cz, "accent")
            return
        end
        if mode == "containers" then
            local sq = IKST_Grid.getSquare(cx, cy, cz)
            if sq then
                IKST_PreviewOverlay.setJobSquare(sq, "protect")
            else
                IKST_PreviewOverlay.clearJob()
            end
            return
        end
        if mode == "vehicles" then
            local vid = IKST_JobGuard and IKST_JobGuard.resolveVehicleId and IKST_JobGuard.resolveVehicleId(panel)
            if vid then
                IKST_PreviewOverlay.setJobVehicle(vid, "claim")
            else
                IKST_PreviewOverlay.clearJob()
            end
            return
        end
    end

    IKST_PreviewOverlay.clearJob()
end

local _previewMoveKey = ""

local function previewMoveKey(panel)
    if not panel or not panel.player then
        return ""
    end
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local parts = {
        panel.view or "",
        math.floor(p:getX()),
        math.floor(p:getY()),
        p:getZ(),
    }
    if state then
        parts[#parts + 1] = state.guardMode or ""
        parts[#parts + 1] = state.guardShSize or ""
        parts[#parts + 1] = state.guardShW or ""
        parts[#parts + 1] = state.guardShH or ""
        parts[#parts + 1] = state.guardShClaimMode or ""
        parts[#parts + 1] = state.guardRadius or ""
        parts[#parts + 1] = state.autoRadius or ""
    end
    parts[#parts + 1] = panel.threatRadius or ""
    parts[#parts + 1] = tostring(panel.guardVehicleId or panel.selectedVehicleId or "")
    parts[#parts + 1] = tostring(panel.guardSelectedSH and panel.guardSelectedSH.id or "")
    if panel.guardShWEntry and IKST_JobGuard and IKST_JobGuard.readEntry then
        parts[#parts + 1] = IKST_JobGuard.readEntry(panel.guardShWEntry)
        parts[#parts + 1] = IKST_JobGuard.readEntry(panel.guardShHEntry)
    end
    return table.concat(parts, "|")
end

local function onPreviewTick()
    local panel = IKST_JobsPanel and IKST_JobsPanel.instance
    if not panel or not panel.getIsVisible or not panel:getIsVisible() then
        _previewMoveKey = ""
        return
    end
    if IKST_HubNav and IKST_HubNav.isFavoritesView(panel.view) then
        return
    end
    local key = previewMoveKey(panel)
    if key ~= _previewMoveKey then
        _previewMoveKey = key
        IKST_Preview.syncForPanel(panel)
    end
end

if Events and Events.OnTick then
    Events.OnTick.Add(onPreviewTick)
end
