-- =====================
-- RULES SYSTEM (FIXED)
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

local function save_rules()
    local f = io.open(rules_path, "w")
    if f then
        f:write(minetest.serialize({ text = rules_text, version = rules_version }))
        f:close()
    end
end

load_rules()

minetest.register_privilege("rulemkr", {
    description = "Can edit the rules",
    give_to_admin = true
})

-- /rules
minetest.register_chatcommand("rules", {
    description = "Show server rules",
    func = function(name)
        minetest.show_formspec(name, "server_tools:rules",
            "formspec_version[4]size[10,8]" ..
            "textarea[0.5,0.5;9,6;rules;Server Rules;" ..
                minetest.formspec_escape(rules_text) .. "]" ..
            "button[4,7;2,1;done;Done]"
        )
    end
})

-- /frul
minetest.register_chatcommand("frul", {
    privs = { rulemkr = true },
    description = "Force rules update",
    func = function(name)
        rules_version = rules_version + 1
        save_rules()
        minetest.chat_send_all("Rules got updated! Everyone must review them again.")
        return true, "Rules update forced."
    end
})

-- Auto popup
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    -- Only show if not yet accepted
    if seen_rules[name] ~= rules_version then
        minetest.after(1, function()
            minetest.show_formspec(name, "server_tools:rules",
                "formspec_version[4]size[10,8]" ..
                "textarea[0.5,0.5;9,6;rules;Server Rules;" ..
                    minetest.formspec_escape(rules_text) .. "]" ..
                "button[4,7;2,1;done;Done]"
            )
        end)
    end
end)

-- Handle close → mark “seen” → open changelog
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "server_tools:rules" then return end
    local name = player:get_player_name()

    if fields.done then

        -- Mark rules as seen NOW
        seen_rules[name] = rules_version

        -- Close window
        minetest.close_formspec(name, "server_tools:rules")

        -- Open changelog (if global function exists)
        minetest.after(0.15, function()
            if type(show_changelog) == "function" then
                pcall(function()
                    show_changelog(name, 1)
                end)
            end
        end)
    end
end)
