require "ISUI/Maps/ISWorldMap"
require "AreaSystem/UI/AreaManagerUI"
require "AreaSystem/UI/AreaEditorUI"
require "AreaSystem/UI/ShapeEditorUI"

AreaSystem.Map = {}
AreaSystem.Map.IsDrawing = false
AreaSystem.Map.StartDrag = nil
AreaSystem.Map.SelectedShapeId = nil
AreaSystem.Map.DragMode = nil -- "CREATE", "MOVE", "RESIZE_N", "RESIZE_S", "RESIZE_E", "RESIZE_W"
AreaSystem.Map.DragOffset = nil 
AreaSystem.Map.OriginalShape = nil -- Snapshot for resize calculations

-- Colors for rendering
local cBorder = {r=1, g=1, b=0, a=1}
local cFill = {r=1, g=1, b=0, a=0.2}

-- Inject Button into WorldMap
local old_ISWorldMap_createChildren = ISWorldMap.createChildren
function ISWorldMap:createChildren()
    old_ISWorldMap_createChildren(self)
    
    local btn = ISButton:new(self.width - 160, 20, 140, 30, "Manage Areas", self, AreaSystem.Map.OnToggleUI)
    btn:initialise()
    btn.backgroundColor = {r=0, g=0, b=0, a=0.8}
    btn.borderColor = {r=1, g=1, b=1, a=0.5}
    btn:setAnchorLeft(false)
    btn:setAnchorRight(true)
    btn:setAnchorTop(true)
    btn:setAnchorBottom(false)
    self:addChild(btn)
    self.areaBtn = btn
end

function AreaSystem.Map.OnToggleUI()
    if ISAreaManager.instance and ISAreaManager.instance:isVisible() then
        AreaSystem.CloseAllUI()
    else
        ISAreaManager.OnOpenPanel()
    end
end

function AreaSystem.CloseAllUI()
    if ISAreaManager.instance then ISAreaManager.instance:onClose() end
    if ISAreaEditor.instance then ISAreaEditor.instance:onClose() end
    if ISShapeEditor.instance then ISShapeEditor.instance:onClose() end
end

local old_ISWorldMap_close = ISWorldMap.close
function ISWorldMap:close()
    if old_ISWorldMap_close then old_ISWorldMap_close(self) end
    AreaSystem.CloseAllUI()
end

-- Helper: Get Handle under mouse
function AreaSystem.Map.GetHandleAt(api, shape, mx, my)
    -- Calculate 4 corners in UI space
    local x1 = api:worldToUIX(shape.x, shape.y)
    local y1 = api:worldToUIY(shape.x, shape.y)
    local x2 = api:worldToUIX(shape.x2, shape.y)
    local y2 = api:worldToUIY(shape.x2, shape.y)
    local x3 = api:worldToUIX(shape.x2, shape.y2)
    local y3 = api:worldToUIY(shape.x2, shape.y2)
    local x4 = api:worldToUIX(shape.x, shape.y2)
    local y4 = api:worldToUIY(shape.x, shape.y2)
    
    local threshold = 10 -- Handle detection radius
    
    -- Midpoints for handles
    local midN_x, midN_y = (x1 + x2) / 2, (y1 + y2) / 2
    local midE_x, midE_y = (x2 + x3) / 2, (y2 + y3) / 2
    local midS_x, midS_y = (x3 + x4) / 2, (y3 + y4) / 2
    local midW_x, midW_y = (x4 + x1) / 2, (y4 + y1) / 2
    
    -- Check Handles
    if math.abs(mx - midN_x) < threshold and math.abs(my - midN_y) < threshold then return "RESIZE_N" end
    if math.abs(mx - midS_x) < threshold and math.abs(my - midS_y) < threshold then return "RESIZE_S" end
    if math.abs(mx - midW_x) < threshold and math.abs(my - midW_y) < threshold then return "RESIZE_W" end
    if math.abs(mx - midE_x) < threshold and math.abs(my - midE_y) < threshold then return "RESIZE_E" end
    
    -- Check Body (Move)
    local wx = api:uiToWorldX(mx, my)
    local wy = api:uiToWorldY(mx, my)
    
    local sx, sx2 = math.min(shape.x, shape.x2), math.max(shape.x, shape.x2)
    local sy, sy2 = math.min(shape.y, shape.y2), math.max(shape.y, shape.y2)
    
    if wx >= sx and wx <= sx2 and wy >= sy and wy <= sy2 then return "MOVE" end
    
    return nil
end

-- Monitor Mouse Move for Dragging
local old_ISWorldMap_onMouseMove = ISWorldMap.onMouseMove
function ISWorldMap:onMouseMove(dx, dy)
    old_ISWorldMap_onMouseMove(self, dx, dy)
    
    if AreaSystem.Map.DragMode and AreaSystem.Map.DragStart then
        local api = self.javaObject:getAPI()
        local mx = self:getMouseX()
        local my = self:getMouseY()
        
        -- Logic for updating shape is complicated because we modify World Coords
        -- but mouse is in UI Coords.
        -- We will do the "Apply" step in MouseUp, but here we could preview?
        -- For now, let's just rely on MouseUp for the actual data change to avoid network spam,
        -- but we need visual feedback.
    end
end

function AreaSystem.Map.DrawThickLine(ui, x1, y1, x2, y2, thickness, r, g, b, a)
    if thickness <= 1 then
        ui:drawLine2(x1, y1, x2, y2, a, r, g, b)
        return
    end

    local dx = x2 - x1
    local dy = y2 - y1

    if math.abs(dx) < 0.5 then
        local x = (x1 + x2) / 2
        local ymin = math.min(y1, y2)
        local h = math.abs(dy)
        ui:drawRect(x - thickness/2, ymin, thickness, h, a, r, g, b)
    elseif math.abs(dy) < 0.5 then
        local y = (y1 + y2) / 2
        local xmin = math.min(x1, x2)
        local w = math.abs(dx)
        ui:drawRect(xmin, y - thickness/2, w, thickness, a, r, g, b)
    else
        -- High quality thick line using perpendicular offsets
        local len = math.sqrt(dx*dx + dy*dy)
        if len == 0 then return end
        
        -- Normalized perpendicular vector (-dy, dx)
        local nx = -dy / len
        local ny = dx / len
        
        -- Draw lines parallel to the main segment
        local half = thickness / 2
        for i = -half, half, 0.5 do -- 0.5 step for denser fill
            local ox = nx * i
            local oy = ny * i
            ui:drawLine2(x1 + ox, y1 + oy, x2 + ox, y2 + oy, a, r, g, b)
        end
    end
end

-- Inject Rendering
local old_ISWorldMap_render = ISWorldMap.render
function ISWorldMap:render()
    old_ISWorldMap_render(self)
    
    if not AreaSystem.Client or not AreaSystem.Client.Data then return end
    
    local shapes = AreaSystem.Client.Data.Shapes
    if not shapes then return end
    
    local api = self.javaObject:getAPI()
    
    for id, shape in pairs(shapes) do
        local isSelected = (AreaSystem.Map.SelectedShapeId == id)
        
        local px, py, px2, py2 = shape.x, shape.y, shape.x2, shape.y2

        -- Apply drag offset if needed
        if isSelected and AreaSystem.Map.DragMode and AreaSystem.Map.DragMode ~= "CREATE" and AreaSystem.Map.DragStart then
            local mx = self:getMouseX()
            local my = self:getMouseY()
            local wx = math.floor(api:uiToWorldX(mx, my))
            local wy = math.floor(api:uiToWorldY(mx, my))
            
            local og = AreaSystem.Map.DragStart.shape
            local dx = wx - AreaSystem.Map.DragStart.x
            local dy = wy - AreaSystem.Map.DragStart.y
            
            px, py, px2, py2 = og.x, og.y, og.x2, og.y2
            
            if AreaSystem.Map.DragMode == "MOVE" then
                px = px + dx
                py = py + dy
                px2 = px2 + dx
                py2 = py2 + dy
            elseif AreaSystem.Map.DragMode == "RESIZE_E" then
                px2 = px2 + dx
            elseif AreaSystem.Map.DragMode == "RESIZE_W" then
                px = px + dx
            elseif AreaSystem.Map.DragMode == "RESIZE_N" then
                py = py + dy
            elseif AreaSystem.Map.DragMode == "RESIZE_S" then
                py2 = py2 + dy
            end
        end

        local x1 = api:worldToUIX(px, py)
        local y1 = api:worldToUIY(px, py)
        local x2 = api:worldToUIX(px2, py)
        local y2 = api:worldToUIY(px2, py)
        local x3 = api:worldToUIX(px2, py2)
        local y3 = api:worldToUIY(px2, py2)
        local x4 = api:worldToUIX(px, py2)
        local y4 = api:worldToUIY(px, py2)
        
        -- Get Area color
        local color = {r=0, g=1, b=0, a=0.3}
        if AreaSystem.Client.Data.Areas[shape.areaId] then
            local ac = AreaSystem.Client.Data.Areas[shape.areaId].color
            if ac then color = ac end
        else
            -- Orphan shape? Skip or Draw Red?
            color = {r=1, g=0, b=0, a=0.3}
        end
        
        -- Draw Outline
        local thickness = 2
        
        AreaSystem.Map.DrawThickLine(self, x1, y1, x2, y2, thickness, color.r, color.g, color.b, 1)
        AreaSystem.Map.DrawThickLine(self, x2, y2, x3, y3, thickness, color.r, color.g, color.b, 1)
        AreaSystem.Map.DrawThickLine(self, x3, y3, x4, y4, thickness, color.r, color.g, color.b, 1)
        AreaSystem.Map.DrawThickLine(self, x4, y4, x1, y1, thickness, color.r, color.g, color.b, 1)
        
        if isSelected then
             -- Draw Handles
             local midN_x, midN_y = (x1 + x2) / 2, (y1 + y2) / 2
             local midE_x, midE_y = (x2 + x3) / 2, (y2 + y3) / 2
             local midS_x, midS_y = (x3 + x4) / 2, (y3 + y4) / 2
             local midW_x, midW_y = (x4 + x1) / 2, (y4 + y1) / 2
            
            local hs = 2 -- Handle Half Size
            
            -- N
            self:drawRect(midN_x - hs, midN_y - hs, hs*2, hs*2, 1, 1, 1, 1)
            -- S
            self:drawRect(midS_x - hs, midS_y - hs, hs*2, hs*2, 1, 1, 1, 1)
            -- W
            self:drawRect(midW_x - hs, midW_y - hs, hs*2, hs*2, 1, 1, 1, 1)
            -- E
            self:drawRect(midE_x - hs, midE_y - hs, hs*2, hs*2, 1, 1, 1, 1)
        end
        
        -- Draw label
        if self.mapAPI:getZoomF() > 14 then 
             if AreaSystem.Client.Data.Areas[shape.areaId] then
                local text = AreaSystem.Client.Data.Areas[shape.areaId].name
                local centerX = (x1 + x3) / 2
                local centerY = (y1 + y3) / 2
                self:drawTextCentre(text, centerX, centerY - 7, 1, 1, 1, 1, UIFont.NewSmall)
            end
        end
    end

    -- Draw Dragging Box (Create Mode)
    if AreaSystem.Map.DragMode == "CREATE" and AreaSystem.Map.DragStart then
        local mx = self:getMouseX()
        local my = self:getMouseY()
        
        -- Get Drag Start and End in World Coordinates
        local wxStart = AreaSystem.Map.DragStart.x
        local wyStart = AreaSystem.Map.DragStart.y
        local wxEnd = math.floor(api:uiToWorldX(mx, my))
        local wyEnd = math.floor(api:uiToWorldY(mx, my))

        -- Calculate overlap for potential new shape
        local _x1, _x2 = math.min(wxStart, wxEnd), math.max(wxStart, wxEnd)
        local _y1, _y2 = math.min(wyStart, wyEnd), math.max(wyStart, wyEnd)
        
        local isOverlapping = AreaSystem.Client.CheckOverlap and AreaSystem.Client.CheckOverlap(_x1, _y1, _x2, _y2, nil)

        -- Calculate 4 corners in World Coordinates
        local wx1, wy1 = wxStart, wyStart
        local wx2, wy2 = wxEnd, wyStart
        local wx3, wy3 = wxEnd, wyEnd
        local wx4, wy4 = wxStart, wyEnd

        -- Convert to UI Coordinates
        local ux1 = api:worldToUIX(wx1, wy1)
        local uy1 = api:worldToUIY(wx1, wy1)
        local ux2 = api:worldToUIX(wx2, wy2)
        local uy2 = api:worldToUIY(wx2, wy2)
        local ux3 = api:worldToUIX(wx3, wy3)
        local uy3 = api:worldToUIY(wx3, wy3)
        local ux4 = api:worldToUIX(wx4, wy4)
        local uy4 = api:worldToUIY(wx4, wy4)

        local r, g, b = 1, 1, 1
        if isOverlapping then r, g, b = 1, 0, 0 end -- RED if overlapping

        self:drawLine2(ux1, uy1, ux2, uy2, 1, r, g, b)
        self:drawLine2(ux2, uy2, ux3, uy3, 1, r, g, b)
        self:drawLine2(ux3, uy3, ux4, uy4, 1, r, g, b)
        self:drawLine2(ux4, uy4, ux1, uy1, 1, r, g, b)
    end
end


local old_ISWorldMap_onMouseDown = ISWorldMap.onMouseDown
function ISWorldMap:onMouseDown(x, y)
    -- 1. Check if Create Mode is active via UI
    if ISAreaManager.instance and ISAreaManager.instance:isVisible() and ISAreaManager.instance.isDrawingMode then
         local api = self.javaObject:getAPI()
         local wx = math.floor(api:uiToWorldX(x, y))
         local wy = math.floor(api:uiToWorldY(x, y))
         
         AreaSystem.Map.DragStart = {x = wx, y = wy}
         AreaSystem.Map.DragMode = "CREATE"
         AreaSystem.Map.SelectedShapeId = nil -- Deselect when creating
         return 
    end
    
    -- Check if Area Manager UI is open before allowing interaction
    if not ISAreaManager.instance or not ISAreaManager.instance:isVisible() then
        AreaSystem.Map.SelectedShapeId = nil -- Deselect if UI is closed
        old_ISWorldMap_onMouseDown(self, x, y)
        return
    end

    -- 2. Check Selection Interaction (Handles or Move)
    if AreaSystem.Map.SelectedShapeId and AreaSystem.Client.Data.Shapes[AreaSystem.Map.SelectedShapeId] then
        local shape = AreaSystem.Client.Data.Shapes[AreaSystem.Map.SelectedShapeId]
        local api = self.javaObject:getAPI()
        
        local mode = AreaSystem.Map.GetHandleAt(api, shape, x, y)
        if mode then
             local wx = math.floor(api:uiToWorldX(x, y))
             local wy = math.floor(api:uiToWorldY(x, y))
             
             AreaSystem.Map.DragMode = mode
             -- Store snapshot for deltas
             AreaSystem.Map.DragStart = {
                 x = wx, y = wy, 
                 shape = {x=shape.x, y=shape.y, x2=shape.x2, y2=shape.y2}
             }
             return
        end
    end
    
    -- 3. Check for New Selection (Clicking any shape)
    if AreaSystem.Client.Data and AreaSystem.Client.Data.Shapes then
         local api = self.javaObject:getAPI()
         local wx = math.floor(api:uiToWorldX(x, y))
         local wy = math.floor(api:uiToWorldY(x, y))
         
         for id, shape in pairs(AreaSystem.Client.Data.Shapes) do
             -- Use World Coords for check (Handles rotation automatically)
             local sx, sx2 = math.min(shape.x, shape.x2), math.max(shape.x, shape.x2)
             local sy, sy2 = math.min(shape.y, shape.y2), math.max(shape.y, shape.y2)
            
            if wx >= sx and wx <= sx2 and wy >= sy and wy <= sy2 then
                AreaSystem.Map.SelectedShapeId = id
                AreaSystem.OpenShapeEditor(shape) -- Open Side Panel
                
                -- Also immediately start Moving it if user wants? 
                -- standard UX: Click = Select. Click+Drag = Move.
                -- For now just Select.
                return 
            end
         end
    end
    
    -- Deselect if clicking void
    AreaSystem.Map.SelectedShapeId = nil
    
    if ISShapeEditor.instance and ISShapeEditor.instance:isVisible() then
        ISShapeEditor.instance:onClose()
    end
    
    if ISAreaEditor.instance and ISAreaEditor.instance:isVisible() then
        ISAreaEditor.instance:onClose()
    end

    old_ISWorldMap_onMouseDown(self, x, y)
    
    -- Fix: Ensure UI stays on top if Map tries to grab focus
    if ISAreaManager.instance and ISAreaManager.instance:isVisible() then
        ISAreaManager.instance:setAlwaysOnTop(true)
        ISAreaManager.instance:bringToTop()
        if ISAreaEditor.instance and ISAreaEditor.instance:isVisible() then
            ISAreaEditor.instance:setAlwaysOnTop(true)
            ISAreaEditor.instance:bringToTop()
        end
        if ISShapeEditor.instance and ISShapeEditor.instance:isVisible() then
            ISShapeEditor.instance:setAlwaysOnTop(true)
            ISShapeEditor.instance:bringToTop()
        end
    end
end

local old_ISWorldMap_onMouseUp = ISWorldMap.onMouseUp
function ISWorldMap:onMouseUp(x, y)
    if AreaSystem.Map.DragMode and AreaSystem.Map.DragStart then
         local api = self.javaObject:getAPI()
         local wx = math.floor(api:uiToWorldX(x, y))
         local wy = math.floor(api:uiToWorldY(x, y))
         
         if AreaSystem.Map.DragMode == "CREATE" then
             local x1, y1 = AreaSystem.Map.DragStart.x, AreaSystem.Map.DragStart.y
             -- Ensure x1 < x2
             local _x1, _x2 = math.min(x1, wx), math.max(x1, wx)
             local _y1, _y2 = math.min(y1, wy), math.max(y1, wy)
             
             -- Minimum size check
             if (_x2 - _x1) > 1 and (_y2 - _y1) > 1 then
                
                -- Check Overlap
                local isOverlapping = AreaSystem.Client.CheckOverlap and AreaSystem.Client.CheckOverlap(_x1, _y1, _x2, _y2, nil)
                
                if not isOverlapping then
                    if ISAreaManager.instance and ISAreaManager.instance.selectedAreaId then
                        local newShape = AreaSystem.CreateShape(ISAreaManager.instance.selectedAreaId, _x1, _y1, _x2, _y2)
                        AreaSystem.Client.UpdateShape(newShape)
                    end
                end
             end
             
         elseif AreaSystem.Map.SelectedShapeId then
             -- Apply Move or Resize
             local shape = AreaSystem.Client.Data.Shapes[AreaSystem.Map.SelectedShapeId]
             if shape then
                 local og = AreaSystem.Map.DragStart.shape
                 local dx = wx - AreaSystem.Map.DragStart.x
                 local dy = wy - AreaSystem.Map.DragStart.y
                 
                 local newShape = {id=shape.id, areaId=shape.areaId, type=shape.type, z=shape.z}
                 
                 if AreaSystem.Map.DragMode == "MOVE" then
                     newShape.x = og.x + dx
                     newShape.y = og.y + dy
                     newShape.x2 = og.x2 + dx
                     newShape.y2 = og.y2 + dy
                 elseif AreaSystem.Map.DragMode == "RESIZE_E" then
                     newShape.x = og.x
                     newShape.y = og.y
                     newShape.x2 = og.x2 + dx
                     newShape.y2 = og.y2
                 elseif AreaSystem.Map.DragMode == "RESIZE_W" then
                     newShape.x = og.x + dx
                     newShape.y = og.y
                     newShape.x2 = og.x2
                     newShape.y2 = og.y2
                 elseif AreaSystem.Map.DragMode == "RESIZE_N" then
                     newShape.x = og.x
                     newShape.y = og.y + dy
                     newShape.x2 = og.x2
                     newShape.y2 = og.y2
                 elseif AreaSystem.Map.DragMode == "RESIZE_S" then
                     newShape.x = og.x
                     newShape.y = og.y
                     newShape.x2 = og.x2
                     newShape.y2 = og.y2 + dy
                 end
                 
                 local sx, sx2 = math.min(newShape.x, newShape.x2), math.max(newShape.x, newShape.x2)
                 local sy, sy2 = math.min(newShape.y, newShape.y2), math.max(newShape.y, newShape.y2)

                 local isOverlapping = AreaSystem.Client.CheckOverlap and AreaSystem.Client.CheckOverlap(sx, sy, sx2, sy2, shape.id)
                 
                 if not isOverlapping then
                    AreaSystem.Client.UpdateShape(newShape)
                 end
             end
         end

         AreaSystem.Map.DragMode = nil
         AreaSystem.Map.DragStart = nil
         return
    end

    old_ISWorldMap_onMouseUp(self, x, y)
end

print("[AreaSystem] Map Integration Loaded")
