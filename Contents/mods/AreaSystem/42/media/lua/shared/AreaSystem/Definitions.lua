AreaSystem = AreaSystem or {}

--- Constructor for a new Area Object
function AreaSystem.CreateArea(name)
    return {
        id = tostring(getRandomUUID()),
        name = name or "New Area",
        color = { r = 0, g = 1, b = 0, a = 0.3 }
    }
end

--- Constructor for a new Shape Object
function AreaSystem.CreateShape(areaId, x, y, x2, y2)
    return {
        id = tostring(getRandomUUID()),
        areaId = tostring(areaId),
        type = "RECTANGLE",
        x = x,
        y = y,
        x2 = x2,
        y2 = y2,
        z = 0,
        mapId = "Base"
    }
end

print("[AreaSystem] Shared Definitions Loaded")

