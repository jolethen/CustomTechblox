minetest.register_chatcommand("online", {
    description = "Show list of online players",
    func = function(name)
        local players = minetest.get_connected_players()
        if #players == 0 then
            return true, "No players are online."
        end

        local names = {}
        for _, player in ipairs(players) do
            table.insert(names, player:get_player_name())
        end

        return true, "Online players (" .. #names .. "): " .. table.concat(names, ", ")
    end,
})
