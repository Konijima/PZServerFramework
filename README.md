# PZServerFramework

A collection of Project Zomboid Mods and Frameworks designed for server management, custom areas, and shared library utilities.

## Contents

### 1. KoniLib
A shared library mod serving as the foundation for other mods in this suite.
*   **Networking Abstraction:** Unified `MP` class for handling Client/Server communication transparently across Singleplayer, Hosted, and Dedicated Server environments.
*   **Project Structure:** Standardized shared Lua code structure.

### 2. AreaSystem
An admin tool and system for creating, managing, and visualizing custom areas within the game world.
*   **UI Tools:** In-game editors for Areas and Shapes (Rectangles, etc.).
*   **Map Integration:** Visualizes created areas directly on the game map.
*   **Extensible:** Built on top of KoniLib for robust networking.

## Installation

1.  Copy the `Contents/mods/` folders into your Project Zomboid `mods` directory (or Workshop content folder).
2.  Ensure `KoniLib` is enabled whenever using `AreaSystem`.
