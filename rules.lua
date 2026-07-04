-- =====================
-- RULES SYSTEM (FIXED)
-- =====================

local rules_text = "Default server rules.\n" ..
"1) Respect Everyone: Treat all players with respect. Harassment, hate speech, discrimination, or personal attacks will not be tolerated.\n" ..
"2) Keep It Appropriate: Mild swearing is allowed. However, sexual, racist, discriminatory, or excessively offensive language or content is strictly prohibited.\n" ..
"3) No Spamming: Avoid flooding the chat with repeated messages, excessive emojis, unnecessary caps, or any form of spam.\n" ..
"4) No Unauthorized Advertising: Do not advertise or promote your own servers, social media, YouTube channels, or other content without staff permission.\n" ..
"5) No Trolling or Harassment: Do not intentionally provoke, bully, threaten, or harass other players.\n" ..
"6) No Hacking, Cheating, or Exploiting: Using hacked clients, cheats, exploits, bugs, or any unfair advantage is strictly prohibited and may result in a permanent ban.\n" ..
"7) Protect Privacy: Do not share your own or anyone else's personal information, including passwords, phone numbers, addresses, or private accounts.\n" ..
"8) Use Common Sense: If something is clearly inappropriate, offensive, or disruptive, don't do it.\n" ..
"9) Follow Discord's Terms of Service: All players must follow Discord's Terms of Service and Community Guidelines.\n" ..
"10) No Inappropriate Content: Sexual, racist, hateful, or otherwise inappropriate builds, usernames, skins, or content are not allowed.\n" ..
"11) Respect Staff Decisions: Respect the decisions made by moderators and administrators. If you disagree with a punishment, use the proper appeal or ticket system instead of arguing in chat.\n" ..
"12) No False Reports: Do not submit false reports against players or staff members. False reports waste staff time and can unfairly damage someone's reputation. Intentionally making false accusations may result in disciplinary action.\n" ..
"13) Fair PvP: Do not kill players who have played for less than 30 minutes. However, this protection is immediately removed if a player attacks another player or creates/joins a guild. Once they engage in PvP or become part of a guild, they are considered fair targets.\n" ..
"14) No Spam Killing: Bone camping and stealing items from a player's bone are allowed. However, repeatedly killing the same player more than 8 times without allowing them to continue playing is considered spam killing and is not allowed.\n" ..
"15) Griefing: Griefing unprotected areas is allowed. However, griefing protected areas or attempting to bypass protections (including lava griefing, water griefing, or similar methods) is strictly prohibited.\n" ..
"16) No Event Interference: Do not kill, attack, or interfere with players who are actively participating in an official server event unless the event explicitly allows PvP. Event participants are protected for the duration of the event.\n" ..
"17) Direct Messages (DMs): Swearing in private Discord DMs does not count as a server rule violation. However, harassment, threats, scams, or any behavior that violates Discord's Terms of Service may still result in staff action if it impacts the TechBlox community.\n" ..
"18) Have Fun!: Enjoy your adventure, respect the community, and help make TechBlox a fun place for everyone."

local rules_version = 1
local seen_rules = {}

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
