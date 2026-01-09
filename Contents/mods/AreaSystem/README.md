# Area System

**Area System** is a Project Zomboid mod that allows server administrators and developers to define, visualize, and manage custom zones directly on the in-game World Map. It is designed to work seamlessly with both isometric (in-game) and orthographic (map) projections.

## Key Features

### 🗺️ Map Integration
- **Direct Editing**: Accessible via a generic "Manage Areas" button added to the `ISWorldMap` interface.
- **Isometric Rendering**: Custom rendering pipeline that draws thick, visible lines on the map that scale correctly with zoom.
- **Fog of War Support**: Areas are rendered over the map layer (work in progress for comprehensive fog bypass).

### ��️ Editor Tools
- **Robust Shape Management**:
  - **Drawing Mode**: Click and drag to create rectangular regions.
  - **Grid Snapping**: All shapes snap to the 1x1 tile grid for precise alignment.
  - **Edit & Resize**: Select existing shapes to move them or resize them using drag handles.
  - **Overlap Prevention**: Logic prevents creating or moving shapes into existing ones to ensure unique zone definitions.
- **Area Metadata**:
  - Assign custom Names and Colors to areas.
  - Reassign shapes between different Areas using the Shape Editor.
- **Safety**: Confirmation dialogs for deleting Areas or individual Shapes.

### 💾 Data Persistence
- Currently operates in **Local Client Mode** (saving to `AreaSystem_Data.txt`) for testing.
- Structure prepared for networked synchronization (Client <-> Server).

## User Guide

1.  **Open Map**: Press `M` to open the World Map.
2.  **Open Manager**: Click the **"Manage Areas"** button in the top-right corner.
3.  **Create Area**: Click "New Area", give it a name and pick a color.
4.  **Draw Shapes**:
    *   Select the area in the list.
    *   Check the **"Drawing Mode"** box.
    *   Left-click and drag on the map to create a rectangle.
5.  **Edit Shapes**:
    *   Uncheck "Drawing Mode".
    *   Click on any existing shape to select it.
    *   Drag the **Box** to move it.
    *   Drag the **White Squares** (handles) to resize it.
    *   Use the popup window to Change the Area or Delete the shape.

## For Developers

The system exposes a global `AreaSystem` table.

### Structure
*   `Contents/mods/AreaSystem/media/lua/client`: Client-side UI and Rendering logic.
*   `Contents/mods/AreaSystem/media/lua/shared`: Definitions and classes.
*   `Contents/mods/AreaSystem/media/lua/server`: Server data handling.

### API Usage (Planned/WIP)

```lua
-- Hook into events
Events.OnAreaSystemDataChanged.Add(function()
    print("Area Data Updated!")
end)

-- Access Data
local areas = AreaSystem.Client.Data.Areas
for id, area in pairs(areas) do
    print("Area: " .. area.name)
end
```

## Compatibility
- Supports **Build 42**
