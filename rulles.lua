-- rules.lua
-- Rules system for custom_commands mod

local rules_text = [[
__  RULES __

1. Respect others: Treat all members with respect, even if you disagree with their opinions. Harassment, hate speech, and discriminatory language will not be tolerated.
2. Keep it PG-13: Avoid sharing NSFW content and keep the language clean to ensure a safe and inclusive environment for everyone.
3. No spamming: Do not flood the chat with repetitive messages, emojis, or excessive use of caps lock. This can disrupt the flow of conversation and make it difficult for others to participate.
4. No self-promotion: Avoid promoting personal content or products without permission from the server owner or moderators. This includes advertising your own social media, YouTube channel, or Discord server.
5. No trolling, discrimination, or harassment: Do not engage in any behavior that is meant to provoke or harass others.
6. No hacking, cheating, and raiding: We take cheating, exploiting, and hacking very seriously on our server, and any attempt to do so will result in a permanent ban.
7. No sharing personal information: Do not share personal information about yourself if you don't want to and don't share personal information about others or, such as phone numbers, addresses, or passwords.
8. Use common sense, if you know something won't be tolerated here don't say anything within its topic, such as gore.
9. Follow Multicraft’s, Minetests, and T.O.S & community guidelines.
10. No Griefing, this includes protection grief, building, and water griefing. 
11. Don’t make any NSFW or inappropriate builds or content.
12. Respect everyone’s opinion, decisions, and actions. If they don’t follow the rules or isn’t appropriate, make a report/appeal/ticket. 
13. No killing NOOBS (players who have just played for less than 1 hr.) and no killing UNGEARED players. Make all fights fair.
14. No spam killing, or bone camping.
15. HAVE FUN!
]]

minetest.register_privilege("rulemkr", {
    description = "Can edit rules",
    give_to_singleplayer = false,
})

local rules_file = minetest.get_worldpath() .. "/rules.txt"

-- Load rules
local function load_rules()
    local f = io.open(rules_file, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content ~= "" then
            rules_text = content
        end
    end
end

-- Save rules
local function save_rules()
    local f = io.open(rules_file, "w")
    if f then
        f:write(rules_text)
        f:close()
    end
end

-- Show rules formspec
local function show_rules(name, editable)
    local formspec = {
        "formspec_version[4]",
        "size[10,8]",
        "textarea[0.3,0.3;9.5,6.5;rules;Server Rules;" .. minetest.formspec_escape(rules_text) .. "]",
        "button_exit[4,7.2;2,0.8;done;Done]"
    }
    if editable then
        formspec[#formspec+1] = "button[7.8,7.2;2,0.8;edit;Edit]"
    end
    minetest.show_formspec(name, "rules:main", table.concat(formspec))
end

-- Commands
minetest.register_chatcommand("rules", {
    description = "View the server rules",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return end
        local privs = minetest.get_player_privs(name)
        show_rules(name, privs.rulemkr)
    end,
})

-- Handle formspec
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "rules:main" then return end
    local name = player:get_player_name()
    local privs = minetest.get_player_privs(name)

    if fields.edit and privs.rulemkr then
        minetest.show_formspec(name, "rules:edit",
            "formspec_version[4]" ..
            "size[10,8]" ..
            "textarea[0.3,0.3;9.5,6.5;edit_rules;Edit Rules;" ..
            minetest.formspec_escape(rules_text) .. "]" ..
            "button_exit[4,7.2;2,0.8;save;Save]")
    end

    if fields.save and privs.rulemkr then
        local fs = minetest.get_player_by_name(name)
        if fs then
            rules_text = fields.edit_rules or rules_text
            save_rules()
            minetest.chat_send_player(name, "Rules updated!")
        end
    end
end)

-- Auto open on first join
local joined = {}
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    if not joined[name] then
        joined[name] = true
        minetest.after(2, function()
            if player and player:is_player() then
                show_rules(name, false)
            end
        end)
    end
end)

-- Load saved rules on startup
load_rules()
