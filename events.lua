-- =====================
-- EVENTS SYSTEM
-- =====================

local events_text = "No events right now."

minetest.register_privilege("eved", {
    description = "Can edit events",
    give_to_admin = true
})

-- /events
minetest.register_chatcommand("events", {
    description = "Show server events",
    func = function(name)
        minetest.show_formspec(name, "server_tools:events",
            "formspec_version[4]size[10,6]" ..
            "textarea[0.5,0.5;9,4;ev;Server Events;" .. minetest.formspec_escape(events_text) .. "]" ..
            "button_exit[4,5;2,1;done;Done]")
    end
})

-- /editevents <text>
minetest.register_chatcommand("editevents", {
    privs = { eved = true },
    params = "<text>",
    description = "Edit events text",
    func = function(name, param)
        if param == "" then return false, "Usage: /editevents <text>" end
        events_text = param
        return true, "Events updated."
    end
})
