require "IKST_Shared"

require "IKST_Access"

require "IKST_Grid"



local function paintModesWithGhost(mode)

    return mode == IKST.PAINTER_MODES.paint or mode == IKST.PAINTER_MODES.replace

end



local function definePaintCursor()

    if IKST_PaintCursor or not ISBuildingObject then

        return

    end



    IKST_PaintCursor = ISBuildingObject:derive("IKST_PaintCursor")



    function IKST_PaintCursor:new(character, mode)

        local o = ISBuildingObject.new(self)

        o:init()

        o.character = character

        o.player = character and character:getPlayerNum() or 0

        o.mode = mode or IKST.PAINTER_MODES.paint

        o.noNeedHammer = true

        o.skipWalk = true

        o.skipBuildAction = true

        o.canBeBuild = true

        o.buildLow = true

        o.floor = true

        o.dragNilAfterPlace = false

        return o

    end



    function IKST_PaintCursor:setMode(mode)

        self.mode = mode

        if IKST_PaintCursorManager and IKST_PaintCursorManager.syncSprite then

            IKST_PaintCursorManager.syncSprite(self.character)

        end

    end



    function IKST_PaintCursor:haveMaterial(square)

        return true

    end



    function IKST_PaintCursor:walkTo(x, y, z)

        return true

    end



    function IKST_PaintCursor:isValid(square)
        if not square then
            return false
        end
        local ch = self.character
        if ch and ch.getX and IKST.getMaxPaintRadius then
            local dx = square:getX() - ch:getX()
            local dy = square:getY() - ch:getY()
            local maxR = IKST.getMaxPaintRadius()
            if (dx * dx + dy * dy) > (maxR * maxR) then
                return false
            end
        end
        return true
    end



    function IKST_PaintCursor:tryBuild(x, y, z)

        self:create(x, y, z, self.north, self:getSprite())

        self:onActionComplete()

    end



    function IKST_PaintCursor:render(x, y, z, square)

        if paintModesWithGhost(self.mode) and self:getSprite() then

            ISBuildingObject.render(self, x, y, z, square)

            return

        end

        if self.mode == IKST.PAINTER_MODES.remove and square then

            local floor = square.getFloor and square:getFloor()

            if floor and floor.setHighlighted then

                floor:setHighlighted(true)

                if floor.setHighlightColor then

                    floor:setHighlightColor(1, 0.25, 0.25, 0.55)

                end

            end

        end

    end



    function IKST_PaintCursor:pickFromSquare(square)

        if not square then

            return

        end

        local state = IKST.getPlayerState(self.character)

        if not state then

            return

        end

        local floor = square:getFloor()

        local sprite = nil

        if floor and floor.getSprite and floor:getSprite() then

            sprite = floor:getSprite():getName()

        end

        if not sprite then

            local objects = square:getObjects()

            if objects then

                for i = objects:size() - 1, 0, -1 do

                    local obj = objects:get(i)

                    if obj and obj.getSprite and obj:getSprite() then

                        sprite = obj:getSprite():getName()

                        break

                    end

                end

            end

        end

        if not sprite then

            return

        end

        state.currentPick = { sprite = sprite, facing = "N", kind = "tile" }

        IKST.pushRecentSprite(self.character, state.currentPick)

        if state.settings and state.settings.autoPaintAfterEyedropper then

            if IKST_PaintCursorManager and IKST_PaintCursorManager.arm then

                IKST_PaintCursorManager.arm(self.character, IKST.PAINTER_MODES.paint)

            end

        end

        if IKST_JobsPanel and IKST_JobsPanel.instance then

            IKST_JobsPanel.instance:refreshJobUI()

        end

        IKST.notify(self.character, sprite, true)

    end



    function IKST_PaintCursor:create(x, y, z, north, sprite)

        if not self.character or not IKST_Access.canUseTools(self.character) then

            return

        end

        if self.mode == IKST.PAINTER_MODES.eyedropper then

            self:pickFromSquare(IKST_Grid.getSquare(x, y, z))

            return

        end

        local state = IKST.getPlayerState(self.character)

        if self.mode == IKST.PAINTER_MODES.remove then

            IKST.dispatchCommand(self.character, IKST.CMD.paintRemove, { x = x, y = y, z = z })

            return

        end

        if self.mode == IKST.PAINTER_MODES.replace then

            IKST.dispatchCommand(self.character, IKST.CMD.paintRemove, { x = x, y = y, z = z })

        end

        if self.mode == IKST.PAINTER_MODES.paint or self.mode == IKST.PAINTER_MODES.replace then

            local pick = state and state.currentPick

            if not pick or not pick.sprite then

                IKST.notify(self.character, IKST.text("IGUI_IKST_NoPick", "No sprite selected"), false)

                return

            end

            IKST.dispatchCommand(self.character, IKST.CMD.paintPlace, {

                x = x, y = y, z = z, sprite = pick.sprite, facing = pick.facing,

            })

        end

    end

end



if Events and Events.OnGameBoot then

    Events.OnGameBoot.Add(definePaintCursor)

end

if Events and Events.OnGameStart then

    Events.OnGameStart.Add(definePaintCursor)

end

definePaintCursor()



function IKST.ensurePaintCursor()

    definePaintCursor()

    return IKST_PaintCursor ~= nil

end

