-- server_tools/init.lua
local report_file = minetest.get_worldpath().."/reports.txt"
local reports = {}
local report_id_counter = 0

-- Convert timestamp to readable string
local function format_time(ts)
    return os.date("%Y-%m-%d %H:%M:%S", ts)
end

-- Load reports from file
local function load_reports()
    local file = io.open(report_file, "r")
    if file then
        local data = file:read("*all")
        file:close()
        if data ~= "" then
            local ok, decoded = pcall(minetest.deserialize, data)
            if ok and type(decoded) == "table" then
                reports = decoded
                for _, r in pairs(reports) do
                    if r.id > report_id_counter then
                        report_id_counter = r.id
                    end
                end
            end
        end
    end
end

-- Save reports to file
local function save_reports()
    local file = io.open(report_file, "w")
    if file then
        file:write(minetest.serialize(reports))
        file:close()
    end
end

load_reports()

-- Register staff privilege
minetest.register_privilege("scc", {
    description = "Can view and comment on all reports",
    give_to_singleplayer = true,
})

-- Create a report
minetest.register_chatcommand("report", {
    params = "<message>",
    description = "Create a report",
    func = function(name, param)
        if param == "" then return false, "You must provide a report message." end
        report_id_counter = report_id_counter + 1
        local report = {
            id = report_id_counter,
            author = name,
            message = param,
            comments = {},
            time = os.time(),
            closed = false
        }
        table.insert(reports, report)
        save_reports()
        return true, "Report created with ID "..report.id
    end,
})

-- Show report list
local function show_report_list(player_name)
    local formspec = "size[8,9]label[0,0;Reports:]scrollbaroptions[8,0;0.5,8;vertical;1]"
    local y = 0.5
    local count = 0
    for _, r in ipairs(reports) do
        if r.author == player_name or minetest.check_player_privs(player_name).scc then
            count = count + 1
            local closed_text = r.closed and " (Closed)" or ""
            formspec = formspec.."button[0,"..y..";7,0.5;view_"..r.id..";ID "..r.id.." - "..r.author..closed_text.."]"
            y = y + 0.6
        end
    end
    if count == 0 then
        formspec = formspec.."label[0,1;No reports available]"
    end
    minetest.show_formspec(player_name, "server_tools:report_list", formspec)
end

-- Show single report with comments and timestamps
local function show_report(player_name, report)
    local lines = {
        "ID: "..report.id,
        "Author: "..report.author,
        "Created: "..format_time(report.time),
        "Message: "..report.message,
        "Closed: "..tostring(report.closed),
        "",
        "Comments:"
    }
    for _, c in ipairs(report.comments) do
        table.insert(lines, format_time(c.time).." - "..c.author..": "..c.text)
    end
    local text = table.concat(lines, "\n")

    local formspec =
        "size[10,9]"..
        "textarea[0,0;10,6.5;report_text;;"..minetest.formspec_escape(text).."]"..
        "field[0,6.6;7,1;comment;;]"..
        "button[7,6.6;3,1;add_comment;Add Comment]"..
        "button_exit[7,7.6;3,1;close;Close]"

    if not report.closed and minetest.check_player_privs(player_name).scc then
        formspec = formspec.."button[0,7.6;7,1;close_report;Close Report]"
    end

    minetest.show_formspec(player_name, "server_tools:report_"..report.id, formspec)
end

-- List reports command
minetest.register_chatcommand("report_list", {
    description = "List reports",
    func = function(name)
        show_report_list(name)
        return true
    end,
})

-- Handle formspec actions
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- Click on a report in the list
    if formname == "server_tools:report_list" then
        for k, _ in pairs(fields) do
            local id = k:match("^view_(%d+)$")
            if id then
                id = tonumber(id)
                for _, r in ipairs(reports) do
                    if r.id == id then
                        if r.author == name or minetest.check_player_privs(name).scc then
                            show_report(name, r)
                        else
                            minetest.chat_send_player(name, "You cannot view this report.")
                        end
                    end
                end
            end
        end
    end

    -- Single report formspec
    local id = formname:match("^server_tools:report_(%d+)$")
    if id then
        id = tonumber(id)
        for _, r in ipairs(reports) do
            if r.id == id then
                -- Add comment
                if fields.add_comment and fields.comment ~= "" then
                    if not r.closed or minetest.check_player_privs(name).scc then
                        if r.author == name or minetest.check_player_privs(name).scc then
                            table.insert(r.comments, {author=name, text=fields.comment, time=os.time()})
                            save_reports()
                            show_report(name, r)
                        else
                            minetest.chat_send_player(name, "You cannot comment on this report.")
                        end
                    else
                        minetest.chat_send_player(name, "This report is closed. Only staff can comment.")
                    end
                end
                -- Close report button
                if fields.close_report then
                    if minetest.check_player_privs(name).scc then
                        r.closed = true
                        save_reports()
                        minetest.chat_send_player(name, "Report "..r.id.." closed.")
                        show_report(name, r)
                    else
                        minetest.chat_send_player(name, "You do not have permission to close reports.")
                    end
                end
            end
        end
    end
end)
