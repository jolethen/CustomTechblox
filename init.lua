local modpath = minetest.get_modpath(minetest.get_current_modname())

-- Load each command/system
dofile(modpath .. "/rules.lua")
dofile(modpath .. "/repoorts.lua")
dofile(modpath .. "/guuide.lua")
dofile(modpath .. "/events.lua")
