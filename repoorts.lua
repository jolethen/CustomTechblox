-- report.lua
local storage = minetest.get_mod_storage()
local reports = minetest.deserialize(storage:get_string("reports")) or {}

local function save_reports()
    storage:set_string("reports", minetest.serialize(reports))
end

-- Show report list
local function show_report_list(playername, for_staff)
    local entries = {}
    for i, r in ipairs(reports) do
        if for_staff or r.author == playername then
            table.insert(entries, i .. ". " .. r.title .. " [" .. r.status .. "] by " .. r.author)
        end
    end
    if #entries == 0 then
        table.insert(entries, "<no reports>")
    end

    local formspec =
        "formspec_version[4]size[12,8]" ..
        "label[0.5,0.5;Reports]" ..
        "textlist[0.5,1;11,6;report_list;" .. table.concat(entries, ",") .. ";0]" ..
        "button[5,7;2,1;new;New Report]"

    minetest.show_formspec(playername, "custom_commands:report_list", formspec)
end

-- Show single report
local function show_report(playername, idx)
    local report = reports[idx]
    if not report then return end

    local comments_text = ""
    for _, c in ipairs(report.comments or {}) do
        comments_text = comments_text .. c.author .. ": " .. c.text .. "\\n"
    end

    local formspec =
        "formspec_version[4]size[12,9]" ..
        "label[0.5,0.5;Report #" .. idx .. " - " .. report.title .. " (" .. report.status .. ")]" ..
        "textarea[0.5,1;11,4;;;" .. minetest.formspec_escape(report.content) .. "]" ..
        "label[0.5,5;Comments:]" ..
        "textarea[0.5,5.5;11,2;;;" .. minetest.formspec_escape(comments_text) .. "]" ..
        "field[0.5,7.8;8,1;comment;Add comment;]" ..
        "button[8.8,7.6;2,1;add_comment;Add]" ..
        "button[0.5,8.6;2,1;back;Back]"

    if minetest.check_player_privs(playername, {report = true}) then
        formspec = formspec .. "button[3,8.6;2,1;close;Close]"
    end

    minetest.show_formspec(playername, "custom_commands:report_view_" .. idx, formspec)
end

-- Show new report form
local function show_new_report(playername)
    local formspec =
        "formspec_version[4]size[10,7]" ..
        "label[0.5,0.5;New Report]" ..
        "field[0.5,1.5;9,1;title;Title;]" ..
        "textarea[0.5,2.5;9,3;content;Content;]" ..
        "button[3.5,6;3,1;submit;Submit]"

    minetest.show_formspec(playername, "custom_commands:new_report", formspec)
end

-- Handle formspecs
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- Report list
    if formname == "custom_commands:report_list" then
        if fields.new then
            show_new_report(name)
            return
        end
        if fields.report_list then
            local event = minetest.explode_textlist_event(fields.report_list)
            if event.type == "DCL" then
                local idx = tonumber(event.index)
                show_report(name, idx)
            end
        end
    end

    -- New report
    if formname == "custom_commands:new_report" then
        if fields.submit and fields.title and fields.content then
            table.insert(reports, {
                author = name,
                title = fields.title,
                content = fields.content,
                comments = {},
                status = "open",
            })
            save_reports()
            minetest.chat_send_player(name, "Report submitted!")
            show_report_list(name, minetest.check_player_privs(name, {report = true}))
        end
    end

    -- Report view
    if formname:find("custom_commands:report_view_") == 1 then
        local idx = tonumber(formname:match("_(%d+)$"))
        local report = reports[idx]
        if not report then return end

        if fields.back then
            show_report_list(name, minetest.check_player_privs(name, {report = true}))
            return
        end
        if fields.add_comment and fields.comment and fields.comment ~= "" then
            table.insert(report.comments, {author = name, text = fields.comment})
            save_reports()
            show_report(name, idx)
            return
        end
        if fields.close and minetest.check_player_privs(name, {report = true}) then
            report.status = "closed"
            save_reports()
            show_report(name, idx)
            return
        end
    end
end)

-- Commands
minetest.register_chatcommand("report", {
    description = "File a new report",
    func = function(name)
        show_new_report(name)
    end,
})

minetest.register_chatcommand("reports", {
    description = "View reports",
    func = function(name)
        local is_staff = minetest.check_player_privs(name, {report = true})
        show_report_list(name, is_staff)
    end,
})

-- Privilege for staff
minetest.register_privilege("report", {
    description = "Can view and manage all reports",
    give_to_singleplayer = false,
})
