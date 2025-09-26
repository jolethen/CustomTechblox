-- report.lua
-- Simple persistent report system with open/close

local reports = {}
local report_file = minetest.get_worldpath() .. "/reports.json"

-- Load reports from file
local function load_reports()
    local f = io.open(report_file, "r")
    if not f then
        reports = {}
        return
    end
    local content = f:read("*all")
    f:close()

    local ok, data = pcall(minetest.parse_json, content)
    if ok and type(data) == "table" then
        reports = data
    else
        minetest.log("error", "[reports] Failed to parse reports.json, starting fresh.")
        reports = {}
    end
end

-- Save reports to file
local function save_reports()
    local f, err = io.open(report_file, "w")
    if not f then
        minetest.log("error", "[reports] Failed to save reports: " .. tostring(err))
        return
    end
    f:write(minetest.write_json(reports, true))
    f:close()
end

load_reports()

-- Register staff privilege
minetest.register_privilege("ra", {
    description = "Access and manage player reports",
    give_to_singleplayer = true,
})

-- Helpers
local function can_access_report(name, report)
    return report.author == name or minetest.check_player_privs(name, {ra = true})
end

-- GUIs
local function show_reports_menu(name)
    local formspec = "size[8,9]label[0,0;All Reports]"
    local y = 0.5
    for id, r in pairs(reports) do
        if r.status == "open" then
            formspec = formspec ..
                "button[0,"..y..";7.5,0.7;view:staff:"..id..";"..minetest.formspec_escape(r.author.." - "..r.title).."]"
            y = y + 0.8
        end
    end
    minetest.show_formspec(name, "reports:main", formspec)
end

local function show_my_reports_menu(name)
    local formspec = "size[8,9]label[0,0;My Reports]"
    local y = 0.5
    for id, r in pairs(reports) do
        if r.author == name and r.status == "open" then
            formspec = formspec ..
                "button[0,"..y..";7.5,0.7;view:author:"..id..";"..minetest.formspec_escape(r.title).."]"
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

    local formspec =
        "size[8,6]" ..
        "label[0,0;Report by "..minetest.formspec_escape(report.author).."]" ..
        "textarea[0.2,0.5;7.5,3;;"..minetest.formspec_escape(report.text)..";]" ..
        "button_exit[6.2,5;2,1;back:"..context..";Back]"

    if is_staff then
        formspec = formspec .. "button[0,5;2,1;close:"..id..";Close]"
    end

    minetest.show_formspec(name, "reports:view:"..context..":"..id, formspec)
end

-- Handle forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- Staff list
    if formname == "reports:main" then
        for field in pairs(fields) do
            local context, id = field:match("^view:(staff):(%d+)$")
            if context and id then
                show_single_report(name, tonumber(id), context)
                return true
            end
        end
    end

    -- Author list
    if formname == "reports:my" then
        for field in pairs(fields) do
            local context, id = field:match("^view:(author):(%d+)$")
            if context and id then
                show_single_report(name, tonumber(id), context)
                return true
            end
        end
    end

    -- Viewing single report
    local context, id = formname:match("^reports:view:([^:]+):(%d+)$")
    if context and id then
        id = tonumber(id)
        local report = reports[id]
        if not report then return true end

        if fields["back:"..context] then
            if context == "staff" then
                show_reports_menu(name)
            else
                show_my_reports_menu(name)
            end
            return true
        end

        if fields["close:"..id] and minetest.check_player_privs(name, {ra = true}) then
            report.status = "closed"
            save_reports()
            if context == "staff" then
                show_reports_menu(name)
            else
                show_my_reports_menu(name)
            end
            return true
        end
    end

    -- New report form
    if formname == "reports:new" then
        if fields.submit_report and fields.report_text and fields.report_text ~= "" then
            local new_id = #reports + 1
            reports[new_id] = {
                author = name,
                title = fields.report_title ~= "" and fields.report_title or ("Report #" .. new_id),
                text = fields.report_text,
                status = "open"
            }
            save_reports()
            minetest.chat_send_player(name, "✅ Report submitted with ID "..new_id)
        end
        return true
    end
end)

-- Commands
minetest.register_chatcommand("report", {
    description = "File a report",
    func = function(name)
        local formspec =
            "size[8,6]" ..
            "field[0.5,1;7,1;report_title;Title;]" ..
            "textarea[0.5,2.5;7,3;report_text;Describe your issue;]" ..
            "button_exit[3,5.5;2,1;submit_report;Submit]"
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
