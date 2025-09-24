-- guide.lua
local guide_storage = minetest.get_mod_storage()
local sections = minetest.deserialize(guide_storage:get_string("sections")) or {}

-- Save sections
local function save_sections()
    guide_storage:set_string("sections", minetest.serialize(sections))
end

-- Show guide formspec
local function show_guide(playername, selected)
    selected = selected or 1
    local section_titles = {}
    for i, sec in ipairs(sections) do
        table.insert(section_titles, i .. ". " .. sec.title)
    end
    if #section_titles == 0 then
        table.insert(section_titles, "<no sections>")
    end

    local current_content = sections[selected] and sections[selected].content or ""
    local current_title   = sections[selected] and sections[selected].title or ""

    local is_editor = minetest.check_player_privs(playername, { gued = true })

    local formspec = {
        "formspec_version[4]",
        "size[14,10]",
        "label[0.2,0.2;Guide Sections:]",
        "textlist[0.2,0.6;5,9;section_list;" .. table.concat(section_titles, ",") .. ";" .. selected .. "]",
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

    minetest.show_formspec(playername, "guide:main", table.concat(formspec, ""))
end

-- Handle form interactions
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "guide:main" then return end
    local name = player:get_player_name()

    -- Handle section selection
    if fields.section_list then
        local event = minetest.explode_textlist_event(fields.section_list)
        if event.type == "CHG" then
            show_guide(name, event.index)
            return
        end
    end

    -- Handle editor actions
    if minetest.check_player_privs(name, { gued = true }) then
        -- Save edits
        if fields.save and fields.title and fields.content then
            for i, sec in ipairs(sections) do
                if (fields.title == sec.title) or (fields.content == sec.content) then
                    sections[i].title = fields.title
                    sections[i].content = fields.content
                    save_sections()
                    break
                end
            end
            show_guide(name)
            return
        end

        -- Add new section
        if fields.add then
            table.insert(sections, { title = "New Section", content = "" })
            save_sections()
            show_guide(name, #sections)
            return
        end

        -- Delete section (with confirmation)
        if fields.delete then
            minetest.show_formspec(name, "guide:confirm_delete",
                "formspec_version[4]size[6,3]" ..
                "label[0.5,0.5;Are you sure you want to delete this section?]" ..
                "button[1,2;2,1;yes;Yes]" ..
                "button[3,2;2,1;no;No]"
            )
            return
        end
    end

    if fields.done then
        minetest.close_formspec(name, "guide:main")
    end
end)

-- Confirm delete dialog
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "guide:confirm_delete" then return end
    local name = player:get_player_name()
    if fields.yes then
        table.remove(sections, #sections)
        save_sections()
    end
    show_guide(name)
end)

-- /guide command
minetest.register_chatcommand("guide", {
    description = "Open the server guide",
    func = function(name)
        show_guide(name, 1)
    end,
})

-- Register priv
minetest.register_privilege("gued", {
    description = "Can edit the guide sections",
    give_to_singleplayer = false,
})
