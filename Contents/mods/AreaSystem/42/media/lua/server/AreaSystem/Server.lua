if isClient() then return end

require "AreaSystem/Definitions"

AreaSystem.Server = {}
local Server = AreaSystem.Server
local MP = KoniLib.MP

Server.Data = {
    Areas = {},
    Shapes = {}
}

-- IO Configuration
local DELIMITER = "|"

-- Helper to get the save-specific filename
local function getSaveFile()
    local saveName = "default"
    if isServer() then
        saveName = getServerName() or "server"
    else
        -- Singleplayer
        saveName = getCore():getSaveFolder() or "sp"
    end
    return "AreaSystem_" .. saveName .. "_Data.txt"
end

-- Persistence Logic
function Server.LoadData()
    local fileName = getSaveFile()
    print("[AreaSystem] Server: Loading Data from " .. fileName)
    
    Server.Data = { Areas = {}, Shapes = {} }
    
    local fileReader = getFileReader(fileName, false)
    if not fileReader then 
        print("[AreaSystem] Server: No save file found. Starting fresh.")
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
            Server.Data.Areas[area.id] = area
            
        elseif parts[1] == "SHAPE" and #parts >= 10 then
            local shape = {
                id = parts[2],
                areaId = parts[3],
                type = parts[4],
                x = tonumber(parts[5]),
                y = tonumber(parts[6]),
                z = tonumber(parts[7]),
                x2 = tonumber(parts[8]),
                y2 = tonumber(parts[9])
            }
            Server.Data.Shapes[shape.id] = shape
        end
        
        line = fileReader:readLine()
    end
    fileReader:close()
end

function Server.SaveData()
    local fileName = getSaveFile()
    print("[AreaSystem] Server: Saving Data to " .. fileName)
    local fileWriter = getFileWriter(fileName, true, false)
    
    for _, area in pairs(Server.Data.Areas) do
        local line = "AREA" .. DELIMITER .. area.id .. DELIMITER .. area.name .. DELIMITER .. 
                     area.color.r .. DELIMITER .. area.color.g .. DELIMITER .. area.color.b .. DELIMITER .. area.color.a
        fileWriter:write(line .. "\r\n")
    end
    
    for _, shape in pairs(Server.Data.Shapes) do
        local line = "SHAPE" .. DELIMITER .. shape.id .. DELIMITER .. shape.areaId .. DELIMITER .. shape.type .. DELIMITER ..
                     shape.x .. DELIMITER .. shape.y .. DELIMITER .. shape.z .. DELIMITER .. shape.x2 .. DELIMITER .. shape.y2
        fileWriter:write(line .. "\r\n")
    end
    
    fileWriter:close()
end

-- Events
Events.OnGameStart.Add(Server.LoadData)

-- ==========================================================
-- Networking Handlers
-- ==========================================================

-- Client requesting full sync (e.g. on join)
MP.Register("AreaSystem", "RequestSync", function(player, args)
    MP.Send(player, "AreaSystem", "SyncData", Server.Data)
end)

-- AREA COMMANDS

MP.Register("AreaSystem", "AddArea", function(player, args)
    if not args.id then return end
    Server.Data.Areas[args.id] = args
    Server.SaveData()
    -- Broadcast to all clients (pass nil as target)
    MP.Send(nil, "AreaSystem", "AreaAdded", args)
end)

MP.Register("AreaSystem", "UpdateArea", function(player, args)
    if not args.id or not Server.Data.Areas[args.id] then return end
    Server.Data.Areas[args.id] = args
    Server.SaveData()
    MP.Send(nil, "AreaSystem", "AreaUpdated", args)
end)

MP.Register("AreaSystem", "RemoveArea", function(player, args)
    if not args.id then return end
    Server.Data.Areas[args.id] = nil
    -- Also remove linked shapes
    for shapeId, shape in pairs(Server.Data.Shapes) do
        if shape.areaId == args.id then
            Server.Data.Shapes[shapeId] = nil
        end
    end
    Server.SaveData()
    MP.Send(nil, "AreaSystem", "AreaRemoved", args)
end)

-- SHAPE COMMANDS

MP.Register("AreaSystem", "AddShape", function(player, args)
    if not args.id then return end
    Server.Data.Shapes[args.id] = args
    Server.SaveData()
    MP.Send(nil, "AreaSystem", "ShapeAdded", args)
end)

MP.Register("AreaSystem", "UpdateShape", function(player, args)
    if not args.id or not Server.Data.Shapes[args.id] then return end
    Server.Data.Shapes[args.id] = args
    Server.SaveData()
    MP.Send(nil, "AreaSystem", "ShapeUpdated", args)
end)

MP.Register("AreaSystem", "RemoveShape", function(player, args)
    if not args.id then return end
    Server.Data.Shapes[args.id] = nil
    Server.SaveData()
    MP.Send(nil, "AreaSystem", "ShapeRemoved", args)
end)
