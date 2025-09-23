-- =====================
-- RULES SYSTEM
-- =====================

local rules_path = minetest.get_worldpath() .. "/rules.txt"
local rules_text = "Default server rules.\n1) Be nice.\n2) No griefing.\n3) Respect staff."
local rules_version = 1
local seen_rules = {}

-- Load stored rules
local function load_rules()
    local f = io.open(rules_path, "r")
    if f then
        local data = minetest.deserialize(f:read("*all"))
        f:close()
        if type(data) == "table" then
            rules_text = data.text or rules_text
            rules_version = data.version or 1
        end
    end
end

-- Save rules
local function save_rules()
    local f = io.open(rules_path, "w")
    if f then
        f:write(minetest.serialize({ text = rules_text, version = rules_version }))
        f:close()
    end
end

load_rules()

-- Priv
minetest.register_privilege("rulemkr", {
    description = "Can edit the rules",
    give_to_admin = true
})

-- /rules command
minetest.register_chatcommand("rules", {
    description = "Show server rules",
    func = function(name)
        minetest.show_formspec(name, "server_tools:rules",
            "formspec_version[4]size[10,8]" ..
            "textarea[0.5,0.5;9,6;rules;Server Rules;" .. minetest.formspec_escape(rules_text) .. "]" ..
            "button_exit[4,7;2,1;done;Done]")
    end
})

-- /frul (force rules update)
minetest.register_chatcommand("frul", {
    privs = { rulemkr = true },
    description = "Force rules update (all players see popup next login)",
    func = function(name)
        rules_version = rules_version + 1
        save_rules()
        minetest.chat_send_all("Rules got updated! Everyone must review them again.")
        return true, "Rules update forced."
    end
})

-- Auto popup on first join or when updated
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    if seen_rules[name] ~= rules_version then
        minetest.after(1, function()
            minetest.show_formspec(name, "server_tools:rules",
                "formspec_version[4]size[10,8]" ..
                "textarea[0.5,0.5;9,6;rules;Server Rules;" .. minetest.formspec_escape(rules_text) .. "]" ..
                "button_exit[4,7;2,1;done;Done]")
            seen_rules[name] = rules_version
        end)
    end
end)
