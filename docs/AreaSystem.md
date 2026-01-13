# Area System Documentation

**Area System** is a powerful admin tool for Project Zomboid that allows you to create, manage, and visualize custom zones directly on the in-game world map.

## Key Features

*   **In-Game Map Integration**: Seamlessly integrated into the vanilla World Map via a "Manage Areas" dashboard.
*   **Visual Drawing**: Draw rectangles directly on the map to define zones.
*   **Networking**: Real-time synchronization. Changes made by one admin are instantly visible to all other connected clients.
*   **Persistence**: Automatically saves areas and shapes to a server-specific data file (`AreaSystem_ServerName_Data.txt`), ensuring data persists across restarts and wipes.
*   **Customization**: organize zones by custom names and colors for easy identification (`Safezones`, `PVP Zones`, `Loot Areas`, etc.).

## Dependencies

*   **[KoniLib](../contents/mods/KoniLib/README.md)**: Required for networking and shared utilities.

## Usage Guide

1.  **Open the Manager**:
    *   Press `M` to open the World Map.
    *   Click the **"Manage Areas"** button in the top-right corner.

2.  **Create a Zone**:
    *   Click **"Create Area"** (or similar) in the manager window.
    *   Enter a Name and pick a Color.

3.  **Draw Shapes**:
    *   Select your area in the list.
    *   Check **"Drawing Mode"**.
    *   Click and drag on the map to create a rectangular defined area.
    *   You can create multiple shapes for a single Area.

4.  **Edit/Delete**:
    *   Click an Area to edit its name or color.
    *   Click shapes on the map to resize or move them (drag interactions).

## Technical Details

*   **Data Storage**:
    *   **Server**: `Zomboid/Lua/AreaSystem_ServerID_Data.txt`
    *   **Singleplayer**: `Zomboid/Saves/Sandbox/SaveName/AreaSystem_SaveName_Data.txt`
*   **Permissions**: Currently, the mod exposes UI to all users for testing. In a production environment, you may want to restrict the "Manage Areas" button to Admins only.
