-- report.lua

-- Set your teleport location here
local REPORT_COORDS = {x = 100, y = 10, z = 100}

minetest.register_chatcommand("report", {
    description = "Teleport to the report center",
    privs = {}, -- everyone can use
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            player:set_pos(REPORT_COORDS)
            return true, "You have been teleported to the report center!"
        end
        return false, "Player not found."
    end,
})
