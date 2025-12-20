-- ==========================================
-- RANDOM CHAT MESSAGES + PRIVATE JOIN MESSAGE
-- ==========================================

local storage = minetest.get_mod_storage()

-- Load stored data
local messages = minetest.deserialize(storage:get_string("random_msgs")) or {
    "Welcome to the server!",
    "Use /rules to read the rules.",
    "Use /guide to learn the server."
}

local interval = tonumber(storage:get_string("random_interval")) or 300

local join_message = storage:get_string("join_message")
if join_message == "" then
    join_message = "Welcome to the server!\nUse /rules and /guide to get started."
end

local timer = 0

-- Save helper
local function save_all()
    storage:set_string("random_msgs", minetest.serialize(messages))
    storage:set_string("random_interval", tostring(interval))
    storage:set_string("join_message", join_message)
end

-- Privilege
minetest.register_privilege("med", {
    description = "Can manage server messages",
    give_to_singleplayer = false
})

-- ==========================================
-- RANDOM CHAT BROADCAST
-- ==========================================
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer >= interval then
        timer = 0
        if #messages > 0 then
            local msg = messages[math.random(#messages)]
            minetest.chat_send_all("[Server] " .. msg)
        end
    end
end)

-- ==========================================
-- PRIVATE JOIN MESSAGE (PLAYER ONLY)
-- ==========================================
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    minetest.after(1, function()
        minetest.chat_send_player(name, "[Welcome]\n" .. join_message)
    end)
end)

-- ==========================================
-- EDITOR FORMSPEC
-- ==========================================
local function show_editor(name)
    minetest.show_formspec(name, "random_msgs:editor",
        "formspec_version[4]size[10,10]" ..
        "label[0.4,0.2;Random Chat Messages (one per line):]" ..
        "textarea[0.4,0.6;9.2,4.5;msgs;;" ..
            minetest.formspec_escape(table.concat(messages, "\n")) .. "]" ..

        "field[0.4,5.4;4,1;interval;Interval (seconds);" ..
            minetest.formspec_escape(tostring(interval)) .. "]" ..

        "label[0.4,6.3;Private Join Message (only the player sees this):]" ..
        "textarea[0.4,6.7;9.2,2.5;joinmsg;;" ..
            minetest.formspec_escape(join_message) .. "]" ..

        "button[2,9.4;2,1;save;Save]" ..
        "button_exit[6,9.4;2,1;cancel;Cancel]"
    )
end

-- ==========================================
-- HANDLE FORMSPEC
-- ==========================================
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "random_msgs:editor" then return end
    local name = player:get_player_name()

    if not minetest.check_player_privs(name, { med = true }) then
        return
    end

    if fields.save then
        -- Parse random messages
        messages = {}
        for line in (fields.msgs or ""):gmatch("[^\r\n]+") do
            table.insert(messages, line)
        end

        -- Interval (minimum 10s)
        local new_interval = tonumber(fields.interval)
        if new_interval and new_interval >= 10 then
            interval = new_interval
        end

        -- Join message
        join_message = fields.joinmsg or join_message

        save_all()
        minetest.chat_send_player(name, "Server messages updated.")
    end
end)

-- ==========================================
-- COMMAND
-- ==========================================
minetest.register_chatcommand("chatmsgs", {
    description = "Edit server random & join messages",
    privs = { med = true },
    func = function(name)
        show_editor(name)
    end
})
