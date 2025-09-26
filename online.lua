-- Safe /online command
minetest.register_chatcommand("online", {
    description = "Shows all online players safely",
    func = function(name)
        local ok, err = pcall(function()
            local players = minetest.get_connected_players()
            if not players or #players == 0 then
                return minetest.chat_send_player(name, "No players are currently online.")
            end

            local player_names = {}
            for _, player in ipairs(players) do
                local pname = player:get_player_name()
                if pname then
                    table.insert(player_names, pname)
                end
            end

            local message = "Online players (" .. #player_names .. "): " .. table.concat(player_names, ", ")
            minetest.chat_send_player(name, message)
        end)

        if not ok then
            minetest.chat_send_player(name, "Error fetching online players: " .. tostring(err))
        end

        return true
    end,
})
