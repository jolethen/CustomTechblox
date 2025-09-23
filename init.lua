local modpath = minetest.get_modpath(minetest.get_current_modname())

-- Load each command/system
dofile(modpath .. "/rules.lua")
dofile(modpath .. "/reports.lua")
dofile(modpath .. "/guide.lua")
dofile(modpath .. "/events.lua")
