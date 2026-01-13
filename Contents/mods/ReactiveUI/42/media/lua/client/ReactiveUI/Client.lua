--[[
    ReactiveUI Client Entry Point
    
    Loads all ReactiveUI modules and provides the main API for client-side usage.
]]

require "ReactiveUI/Definitions"
require "ReactiveUI/State"
require "ReactiveUI/Utils"
require "ReactiveUI/Component"
require "ReactiveUI/Elements"
require "ReactiveUI/Layout"

-- Log initialization
KoniLib.Log.Print("ReactiveUI", "ReactiveUI v" .. ReactiveUI.Version .. " loaded")
