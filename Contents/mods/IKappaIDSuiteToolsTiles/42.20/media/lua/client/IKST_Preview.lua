if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Claim"
require "IKST_PreviewOverlay"
require "IKST_JobGuard"

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

    if view == IKST.VIEW.cleanup and state then
        local ax, ay, az = cx, cy, cz
        if state.armed and (state.armedJob == IKST.VIEW.cleanup or state.armedJob == IKST.VIEW.inspector)
            and IKST_WorldPick and IKST_WorldPick.hoverSquare then
            local hs = IKST_WorldPick.hoverSquare
            if type(hs.getX) == "function" and type(hs.getY) == "function" then
                ax = hs:getX()
                ay = hs:getY()
                if type(hs.getZ) == "function" then
                    az = hs:getZ()
                end
            end
        end
        if state.armed and state.armedJob == IKST.VIEW.cleanup and IKST_PreviewOverlay.setCleanupPreview then
            local sq = IKST_Grid.getSquare(ax, ay, az)
            if sq then
                IKST_PreviewOverlay.setCleanupPreview(sq, state, IKST_WorldPick and IKST_WorldPick.batchScope)
            else
                IKST_PreviewOverlay.clearJob()
            end
        else
            IKST_PreviewOverlay.clearJob()
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

    if view == IKST.VIEW.loot and state and IKST_LootOps and IKST_LootOps.previewZone then
        local ax, ay, az = cx, cy, cz
        local hoverSq = nil
        if state.armed and state.armedJob == IKST.VIEW.loot
            and IKST_WorldPick and IKST_WorldPick.hoverSquare then
            hoverSq = IKST_WorldPick.hoverSquare
            if type(hoverSq.getX) == "function" and type(hoverSq.getY) == "function" then
                ax = hoverSq:getX()
                ay = hoverSq:getY()
                if type(hoverSq.getZ) == "function" then
                    az = hoverSq:getZ()
                end
            end
        end
        local preview = IKST_LootOps.previewZone(ax, ay, az, IKST.getLootScope(state), {
            radius = state.cleanupRadius,
        })
        if IKST_PreviewOverlay.setLootJobPreview then
            IKST_PreviewOverlay.setLootJobPreview(preview, hoverSq)
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
local _previewMoveParts = {}

local function previewMoveKey(panel)
    if not panel or not panel.player then
        return ""
    end
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local parts = _previewMoveParts
    local n = 0
    n = n + 1
    parts[n] = panel.view or ""
    n = n + 1
    parts[n] = math.floor(p:getX())
    n = n + 1
    parts[n] = math.floor(p:getY())
    n = n + 1
    parts[n] = math.floor(p:getZ() or 0)
    if state then
        n = n + 1
        parts[n] = state.guardMode or ""
        n = n + 1
        parts[n] = state.guardShSize or ""
        n = n + 1
        parts[n] = state.guardShW or ""
        n = n + 1
        parts[n] = state.guardShH or ""
        n = n + 1
        parts[n] = state.guardShClaimMode or ""
        n = n + 1
        parts[n] = state.guardRadius or ""
        n = n + 1
        parts[n] = state.autoRadius or ""
    end
    n = n + 1
    parts[n] = panel.threatRadius or ""
    n = n + 1
    parts[n] = tostring(panel.guardVehicleId or panel.selectedVehicleId or "")
    n = n + 1
    parts[n] = tostring(panel.guardSelectedSH and panel.guardSelectedSH.id or "")
    if state then
        n = n + 1
        parts[n] = state.lootScope or ""
        n = n + 1
        parts[n] = state.cleanupRadius or ""
        n = n + 1
        parts[n] = tostring(state.armed and state.armedJob == IKST.VIEW.loot)
        if IKST_WorldPick and IKST_WorldPick.hoverSquare then
            local hs = IKST_WorldPick.hoverSquare
            if type(hs.getX) == "function" and type(hs.getY) == "function" then
                n = n + 1
                parts[n] = tostring(math.floor(hs:getX() or 0)) .. "," .. tostring(math.floor(hs:getY() or 0))
            end
        end
    end
    if panel.guardShWEntry and IKST_JobGuard and IKST_JobGuard.readEntry then
        n = n + 1
        parts[n] = IKST_JobGuard.readEntry(panel.guardShWEntry)
        n = n + 1
        parts[n] = IKST_JobGuard.readEntry(panel.guardShHEntry)
    end
    for i = n + 1, #parts do
        parts[i] = nil
    end
    return table.concat(parts, "|", 1, n)
end

local function onPreviewTick()
    local panel = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
    if not panel or type(panel.getIsVisible) ~= "function" or not panel:getIsVisible() then
        _previewMoveKey = ""
        return
    end
    if IKST_HubNav and type(IKST_HubNav.isFavoritesView) == "function" and IKST_HubNav.isFavoritesView(panel.view) then
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
