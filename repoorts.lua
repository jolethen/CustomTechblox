-- server_tools: Full report system with comments & close/reopen

-- Sample report data
local reports = {}
for i=1,50 do
    table.insert(reports, {id=i, title="Report "..i, author="Player"..i, closed=(i%3==0), comments={}})
end

-- Helper: safely convert to string
local function safe_string(str)
    if not str then return "" end
    return tostring(str)
end

-- Show report list (scrollable)
local function show_report_list(player, list, title)
    local name = player:get_player_name()

    local rows = {}
    for _, report in ipairs(list) do
        local status = report.closed and "[Closed]" or "[Open]"
        table.insert(rows, safe_string(report.id.."|"..report.title.." by "..report.author.." "..status))
    end

    local formspec = "size[8,9]" ..
                     "label[0,0;"..minetest.formspec_escape(title).."]" ..
                     "field[0,0.5;5,1;filter_author;Filter by author;]" ..
                     "dropdown[5,0.5;3,1;filter_status;All,Open,Closed;1]" ..
                     "button[0,1;2,1;apply_filter;Apply Filter]" ..
                     "tablecolumns[color;text]" ..
                     "table[0,2;8,6;report_table;"..table.concat(rows, ",")..";1,1;false]" ..
                     "button_exit[0,8.5;2,1;close;Close]"

    minetest.show_formspec(name, "server_tools:report_list", formspec)
end

-- Show detailed report with comments and close/reopen button
local function show_report_detail(player, report)
    local name = player:get_player_name()
    local comments_text = ""
    for i, c in ipairs(report.comments) do
        comments_text = comments_text .. safe_string(i..". "..c.author..": "..c.text) .. "\n"
    end

    local status_label = report.closed and "Reopen Report" or "Close Report"

    local formspec = "size[8,9]" ..
                     "label[0,0;"..minetest.formspec_escape("Report: "..report.title).."]" ..
                     "label[0,0.5;"..minetest.formspec_escape("Author: "..report.author).."]" ..
                     "label[0,1;"..minetest.formspec_escape("Status: "..(report.closed and "Closed" or "Open")).."]" ..
                     "textarea[0,1.7;8,4;comments;Comments;"..minetest.formspec_escape(comments_text).."]" ..
                     "field[0,6.0;6,1;new_comment;Add Comment;]" ..
                     "button[6,6;2,1;add_comment;Add]" ..
                     "button[0,7;3,1;toggle_status;"..status_label.."]" ..
                     "button[4,7;2,1;close_detail;Back]"

    minetest.show_formspec(name, "server_tools:report_detail_"..report.id, formspec)
end

-- Handle all forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- Report list
    if formname == "server_tools:report_list" then
        -- Apply filter
        if fields.apply_filter then
            local filtered = {}
            for _, r in ipairs(reports) do
                local match_author = (fields.filter_author == "" or string.find(r.author, fields.filter_author))
                local match_status = (fields.filter_status == "All" or
                                     (fields.filter_status == "Open" and not r.closed) or
                                     (fields.filter_status == "Closed" and r.closed))
                if match_author and match_status then
                    table.insert(filtered, r)
                end
            end
            show_report_list(player, filtered, "Reports")
            return
        end

        -- Table selection
        if fields.report_table then
            local selection = fields.report_table
            local row = tonumber(selection:match("^(%d+),"))
            if row and reports[row] then
                show_report_detail(player, reports[row])
            end
        end
        return
    end

    -- Detailed report
    for _, r in ipairs(reports) do
        if formname == "server_tools:report_detail_"..r.id then
            if fields.add_comment and fields.new_comment and fields.new_comment ~= "" then
                table.insert(r.comments, {author=name, text=fields.new_comment})
                show_report_detail(player, r)
                return
            elseif fields.toggle_status then
                r.closed = not r.closed
                show_report_detail(player, r)
                return
            elseif fields.close_detail then
                show_report_list(player, reports, "Reports")
                return
            end
        end
    end
end)

-- Chat command to open report list
minetest.register_chatcommand("list_reports", {
    description = "List all reports",
    privs = {server=true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            show_report_list(player, reports, "Reports")
        end
    end,
})
