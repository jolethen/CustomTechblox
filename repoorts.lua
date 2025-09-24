-- server_tools/reports.lua
-- Persistent report system for server_tools mod

local reports = {}
local report_id_counter = 0
local report_file = minetest.get_worldpath().."/reports.txt"

-- Privilege for staff
minetest.register_privilege("repc", {
    description = "Can view, comment, close, and filter reports",
    give_to_singleplayer = false,
})

-- Load reports from file
local function load_reports()
    local f = io.open(report_file, "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content ~= "" then
            local ok, data = pcall(minetest.deserialize, content)
            if ok and data then
                reports = data
                for id,_ in pairs(reports) do
                    if id > report_id_counter then
                        report_id_counter = id
                    end
                end
            end
        end
    end
end

-- Save reports to file
local function save_reports()
    local f = io.open(report_file, "w")
    if f then
        f:write(minetest.serialize(reports))
        f:close()
    end
end

load_reports()

-- Show main menu
local function show_report_menu(player)
    local name = player:get_player_name()
    local formspec = "size[8,9]" ..
                     "label[0,0;Report System]" ..
                     "button[0,0.5;2,1;new_report;New Report]" ..
                     "button[2,0.5;2,1;view_my_reports;My Reports]"
    if minetest.get_player_privs(name).repc then
        formspec = formspec .. "button[4,0.5;2,1;view_all_reports;All Reports 🔐]"
    end
    minetest.show_formspec(name, "server_tools:report_menu", formspec)
end

-- Show new report form
local function show_new_report(player)
    local formspec = "size[8,5]" ..
                     "field[0.5,1;7,1;report_title;Title;]" ..
                     "textarea[0.5,2;7,2;report_text;Description;]" ..
                     "button[3,4;2,1;submit_report;Submit]" ..
                     "button_exit[0,4;2,1;cancel;Cancel]"
    minetest.show_formspec(player:get_player_name(), "server_tools:new_report", formspec)
end

-- List reports with optional filter (fixed to prevent crash)
local function show_report_list(player, list, title)
    local name = player:get_player_name()
    local formspec = "size[8,9]" ..
                     "label[0,0;"..title.."]" ..
                     "field[0,0.5;5,1;filter_author;Filter by author;]" ..
                     "dropdown[5,0.5;3,1;filter_status;All,Open,Closed;1]" ..
                     "button[0,1;2,1;apply_filter;Apply Filter]"
    local y = 1.7

    -- Convert to array and sort by ID to prevent crashes
    local sorted_reports = {}
    for _, r in pairs(list) do
        table.insert(sorted_reports, r)
    end
    table.sort(sorted_reports, function(a, b) return a.id < b.id end)

    for _, report in ipairs(sorted_reports) do
        local status = report.closed and " [Closed]" or " [Open]"
        formspec = formspec .. "button[0,"..y..";8,1;view_report_"..report.id..";"..report.title.." by "..report.author..status.."]"
        y = y + 1.2
    end

    formspec = formspec .. "button_exit[0,"..y..";2,1;close;Close]"
    minetest.show_formspec(name, "server_tools:report_list", formspec)
end

-- Show single report
local function show_report(player, report)
    local name = player:get_player_name()
    local formspec = "size[8,9]" ..
                     "label[0,0;Title: "..report.title.."]" ..
                     "textarea[0.5,1;7,5;report_content;Description;"..report.text.."]" ..
                     "label[0,6;Comments:]"
    local y = 6.5
    for _, comment in ipairs(report.comments or {}) do
        formspec = formspec .. "label[0,"..y..";"..comment.author..": "..comment.text.."]"
        y = y + 0.5
    end
    if minetest.get_player_privs(name).repc then
        formspec = formspec ..
                   "field[0.5,"..y..";7,1;new_comment;Add Comment;]" ..
                   "button[3,"..(y+1)..";2,1;submit_comment;Submit]"
        if not report.closed then
            formspec = formspec .. "button[5,"..(y+1)..";2,1;close_report;Close Report 🔒]"
        end
    end
    formspec = formspec .. "button_exit[0,"..(y+2)..";2,1;exit;Exit]"
    minetest.show_formspec(name, "server_tools:view_report_"..report.id, formspec)
end

-- Chat command to open report menu from server_tools
minetest.register_chatcommand("reports", {
    description = "Open the server_tools report menu",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then show_report_menu(player) end
    end
})

-- Forms handler
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    if formname == "server_tools:report_menu" then
        if fields.new_report then show_new_report(player)
        elseif fields.view_my_reports then
            local my_reports = {}
            for _, r in pairs(reports) do
                if r.author == name then table.insert(my_reports, r) end
            end
            show_report_list(player, my_reports, "My Reports")
        elseif fields.view_all_reports and minetest.get_player_privs(name).repc then
            local all_reports = {}
            for _, r in pairs(reports) do table.insert(all_reports, r) end
            show_report_list(player, all_reports, "All Reports 🔐")
        end

    elseif formname == "server_tools:new_report" then
        if fields.submit_report and fields.report_title and fields.report_text ~= "" then
            report_id_counter = report_id_counter + 1
            reports[report_id_counter] = {
                id = report_id_counter,
                author = name,
                title = fields.report_title,
                text = fields.report_text,
                comments = {},
                closed = false
            }
            save_reports()
            minetest.chat_send_player(name, "Report submitted!")
            show_report_menu(player)
        end

    elseif formname:match("^server_tools:report_list") then
        if fields.apply_filter and minetest.get_player_privs(name).repc then
            local filter_author = fields.filter_author or ""
            local status_index = tonumber(fields.filter_status) or 1
            local status_filter
            if status_index == 2 then status_filter = false
            elseif status_index == 3 then status_filter = true
            else status_filter = nil end

            local filtered = {}
            for _, r in pairs(reports) do
                if (filter_author == "" or r.author:find(filter_author)) and
                   (status_filter == nil or r.closed == status_filter) then
                    table.insert(filtered, r)
                end
            end
            show_report_list(player, filtered, "Filtered Reports 🔐")
        else
            for key,_ in pairs(fields) do
                if key:match("^view_report_(%d+)$") then
                    local id = tonumber(key:match("^view_report_(%d+)$"))
                    local report = reports[id]
                    if report then show_report(player, report) end
                end
            end
        end

    else
        for key,_ in pairs(fields) do
            if key == "submit_comment" and fields.new_comment then
                local id = tonumber(formname:match("server_tools:view_report_(%d+)"))
                local report = reports[id]
                if report then
                    table.insert(report.comments, {author=name, text=fields.new_comment})
                    save_reports()
                    show_report(player, report)
                end
            elseif key == "close_report" then
                local id = tonumber(formname:match("server_tools:view_report_(%d+)"))
                local report = reports[id]
                if report and minetest.get_player_privs(name).repc then
                    report.closed = true
                    save_reports()
                    minetest.chat_send_player(name, "Report closed 🔒")
                    show_report(player, report)
                end
            end
        end
    end
end)
