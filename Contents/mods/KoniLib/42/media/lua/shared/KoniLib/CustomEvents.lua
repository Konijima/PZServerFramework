if not KoniLib then KoniLib = {} end

-- Use the Event wrapper to register globally
local Event = require("KoniLib/Event")

KoniLib.Events = KoniLib.Events or {}

-- Registers "OnNetworkAvailable"
KoniLib.Events.OnNetworkAvailable = Event.new("OnNetworkAvailable")

-- Registers "OnPlayerInit"
-- Arguments: playerIndex (int), player (IsoPlayer), isRespawn (boolean)
KoniLib.Events.OnPlayerInit = Event.new("OnPlayerInit")

-- Registers "OnRemotePlayerInit"
-- Arguments: username (string), isRespawn (boolean)
KoniLib.Events.OnRemotePlayerInit = Event.new("OnRemotePlayerInit")

-- Reuse Vanilla "OnPlayerDeath" for consistency/wrapper usage
-- Arguments: player (IsoPlayer)
KoniLib.Events.OnPlayerDeath = Event.new("OnPlayerDeath")

-- Registers "OnRemotePlayerDeath"
-- Arguments: username (string), x (float), y (float), z (float)
KoniLib.Events.OnRemotePlayerDeath = Event.new("OnRemotePlayerDeath")

-- Registers "OnPlayerQuit" (Server Side Detection)
-- Arguments: username (string)
KoniLib.Events.OnPlayerQuit = Event.new("OnPlayerQuit")

-- Registers "OnRemotePlayerQuit" (Client Side Notification)
-- Arguments: username (string)
KoniLib.Events.OnRemotePlayerQuit = Event.new("OnRemotePlayerQuit")

-- Registers "OnAccessLevelChanged" (Client Side Detection)
-- Triggered when the local player's access level changes (e.g., promoted to moderator/admin)
-- Arguments: newAccessLevel (string), oldAccessLevel (string|nil)
KoniLib.Events.OnAccessLevelChanged = Event.new("OnAccessLevelChanged")
