require "ISUI/ISPanel"
require "ISUI/ISModalDialog"
require "AreaSystem/Definitions"
require "AreaSystem/UI/AreaEditorUI"

ISAreaManager = ISPanel:derive("ISAreaManager")

function ISAreaManager:initialise()
    ISPanel.initialise(self)
end

function ISAreaManager:render()
    ISPanel.render(self)
    -- Update selected ID for Map Integration
    if self.areaList and self.areaList.items and self.areaList.items[self.areaList.selected] then
        self.selectedAreaId = self.areaList.items[self.areaList.selected].item.id
    else
        self.selectedAreaId = nil
    end
end

function ISAreaManager:createChildren()
    ISPanel.createChildren(self)

    self.title = "Area Manager"
    
    -- Close Button
    self.closeButton = ISButton:new(self.width - 20, 5, 15, 15, "X", self, self.onClose)
    self.closeButton:initialise()
    self.closeButton.borderColor = {r=0, g=0, b=0, a=0}
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0}
    self:addChild(self.closeButton)

    -- Area List
    self.areaList = ISScrollingListBox:new(10, 40, self.width - 20, self.height - 80)
    self.areaList:initialise()
    self.areaList:instantiate()
    self.areaList.itemheight = 30
    self.areaList.selected = 0
    self.areaList.joypadParent = self
    self.areaList.font = UIFont.NewSmall
    self.areaList.doDrawItem = self.drawAreaItem
    self.areaList.onmousedown = self.onAreaListMouseDown
    self.areaList.target = self
    self.areaList.drawBorder = true
    self:addChild(self.areaList)

    -- Drawing Mode Toggle
    self.drawTick = ISTickBox:new(15, self.height - 65, 200, 20, "Drawing Mode", self, self.onToggleDraw)
    self.drawTick:initialise()
    self.drawTick:addOption("Enable Drawing Mode (Drag on Map)")
    self:addChild(self.drawTick)

    -- Buttons
    self.createBtn = ISButton:new(10, self.height - 35, 90, 25, "New Area", self, self.onCreateArea)
    self.createBtn:initialise()
    self:addChild(self.createBtn)

    self.deleteBtn = ISButton:new(110, self.height - 35, 90, 25, "Delete", self, self.onDeleteArea)
    self.deleteBtn:initialise()
    self:addChild(self.deleteBtn)

    self:populateList()
end

function ISAreaManager:drawAreaItem(y, item, alt)
    local a = 0.9
    
    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    end

    if alt then
        self:drawRect(0, (y), self:getWidth(), item.height - 1, 0.3, 0.6, 0.6, 0.6)
    end
    
    self:drawRectBorder(0, (y), self:getWidth(), item.height - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local area = item.item
    
    -- Draw Color box
    self:drawRect(5, y + 5, 20, 20, 1, area.color.r, area.color.g, area.color.b)
    self:drawRectBorder(5, y + 5, 20, 20, 1, 1, 1, 1)

    self:drawText(area.name, 35, y + 8, 1, 1, 1, 1, UIFont.NewSmall)
    
    return y + item.height
end

function ISAreaManager:populateList()
    -- Enable saving selection across refreshes
    local currentSelectedId = self.selectedAreaId
    -- Fallback: try to get ID from current list item if selectedAreaId is not set
    if not currentSelectedId and self.areaList.items then
        local selItem = self.areaList.items[self.areaList.selected]
        if selItem and selItem.item then
            currentSelectedId = selItem.item.id
        end
    end

    self.areaList:clear()
    
    local areas = AreaSystem.Client.Data.Areas
    if not areas then 
        print("[AreaSystem] AreaManagerUI: No Areas Data Table found (nil)")
        return 
    end

    -- Sort for stability
    local sorted = {}
    for id, area in pairs(areas) do
        if type(area) == "table" then
            table.insert(sorted, area)
        end
    end
    table.sort(sorted, function(a,b) 
        local na = a.name or ""
        local nb = b.name or ""
        if na == nb then
             local idA = tostring(a.id or "")
             local idB = tostring(b.id or "")
             return idA < idB
        end
        return na < nb 
    end)

    for _, area in ipairs(sorted) do
        local display = area.name or "Unnamed"
        
        -- Safe AddItem: Ensure display text is a string
        local item = self.areaList:addItem(tostring(display), area)
        
        -- Restore selection
        if currentSelectedId and area.id == currentSelectedId then
            self.areaList.selected = item.index
        end
    end
    
    -- Debug Indicator
    if #sorted == 0 then
        local item = self.areaList:addItem("No Areas Found (Ver " .. tostring(getTimeInMillis()) .. ")", nil)
        item.item = {id="none", name="No Areas", color={r=0.5,g=0.5,b=0.5,a=0.5}}
    end
    
    -- Fix: Valid selection range check
    local sel = tonumber(self.areaList.selected)
    if not sel then 
        self.areaList.selected = 1
        sel = 1
    end
    
    if sel > #self.areaList.items then
        self.areaList.selected = 1
    end
    if sel < 1 and #self.areaList.items > 0 then
        self.areaList.selected = 1
    end
end

function ISAreaManager:onAreaListMouseDown(item)
    if item then
        -- Update internal selection ID immediately on click
        self.selectedAreaId = item.id
        AreaSystem.OpenAreaEditor(item)
    end
end

function ISAreaManager:updateSelection()
     local sel = self.areaList.items[self.areaList.selected]
     if sel then
         self.selectedAreaId = sel.item.id
     else
         self.selectedAreaId = nil
     end
end

function ISAreaManager:onToggleDraw(index, selected)
    self.isDrawingMode = selected
end

function ISAreaManager:onCreateArea()
    local newArea = AreaSystem.CreateArea("New Area")
    AreaSystem.OpenAreaEditor(newArea)
end

function ISAreaManager:onEditArea()
    local item = self.areaList.items[self.areaList.selected]
    if item then
        AreaSystem.OpenAreaEditor(item.item)
    end
end

function ISAreaManager:onDeleteArea()
    local selected = self.areaList.items[self.areaList.selected]
    if selected then
        local area = selected.item
        self.areaToDeleteId = area.id
        local modal = ISModalDialog:new(0, 0, 250, 150, "Are you sure you want to delete area '" .. area.name .. "' and ALL its shapes?", true, self, self.onConfirmDeleteArea)
        modal:initialise()
        modal:setAlwaysOnTop(true)
        modal:addToUIManager()
    end
end

function ISAreaManager:onConfirmDeleteArea(button)
    if button.internal == "YES" and self.areaToDeleteId then
        AreaSystem.Client.RemoveArea(self.areaToDeleteId)
        self.areaToDeleteId = nil
    end
end

function ISAreaManager:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    
    -- Close Child UIs
    if ISAreaEditor.instance and ISAreaEditor.instance:isVisible() then
        ISAreaEditor.instance:onClose()
    end
    if ISShapeEditor.instance and ISShapeEditor.instance:isVisible() then
        ISShapeEditor.instance:onClose()
    end
    
    -- Deselect Shape
    AreaSystem.Map.SelectedShapeId = nil
end

function ISAreaManager:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.title, self.width / 2 - (getTextManager():MeasureStringX(UIFont.Medium, self.title) / 2), 10, 1, 1, 1, 1, UIFont.Medium)
end

-- Singleton Access
function ISAreaManager.OnOpenPanel()
    if ISAreaManager.instance then
        ISAreaManager.instance:setVisible(true)
        ISAreaManager.instance:populateList()
        ISAreaManager.instance:addToUIManager()
        ISAreaManager.instance:setAlwaysOnTop(true)
        return
    end

    local ui = ISAreaManager:new(100, 100, 400, 500)
    ui:initialise()
    ui:addToUIManager()
    ui:setAlwaysOnTop(true)
    ISAreaManager.instance = ui
end

-- Refresh listener
local function onDataChanged()
    if ISAreaManager.instance and ISAreaManager.instance:isVisible() then
        ISAreaManager.instance:populateList()
    end
end

AreaSystem.Events.OnDataChanged:Add(onDataChanged)

-- Constructor
function ISAreaManager:new(x, y, width, height)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.variable = nil
    o.name = nil
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor = {r=1, g=1, b=1, a=0.5}
    o.width = width
    o.height = height
    return o
end
