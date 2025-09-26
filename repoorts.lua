-- report.lua
-- Interactive report system (no comments). Close removes/hides reports from /ra and /vr.
-- Persistence via world file: <world>/custom_commands_reports.data

local report_file = minetest.get_worldpath() .. "/custom_commands_reports.data"
local reports = {}               -- array of report tables { id, author, title, text, status, created }
local list_map = {}              -- per-player mapping table[name] = { report_id1, report_id2, ... }
local page_map = {}              -- per-player current page

local PER_PAGE = 20

-- Load / Save
local function load_reports()
    local f = io.open(report_file, "r")
    if not f then return end
    local content = f:read("*all")
    f:close()
    local ok, data = pcall(minetest.deserialize, content)
    if ok and type(data) == "table" then
        reports = data
    else
        reports = {}
    end
end

local function save_reports()
    local f, err = io.open(report_file, "w")
    if not f then
        minetest.log("error", "[custom_commands.report] failed to open report file for writing: "..tostring(err))
        return
    end
    f:write(minetest.serialize(reports))
    f:close()
end

load_reports()

-- Privilege for staff
minetest.register_privilege("ra", {
    description = "Can view/manage reports",
    give_to_singleplayer = false,
})

-- Helpers
local function safe_get_report(id)
    id = tonumber(id)
    if not id then return nil end
    if reports[id] and type(reports[id]) == "table" then
        return reports[id]
    end
    return nil
end

local function build_open_list_for_staff()
    local list = {}
    for i, r in ipairs(reports) do
        if r and r.status == "open" then
            table.insert(list, { id = r.id or i, author = r.author, text = r.text, title = r.title })
        end
    end
    return list
end

local function build_open_list_for_author(author)
    local list = {}
    for i, r in ipairs(reports) do
        if r and r.status == "open" and r.author == author then
            table.insert(list, { id = r.id or i, author = r.author, text = r.text, title = r.title })
        end
    end
    return list
end

local function sanitize_text_for_list(s)
    if not s then return "" end
    local s2 = tostring(s)
    s2 = s2:gsub("\n", " ")
    s2 = s2:gsub(",", " ") -- textlist uses commas as separators
    if #s2 > 80 then
        s2 = s2:sub(1,77) .. "..."
    end
    return s2
end

-- UI: Staff reports list (paginated)
local function show_reports_menu(name, page)
    page = tonumber(page) or 1
    local full = build_open_list_for_staff()
    local total = #full
    local total_pages = math.max(1, math.ceil(total / PER_PAGE))
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_i = (page - 1) * PER_PAGE + 1
    local entries = {}
    local mapping = {}

    for i = start_i, math.min(start_i + PER_PAGE - 1, total) do
        local item = full[i]
        if item then
            local label = tostring(item.id) .. " - " .. minetest.formspec_escape(item.author) .. ": " .. minetest.formspec_escape(sanitize_text_for_list(item.text))
            table.insert(entries, label)
            table.insert(mapping, item.id)
        end
    end

    if #entries == 0 then entries = { "<no reports>" } end

    local textlist = "textlist[0.5,0.8;11,6;report_list;" .. table.concat(entries, ",") .. ";0]"
    local pager = "label[0.5,7.0;Page " .. page .. " / " .. total_pages .. "]"
    if page > 1 then pager = pager .. "button[4.2,7;1.8,1;prev;Prev]" end
    if page < total_pages then pager = pager .. "button[6.2,7;1.8,1;next;Next]" end

    local formspec = table.concat({
        "formspec_version[4]",
        "size[12,8]",
        "label[0.5,0.2;Reports (staff view)]",
        textlist,
        pager,
        "button[10.2,0.2;1.6,1;new;New]"
    }, "")

    list_map[name] = mapping
    page_map[name] = page
    minetest.show_formspec(name, "reports:main", formspec)
end

-- UI: Author's own reports list (paginated)
local function show_my_reports_menu(name, page)
    page = tonumber(page) or 1
    local full = build_open_list_for_author(name)
    local total = #full
    local total_pages = math.max(1, math.ceil(total / PER_PAGE))
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_i = (page - 1) * PER_PAGE + 1
    local entries = {}
    local mapping = {}

    for i = start_i, math.min(start_i + PER_PAGE - 1, total) do
        local item = full[i]
        if item then
            local label = tostring(item.id) .. " - " .. minetest.formspec_escape(sanitize_text_for_list(item.text))
            table.insert(entries, label)
            table.insert(mapping, item.id)
        end
    end

    if #entries == 0 then entries = { "<no reports>" } end

    local textlist = "textlist[0.5,0.8;11,6;report_list;" .. table.concat(entries, ",") .. ";0]"
    local pager = "label[0.5,7.0;Page " .. page .. " / " .. total_pages .. "]"
    if page > 1 then pager = pager .. "button[4.2,7;1.8,1;prev;Prev]" end
    if page < total_pages then pager = pager .. "button[6.2,7;1.8,1;next;Next]" end

    local formspec = table.concat({
        "formspec_version[4]",
        "size[12,8]",
        "label[0.5,0.2;My Reports]",
        textlist,
        pager,
        "button[10.2,0.2;1.6,1;new;New]"
    }, "")

    list_map[name] = mapping
    page_map[name] = page
    minetest.show_formspec(name, "reports:my", formspec)
end

-- UI: View a single report
local function show_single_report(name, report_id, context)
    local r = safe_get_report(report_id)
    if not r then
        minetest.chat_send_player(name, "⚠ Report not found (ID "..tostring(report_id)..")")
        return
    end

    -- Only show if user can access
    local can_view = (r.author == name) or minetest.check_player_privs(name, {ra = true})
    if not can_view then
        minetest.chat_send_player(name, "You don't have access to this report.")
        return
    end

    local display_text = minetest.formspec_escape(r.text or "")
    local title = minetest.formspec_escape(r.title or ("Report #" .. tostring(r.id)))
    local is_staff = minetest.check_player_privs(name, {ra = true})

    local formspec_parts = {
        "formspec_version[4]",
        "size[12,8]",
        "label[0.5,0.2;Report: " .. title .. "]",
        "textarea[0.5,0.6;11,4;report_text;;" .. display_text .. "]",
        "label[0.5,5.0;Status: " .. minetest.formspec_escape(r.status) .. "]",
        "button[9.5,5;2,1;back;Back]"
    }

    if is_staff then
        table.insert(formspec_parts, "button[0.5,5;2,1;close;Close]")
    end

    local formspec = table.concat(formspec_parts, "")
    -- we encode context and id in the formname so handler can tell where to go back
    minetest.show_formspec(name, "reports:view_" .. context .. "_" .. tostring(report_id), formspec)
end

-- New report form
local function show_new_report_form(name)
    local formspec = table.concat({
        "formspec_version[4]",
        "size[12,8]",
        "label[0.5,0.2;Create a new report]",
        "field[0.5,1;11,1;report_title;Title;]",
        "textarea[0.5,2.2;11,4;report_text;Describe your issue;]",
        "button[4.5,6.5;3,1;submit_report;Submit]",
        "button[8.0,6.5;3,1;cancel_report;Cancel]"
    }, "")
    minetest.show_formspec(name, "reports:new", formspec)
end

-- Main forms handler
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- NEW report form submitted
    if formname == "reports:new" then
        if fields.submit_report and fields.report_text and fields.report_text:trim() ~= "" then
            local newid = #reports + 1
            local title = (fields.report_title and fields.report_title:trim() ~= "") and fields.report_title or ("Report #" .. tostring(newid))
            reports[newid] = {
                id = newid,
                author = name,
                title = title,
                text = fields.report_text,
                status = "open",
                created = os.time()
            }
            save_reports()
            minetest.chat_send_player(name, "✅ Report submitted with ID " .. tostring(newid))
            show_my_reports_menu(name, 1)
            return true
        end
        if fields.cancel_report then
            -- simply close the formspec
            minetest.close_formspec(name, "reports:new")
            return true
        end
        return true
    end

    -- Staff list interactions
    if formname == "reports:main" then
        -- Prev / Next pagination
        if fields.prev then
            local p = (page_map[name] or 1) - 1
            show_reports_menu(name, p)
            return true
        elseif fields.next then
            local p = (page_map[name] or 1) + 1
            show_reports_menu(name, p)
            return true
        elseif fields.new then
            show_new_report_form(name)
            return true
        end

        -- textlist selection
        if fields.report_list then
            local event = minetest.explode_textlist_event(fields.report_list)
            if event and (event.type == "DCL" or event.type == "CHG") then
                local idx = event.index
                local mapping = list_map[name] or {}
                local report_id = mapping[idx]
                if report_id then
                    show_single_report(name, report_id, "staff")
                end
            end
            return true
        end

        return true
    end

    -- Author list interactions
    if formname == "reports:my" then
        -- Prev / Next pagination
        if fields.prev then
            local p = (page_map[name] or 1) - 1
            show_my_reports_menu(name, p)
            return true
        elseif fields.next then
            local p = (page_map[name] or 1) + 1
            show_my_reports_menu(name, p)
            return true
        elseif fields.new then
            show_new_report_form(name)
            return true
        end

        if fields.report_list then
            local event = minetest.explode_textlist_event(fields.report_list)
            if event and (event.type == "DCL" or event.type == "CHG") then
                local idx = event.index
                local mapping = list_map[name] or {}
                local report_id = mapping[idx]
                if report_id then
                    show_single_report(name, report_id, "author")
                end
            end
            return true
        end

        return true
    end

    -- Single report view interactions (formname like "reports:view_<context>_<id>")
    if formname:sub(1,12) == "reports:view_" then
        -- parse formname
        -- pattern: reports:view_<context>_<id>
        local _, _, rest = formname:find("reports:view_(.+)")
        if not rest then return true end
        local context, id_str = rest:match("^([^_]+)_(%d+)$")
        local id = tonumber(id_str)
        if not context or not id then return true end

        if fields.back then
            if context == "staff" then
                show_reports_menu(name, page_map[name] or 1)
            else
                show_my_reports_menu(name, page_map[name] or 1)
            end
            return true
        end

        -- Close (staff only) -> mark closed so it no longer appears
        if fields.close then
            if not minetest.check_player_privs(name, {ra = true}) then
                minetest.chat_send_player(name, "You do not have permission to close reports.")
                return true
            end
            local r = safe_get_report(id)
            if not r then
                minetest.chat_send_player(name, "Report not found.")
                return true
            end
            r.status = "closed"
            save_reports()
            -- After closing, return to the appropriate menu (staff)
            if context == "staff" then
                show_reports_menu(name, page_map[name] or 1)
            else
                show_my_reports_menu(name, page_map[name] or 1)
            end
            minetest.chat_send_player(name, "Report "..tostring(id).." closed (hidden).")
            return true
        end

        return true
    end
end)

-- Commands
minetest.register_chatcommand("report", {
    description = "Open the new report form",
    func = function(name)
        show_new_report_form(name)
    end
})

minetest.register_chatcommand("ra", {
    description = "Staff: view all open reports",
    privs = { ra = true },
    func = function(name)
        show_reports_menu(name, 1)
    end
})

minetest.register_chatcommand("vr", {
    description = "View your own open reports",
    func = function(name)
        show_my_reports_menu(name, 1)
    end
})
