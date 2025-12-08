-- ==========================
-- CHANGELOG SYSTEM (LIKE GUIDE)
-- ==========================

local storage = minetest.get_mod_storage()
local changelog_sections =
    minetest.deserialize(storage:get_string("changelog_sections")) or {}

-- Save
local function save_changelog()
    storage:set_string(
        "changelog_sections",
        minetest.serialize(changelog_sections)
    )
end

-- GLOBAL function (used by rules.lua)
function show_changelog(playername, selected)
    selected = selected or 1

    -- Build titles list
    local titles = {}
    for i, sec in ipairs(changelog_sections) do
        table.insert(titles, i .. ". " .. sec.title)
    end
    if #titles == 0 then
        table.insert(titles, "<no logs>")
    end

    local current_title =
        changelog_sections[selected] and changelog_sections[selected].title or ""
    local current_content =
        changelog_sections[selected] and changelog_sections[selected].content or ""

    local is_editor = minetest.check_player_privs(playername, { clog = true })

    local formspec = {
        "formspec_version[4]",
        "size[14,10]",
        "label[0.2,0.2;Changelog:]",
        "textlist[0.2,0.6;5,9;clogs;" ..
            table.concat(titles, ",") ..
            ";" .. selected .. "]",
        "label[5.5,0.2;Details:]",
        "textarea[5.5,0.6;8,7;content;;" ..
            minetest.formspec_escape(current_content) .. "]"
    }

    if is_editor then
        table.insert(formspec,
            "field[5.5,7.8;6,1;title;Title;" ..
                minetest.formspec_escape(current_title) .. "]")
        table.insert(formspec, "button[12,7.8;1.5,1;save;Save]")
        table.insert(formspec, "button[5.5,9;2,1;add;Add+]")
        table.insert(formspec, "button[8,9;2,1;delete;Delete]")
    else
        table.insert(formspec, 
            "button[12,8.5;1.5,1;done;Done]")
    end

    minetest.show_formspec(playername,
        "changelog:main",
        table.concat(formspec, "")
    )
end

-- Handle UI events
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "changelog:main" then return end
    local name = player:get_player_name()

    -- Selecting items
    if fields.clogs then
        local ev = minetest.explode_textlist_event(fields.clogs)
        if ev.type == "CHG" then
            show_changelog(name, ev.index)
            return
        end
    end

    -- Editor
    if minetest.check_player_privs(name, { clog = true }) then

        -- Save
        if fields.save and fields.title and fields.content then
            local selected = nil

            -- Find selected index safely
            if fields.clogs then
                local ev = minetest.explode_textlist_event(fields.clogs)
                if ev.index then selected = ev.index end
            end
            selected = selected or 1

            if changelog_sections[selected] then
                changelog_sections[selected].title = fields.title
                changelog_sections[selected].content = fields.content
                save_changelog()
            end

            show_changelog(name, selected)
            return
        end

        -- Add entry
        if fields.add then
            table.insert(changelog_sections,
                { title = "New Entry", content = "" })
            save_changelog()
            show_changelog(name, #changelog_sections)
            return
        end

        -- Delete
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

    if fields.done then
        minetest.close_formspec(name, "changelog:main")
    end
end)

-- Confirm delete dialog
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "changelog:delete" then return end
    local name = player:get_player_name()

    if fields.yes then
        table.remove(changelog_sections, #changelog_sections)
        save_changelog()
    end

    show_changelog(name)
end)

-- Chat command
minetest.register_chatcommand("changelog", {
    description = "View server changelog",
    func = function(name)
        show_changelog(name, 1)
    end
})

-- Privilege
minetest.register_privilege("clog", {
    description = "Can edit the changelog",
    give_to_singleplayer = false
})
