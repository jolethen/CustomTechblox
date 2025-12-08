-- ==========================
-- CHANGELOG SYSTEM (LIKE GUIDE)
-- ==========================

local storage = minetest.get_mod_storage()

-- Use isolated storage key so it NEVER mixes with guide.lua
local changelog_sections =
    minetest.deserialize(storage:get_string("changelog_sections")) or {}

-- Track currently selected section (REAL FIX)
local selected_index = 1

-- Save
local function save_changelog()
    storage:set_string(
        "changelog_sections",
        minetest.serialize(changelog_sections)
    )
end

-- GLOBAL function (rules.lua calls this)
function show_changelog(playername, selected)
    selected = selected or selected_index
    selected_index = selected

    -- Build title list
    local titles = {}
    for i, sec in ipairs(changelog_sections) do
        table.insert(titles, i .. ". " .. sec.title)
    end
    if #titles == 0 then
        table.insert(titles, "<no logs>")
    end

    local cur = changelog_sections[selected_index] or { title = "", content = "" }

    local is_editor = minetest.check_player_privs(playername, { clog = true })

    local fs = {
        "formspec_version[4]",
        "size[14,10]",
        "label[0.2,0.2;Changelog:]",
        "textlist[0.2,0.6;5,9;clogs;" ..
            table.concat(titles, ",") ..
            ";" .. selected_index .. "]",

        "label[5.5,0.2;Details:]",
        "textarea[5.5,0.6;8,7;content;;" ..
            minetest.formspec_escape(cur.content) .. "]"
    }

    if is_editor then
        table.insert(fs,
            "field[5.5,7.8;6,1;title;Title;" ..
                minetest.formspec_escape(cur.title) .. "]")
        table.insert(fs, "button[12,7.8;1.5,1;save;Save]")
        table.insert(fs, "button[5.5,9;2,1;add;Add+]")
        table.insert(fs, "button[8,9;2,1;delete;Delete]")
    else
        table.insert(fs, "button[12,8.5;1.5,1;done;Done]")
    end

    minetest.show_formspec(playername, "changelog:main", table.concat(fs, ""))
end

-- Handle UI
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "changelog:main" then return end
    local name = player:get_player_name()

    -- Selecting a section
    if fields.clogs then
        local ev = minetest.explode_textlist_event(fields.clogs)
        if ev.type == "CHG" then
            selected_index = ev.index
            show_changelog(name, selected_index)
            return
        end
    end

    -- Editor actions
    if minetest.check_player_privs(name, { clog = true }) then

        -- SAVE → THIS IS THE FIXED PART
        if fields.save and fields.title and fields.content then
            if changelog_sections[selected_index] then
                changelog_sections[selected_index].title = fields.title
                changelog_sections[selected_index].content = fields.content
                save_changelog()
            end

            show_changelog(name, selected_index)
            return
        end

        -- Add new entry
        if fields.add then
            table.insert(changelog_sections,
                { title = "New Entry", content = "" })
            save_changelog()
            selected_index = #changelog_sections
            show_changelog(name, selected_index)
            return
        end

        -- Delete confirmation
        if fields.delete then
            minetest.show_formspec(name, "changelog:delete",
                "formspec_version[4]size[6,3]" ..
                "label[0.5,0.6;Delete latest changelog entry?]" ..
                "button[1,2;2,1;yes;Yes]" ..
                "button[3,2;2,1;no;No]"
            )
            return
        end
    end

    -- Close
    if fields.done then
        minetest.close_formspec(name, "changelog:main")
        return
    end
end)

-- Delete dialog
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "changelog:delete" then return end
    local name = player:get_player_name()

    if fields.yes then
        table.remove(changelog_sections, #changelog_sections)
        save_changelog()
    end

    selected_index = math.min(selected_index, #changelog_sections)
    if selected_index < 1 then selected_index = 1 end

    show_changelog(name, selected_index)
end)

-- Chat command
minetest.register_chatcommand("changelog", {
    description = "View server changelog",
    func = function(name)
        show_changelog(name, selected_index)
    end
})

-- Privilege
minetest.register_privilege("clog", {
    description = "Can edit the changelog",
    give_to_singleplayer = false
})
