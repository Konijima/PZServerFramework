require "AreaSystem/Definitions"

LuaEventManager.AddEvent("OnAreaSystemDataChanged")

AreaSystem.Client = {}

AreaSystem.Client.Data = {
    Areas = {},
    Shapes = {}
}

-- IO Configuration
local SAVE_FILE = "AreaSystem_Data.txt"
local DELIMITER = "|"

-- Local Persistence Logic (Client Side Only)
function AreaSystem.Client.LoadData()
    print("[AreaSystem] AreaSystem: Loading Local Client Data...")
    
    -- Ensure fresh table
    AreaSystem.Client.Data = { Areas = {}, Shapes = {} }
    
    local fileReader = getFileReader(SAVE_FILE, false) -- read, don't create if missing
    if not fileReader then 
        print("[AreaSystem] AreaSystem: No local save file found. Starting fresh.")
        return 
    end

    local line = fileReader:readLine()
    while line do
        local parts = {}
        for part in string.gmatch(line, "([^" .. DELIMITER .. "]+)") do
            table.insert(parts, part)
        end
        
        if parts[1] == "AREA" and #parts >= 7 then
            local area = {
                id = parts[2],
                name = parts[3],
                color = { r=tonumber(parts[4]), g=tonumber(parts[5]), b=tonumber(parts[6]), a=tonumber(parts[7]) }
            }
            AreaSystem.Client.Data.Areas[area.id] = area
            
        elseif parts[1] == "SHAPE" and #parts >= 10 then
            local shape = {
                id = parts[2],
                areaId = parts[3],
                type = parts[4],
                x = tonumber(parts[5]),
                y = tonumber(parts[6]),
                x2 = tonumber(parts[7]),
                y2 = tonumber(parts[8]),
                z = tonumber(parts[9]),
                mapId = parts[10]
            }
            AreaSystem.Client.Data.Shapes[shape.id] = shape
        end
        
        line = fileReader:readLine()
    end
    
    fileReader:close()
    
    local c = 0
    for k,v in pairs(AreaSystem.Client.Data.Areas) do c = c + 1 end
    print("[AreaSystem] AreaSystem: Loaded Local Data. Count: " .. c)
    
    triggerEvent("OnAreaSystemDataChanged")
end

function AreaSystem.Client.SaveData()
    print("[AreaSystem] AreaSystem: Saving Local Client Data...")
    
    local fileWriter = getFileWriter(SAVE_FILE, true, false) -- create, don't append (overwrite)
    if not fileWriter then
        print("[AreaSystem] AreaSystem: Failed to create save file writer!")
        return
    end
    
    -- Save Areas
    for id, area in pairs(AreaSystem.Client.Data.Areas) do
        -- AREA|id|name|colorR|colorG|colorB|colorA
        local line = "AREA" .. DELIMITER ..
                     tostring(area.id) .. DELIMITER ..
                     tostring(area.name) .. DELIMITER ..
                     tostring(area.color.r) .. DELIMITER ..
                     tostring(area.color.g) .. DELIMITER ..
                     tostring(area.color.b) .. DELIMITER ..
                     tostring(area.color.a)
        fileWriter:write(line .. "\r\n")
    end
    
    -- Save Shapes
    for id, shape in pairs(AreaSystem.Client.Data.Shapes) do
        -- SHAPE|id|areaId|type|x|y|x2|y2|z|mapId
        local line = "SHAPE" .. DELIMITER ..
                     tostring(shape.id) .. DELIMITER ..
                     tostring(shape.areaId) .. DELIMITER ..
                     tostring(shape.type) .. DELIMITER ..
                     tostring(shape.x) .. DELIMITER ..
                     tostring(shape.y) .. DELIMITER ..
                     tostring(shape.x2) .. DELIMITER ..
                     tostring(shape.y2) .. DELIMITER ..
                     tostring(shape.z) .. DELIMITER ..
                     tostring(shape.mapId)
        fileWriter:write(line .. "\r\n")
    end
    
    fileWriter:close()
    print("[AreaSystem] AreaSystem: Saved Local Data.")
end


function AreaSystem.Client.OnInitWorld()
    print("[AreaSystem] AreaSystem: Client Init (Local Mode)")
    AreaSystem.Client.LoadData()
end

-- Replaces Network Commands
function AreaSystem.Client.UpdateArea(area)
    AreaSystem.Client.Data.Areas[area.id] = area
    AreaSystem.Client.SaveData()
    triggerEvent("OnAreaSystemDataChanged")
end

function AreaSystem.Client.RemoveArea(id)
    AreaSystem.Client.Data.Areas[id] = nil
    -- Remove linked shapes
    for k, v in pairs(AreaSystem.Client.Data.Shapes) do
        if v.areaId == id then
             AreaSystem.Client.Data.Shapes[k] = nil
        end
    end
    AreaSystem.Client.SaveData()
    triggerEvent("OnAreaSystemDataChanged")
end

function AreaSystem.Client.UpdateShape(shape)
    AreaSystem.Client.Data.Shapes[shape.id] = shape
    AreaSystem.Client.SaveData()
    triggerEvent("OnAreaSystemDataChanged")
end

function AreaSystem.Client.RemoveShape(id)
    AreaSystem.Client.Data.Shapes[id] = nil
    AreaSystem.Client.SaveData()
    triggerEvent("OnAreaSystemDataChanged")
end

-- Snap / Overlap Logic
function AreaSystem.Client.CheckOverlap(x1, y1, x2, y2, ignoreShapeId)
    local shapes = AreaSystem.Client.Data.Shapes
    for id, shape in pairs(shapes) do
        if id ~= ignoreShapeId then
            local sx, sx2 = math.min(shape.x, shape.x2), math.max(shape.x, shape.x2)
            local sy, sy2 = math.min(shape.y, shape.y2), math.max(shape.y, shape.y2)
            
            -- Check for intersection
            if x1 < sx2 and x2 > sx and y1 < sy2 and y2 > sy then
                return true
            end
        end
    end
    return false
end

Events.OnInitWorld.Add(AreaSystem.Client.OnInitWorld)

print("[AreaSystem] AreaSystem: Client Core Loaded (Local Storage Mode)")

