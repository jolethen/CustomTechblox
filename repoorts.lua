-- report.lua
local storage = minetest.get_mod_storage()
local reports = minetest.deserialize(storage:get_string("reports")) or {}

-- save reports
local function save_reports()
    storage:set_string("reports", minetest.serialize(reports))
end

-- staff privilege
minetest.register_privilege("ra", {
    description = "Can manage and comment on player reports",
    give_to_singleplayer = false,
})

-- helper: check if player can access report
local function can_access_report(name, report)
    if report.author == name then
        return true
    end
    if minetest.check_player_privs(name, {ra = true}) then
        return true
    end
    return false
end

-- main report menu (staff only)
local function show_reports_menu(name)
    local formspec = "size[8,9]" ..
        "label[0,0;All Reports]" ..
        "button_exit[7,0;1,1;close;X]"

    local i = 0
    for id, report in pairs(reports) do
        if i < 10 then
            formspec = formspec ..
                "button[0,"..(1+i)..";6,1;view_"..id..";"..minetest.formspec_escape(report.title).." ("..report.status..")]"
            i = i + 1
        end
    end

    minetest.show_formspec(name, "reports:main", formspec)
end

-- author report menu
local function show_my_reports_menu(name)
    local formspec = "size[8,9]" ..
        "label[0,0;My Reports]" ..
        "button_exit[7,0;1,1;close;X]"

    local i = 0
    for id, report in pairs(reports) do
        if report.author == name then
            if i < 10 then
                formspec = formspec ..
                    "button[0,"..(1+i)..";6,1;view_"..id..";"..minetest.formspec_escape(report.title).." ("..report.status..")]"
                i = i + 1
            end
        end
    end

    minetest.show_formspec(name, "reports:my", formspec)
end

-- single report view
local function show_single_report(name, id)
    local report = reports[id]
    if not report then return end

    if not can_access_report(name, report) then
        minetest.chat_send_player(name, "You don't have access to this report.")
        return
    end

    local is_staff = minetest.check_player_privs(name, {ra = true})
    local is_author = (report.author == name)
    local comments = table.concat(report.comments, "\n")

    local formspec =
        "size[8,9]" ..
        "label[0,0;Report by "..report.author.."]" ..
        "textarea[0.2,0.5;7.5,2;;"..minetest.formspec_escape(report.text)..";]" ..
        "label[0,2.8;Status: "..report.status.."]" ..
        "textarea[0.2,3.3;7.5,2;comments;Comments;"..minetest.formspec_escape(comments).."]" ..
        "button_exit[6.5,8;1.5,1;back;Back]"

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

    minetest.show_formspec(name, "reports:view_"..id, formspec)
end

-- handle forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- staff reports list
    if formname == "reports:main" then
        for field in pairs(fields) do
            if field:sub(1,5) == "view_" then
                local id = tonumber(field:sub(6))
                show_single_report(name, id)
                return true
            end
        end
    end

    -- author report list
    if formname == "reports:my" then
        for field in pairs(fields) do
            if field:sub(1,5) == "view_" then
                local id = tonumber(field:sub(6))
                show_single_report(name, id)
                return true
            end
        end
    end

    -- single report
    if formname:sub(1,13) == "reports:view_" then
        local id = tonumber(formname:sub(14))
        local report = reports[id]
        if not report then return true end

        if fields.back then
            if minetest.check_player_privs(name, {ra = true}) then
                show_reports_menu(name)
            else
                show_my_reports_menu(name)
            end
            return true
        end

        if fields["close_"..id] and minetest.check_player_privs(name, {ra = true}) then
            report.status = "closed"
            save_reports()
            show_single_report(name, id)
            return true
        end

        if fields["open_"..id] and minetest.check_player_privs(name, {ra = true}) then
            report.status = "open"
            save_reports()
            show_single_report(name, id)
            return true
        end

        if fields["addc_"..id] and (minetest.check_player_privs(name, {ra = true}) or report.author == name) then
            if fields.add_comment and fields.add_comment ~= "" then
                table.insert(report.comments, name..": "..fields.add_comment)
                save_reports()
                show_single_report(name, id)
            end
            return true
        end
    end
end)

-- create report
minetest.register_chatcommand("report", {
    description = "Create a new report",
    func = function(name, param)
        if param == "" then
            return false, "Usage: /report <your issue>"
        end
        local id = #reports + 1
        reports[id] = {
            id = id,
            author = name,
            title = "Report #"..id,
            text = param,
            status = "open",
            comments = {}
        }
        save_reports()
        return true, "Report created with ID #"..id
    end
})

-- staff view all reports
minetest.register_chatcommand("reports", {
    description = "View all reports (staff only)",
    privs = {ra = true},
    func = function(name)
        show_reports_menu(name)
    end
})

-- author view their own reports
minetest.register_chatcommand("vr", {
    description = "View your reports",
    func = function(name)
        show_my_reports_menu(name)
    end
})
