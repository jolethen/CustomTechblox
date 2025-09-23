local modpath = minetest.get_modpath(minetest.get_current_modname())

-- Load each command/system
dofile(modpath .. "/commands/rules.lua")
dofile(modpath .. "/commands/reports.lua")
dofile(modpath .. "/commands/guide.lua")
dofile(modpath .. "/commands/events.lua")
