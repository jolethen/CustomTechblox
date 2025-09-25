-- report.lua : interactive report system with persistence

local reports = {}
local report_file = minetest.get_worldpath().."/reports.json"

-- Load / Save
local function load_reports()
    local f = io.open(report_file, "r")
    if not f then return end
    local data = minetest.parse_json(f:read("*all"))
    f:close()
    if type(data) == "table" then reports = data end
end

local function save_reports()
    local f = io.open(report_file, "w")
    if not f then return end
    f:write(minetest.write_json(reports, true))
    f:close()
end

load_reports()

-- Privs
minetest.register_privilege("ra", {
    description = "Access and manage reports",
    give_to_singleplayer = false
})

-- Helpers
local function safe_tonumber(str)
    local n = tonumber(str)
    if not n then return nil end
    if not reports[n] then return nil end
    return n
end

local function can_access_report(name, report)
    return report.author == name or minetest.check_player_privs(name, {ra = true})
end

-- GUI
local function show_reports_menu(name)
    local formspec = "size[8,9]label[0,0;All Reports]"
    local y = 0.5
    for id, r in pairs(reports) do
        if minetest.check_player_privs(name, {ra = true}) then
            formspec = formspec ..
                "button[0,"..y..";7.5,0.7;view_staff_"..id..";"..minetest.formspec_escape(r.author.." - "..r.status).."]"
            y = y + 0.8
        end
    end
    minetest.show_formspec(name, "reports:main", formspec)
end

local function show_my_reports_menu(name)
    local formspec = "size[8,9]label[0,0;My Reports]"
    local y = 0.5
    for id, r in pairs(reports) do
        if r.author == name then
            formspec = formspec ..
                "button[0,"..y..";7.5,0.7;view_author_"..id..";"..minetest.formspec_escape(r.status).."]"
            y = y + 0.8
        end
    end
    minetest.show_formspec(name, "reports:my", formspec)
end

local function show_single_report(name, id, context)
    local report = reports[id]
    if not report then
        minetest.chat_send_player(name, "⚠ Report not found (ID "..tostring(id)..")")
        return
    end
    if not can_access_report(name, report) then
        minetest.chat_send_player(name, "You don't have access to this report.")
        return
    end

    local is_staff = minetest.check_player_privs(name, {ra = true})
    local is_author = (report.author == name)
    local comments = table.concat(report.comments or {}, "\n")

    local formspec =
        "size[8,9]" ..
        "label[0,0;Report by "..minetest.formspec_escape(report.author).."]" ..
        "textarea[0.2,0.5;7.5,2;;"..minetest.formspec_escape(report.text)..";]" ..
        "label[0,2.8;Status: "..report.status.."]" ..
        "textarea[0.2,3.3;7.5,2;comments;Comments;"..minetest.formspec_escape(comments).."]" ..
        "button_exit[6.5,8;1.5,1;back_"..context..";Back]"

    if is_staff then
        if report.status == "open" then
            formspec = formspec .. "button[0,8;2,1;close_"..id..";Close]"
        else
            formspec = formspec .. "button[0,8;2,1;open_"..id..";Reopen]"
        end
    end

    if is_staff or is_author then
        formspec = formspec ..
            "field[0.3,6.5;6,1;add_comment;Add comment;]" ..
            "button[6,6.2;2,1;addc_"..id..";Add]"
    end

    minetest.show_formspec(name, "reports:view_"..context.."_"..id, formspec)
end

-- Fields
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    if formname == "reports:main" then
        for field in pairs(fields) do
            if field:sub(1,11) == "view_staff_" then
                local id = safe_tonumber(field:sub(12))
                if id then show_single_report(name, id, "staff") end
                return true
            end
        end
    end

    if formname == "reports:my" then
        for field in pairs(fields) do
            if field:sub(1,12) == "view_author_" then
                local id = safe_tonumber(field:sub(13))
                if id then show_single_report(name, id, "author") end
                return true
            end
        end
    end

    if formname:sub(1,14) == "reports:view_" then
        local parts = {}
        for part in formname:gmatch("[^_]+") do table.insert(parts, part) end
        local context = parts[3]
        local id = safe_tonumber(parts[4])
        if not id then return true end
        local report = reports[id]
        if not report then return true end

        if fields["back_"..context] then
            if context == "staff" then
                show_reports_menu(name)
            else
                show_my_reports_menu(name)
            end
            return true
        end

        if fields["close_"..id] and minetest.check_player_privs(name, {ra = true}) then
            report.status = "closed"
            save_reports()
            show_single_report(name, id, context)
            return true
        end

        if fields["open_"..id] and minetest.check_player_privs(name, {ra = true}) then
            report.status = "open"
            save_reports()
            show_single_report(name, id, context)
            return true
        end

        if fields["addc_"..id] and (minetest.check_player_privs(name, {ra = true}) or report.author == name) then
            if fields.add_comment and fields.add_comment ~= "" then
                report.comments = report.comments or {}
                table.insert(report.comments, name..": "..fields.add_comment)
                save_reports()
                show_single_report(name, id, context)
            end
            return true
        end
    end
end)

-- Commands
minetest.register_chatcommand("report", {
    description = "File a report",
    func = function(name)
        local formspec =
            "size[8,6]" ..
            "field[0.5,1;7,1;report_text;Enter your report;]" ..
            "button_exit[3,3;2,1;submit_report;Submit]"
        minetest.show_formspec(name, "reports:new", formspec)
    end
})

minetest.register_chatcommand("ra", {
    description = "View all reports (staff only)",
    privs = {ra = true},
    func = function(name)
        show_reports_menu(name)
    end
})

minetest.register_chatcommand("vr", {
    description = "View my reports",
    func = function(name)
        show_my_reports_menu(name)
    end
})

-- Handle new reports
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "reports:new" and fields.submit_report and fields.report_text and fields.report_text ~= "" then
        local name = player:get_player_name()
        local new_id = #reports + 1
        reports[new_id] = {
            author = name,
            text = fields.report_text,
            status = "open",
            comments = {}
        }
        save_reports()
        minetest.chat_send_player(name, "✅ Report submitted with ID "..new_id)
    end
end)
