-- changelog.lua
-- Minimal-safe changelog system matching guide.lua style

local ch_storage = minetest.get_mod_storage()
local changelog_sections = minetest.deserialize(ch_storage:get_string("changelog_sections")) or {}

-- Save sections
local function save_changelog()
    ch_storage:set_string("changelog_sections", minetest.serialize(changelog_sections))
end

-- Make this a global function so other files (rules.lua) can call it
function show_changelog(playername, selected)
    selected = selected or 1
    local section_titles = {}
    for i, sec in ipairs(changelog_sections) do
        table.insert(section_titles, i .. ". " .. sec.title)
    end
    if #section_titles == 0 then
        table.insert(section_titles, "<no sections>")
    end

    local current_content = changelog_sections[selected] and changelog_sections[selected].content or ""
    local current_title   = changelog_sections[selected] and changelog_sections[selected].title or ""

    local is_editor = minetest.check_player_privs(playername, { cled = true })

    local formspec = {
        "formspec_version[4]",
        "size[14,10]",
        "label[0.2,0.2;Changelog Sections:]",
        "textlist[0.2,0.6;5,9;cl_list;" .. table.concat(section_titles, ",") .. ";" .. selected .. "]",
        "label[5.5,0.2;Content:]",
        "textarea[5.5,0.6;8,7;content;;" .. minetest.formspec_escape(current_content) .. "]",
    }

    if is_editor then
        table.insert(formspec, "field[5.5,7.8;6,1;title;Title;" .. minetest.formspec_escape(current_title) .. "]")
        table.insert(formspec, "button[12,7.8;1.5,1;save;Save]")
        table.insert(formspec, "button[5.5,9;2,1;add;Add+]")
        table.insert(formspec, "button[8,9;2,1;delete;Delete]")
    else
        table.insert(formspec, "button[12,8.5;1.5,1;done;Done]")
    end

    minetest.show_formspec(playername, "cl:main", table.concat(formspec, ""))
end

-- Handle changelog interactions
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "cl:main" then return end
    local name = player:get_player_name()

    -- Section selection
    if fields.cl_list then
        local event = minetest.explode_textlist_event(fields.cl_list)
        if event.type == "CHG" then
            show_changelog(name, event.index)
            return
        end
    end

    -- Editor functions
    if minetest.check_player_privs(name, { cled = true }) then

        if fields.save and fields.title and fields.content then
            for i, sec in ipairs(changelog_sections) do
                -- preserve your existing matching logic (title/content match)
                if (fields.title == sec.title) or (fields.content == sec.content) then
                    changelog_sections[i].title = fields.title
                    changelog_sections[i].content = fields.content
                    save_changelog()
                    break
                end
            end
            show_changelog(name)
            return
        end

        if fields.add then
            table.insert(changelog_sections, { title = "New Log", content = "" })
            save_changelog()
            show_changelog(name, #changelog_sections)
            return
        end

        if fields.delete then
            minetest.show_formspec(name, "cl:confirm_delete",
                "formspec_version[4]size[6,3]" ..
                "label[0.5,0.5;Delete this changelog entry?]" ..
                "button[1,2;2,1;yes;Yes]" ..
                "button[3,2;2,1;no;No]"
            )
            return
        end
    end

    if fields.done then
        minetest.close_formspec(name, "cl:main")
    end
end)

-- Confirm delete dialog
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "cl:confirm_delete" then return end
    local name = player:get_player_name()

    if fields.yes then
        table.remove(changelog_sections, #changelog_sections)
        save_changelog()
    end

    show_changelog(name)
end)

-- /changelog command
minetest.register_chatcommand("changelog", {
    description = "Open the changelog",
    func = function(name)
        show_changelog(name, 1)
    end,
})

-- Privilege
minetest.register_privilege("cled", {
    description = "Can edit changelog sections",
    give_to_singleplayer = false,
})
