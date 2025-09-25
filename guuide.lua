-- guide.lua
local guide_storage = minetest.get_mod_storage()
local sections = minetest.deserialize(guide_storage:get_string("sections")) or {}
local selected_index = {}

local function save_sections()
    guide_storage:set_string("sections", minetest.serialize(sections))
end

local function show_guide(playername, selected)
    selected = selected or 1
    selected_index[playername] = selected

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
        "formspec_version[4]size[14,10]",
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

    minetest.show_formspec(playername, "custom_commands:guide", table.concat(formspec, ""))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "custom_commands:guide" then return end
    local name = player:get_player_name()
    local sel = selected_index[name] or 1

    if fields.section_list then
        local event = minetest.explode_textlist_event(fields.section_list)
        if event.type == "CHG" then
            show_guide(name, event.index)
            return
        end
    end

    if minetest.check_player_privs(name, { gued = true }) then
        if fields.save and fields.title and fields.content then
            if sections[sel] then
                sections[sel].title = fields.title
                sections[sel].content = fields.content
                save_sections()
            end
            show_guide(name, sel)
            return
        end
        if fields.add then
            table.insert(sections, { title = "New Section", content = "" })
            save_sections()
            show_guide(name, #sections)
            return
        end
        if fields.delete and sections[sel] then
            minetest.show_formspec(name, "custom_commands:confirm_delete",
                "formspec_version[4]size[6,3]" ..
                "label[0.5,0.5;Delete this section?]" ..
                "button[1,2;2,1;yes;Yes]" ..
                "button[3,2;2,1;no;No]"
            )
            return
        end
    end

    if fields.done then
        minetest.close_formspec(name, "custom_commands:guide")
    end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "custom_commands:confirm_delete" then return end
    local name = player:get_player_name()
    local sel = selected_index[name] or 1

    if fields.yes and sections[sel] then
        table.remove(sections, sel)
        save_sections()
    end
    show_guide(name, math.max(1, sel - 1))
end)

minetest.register_chatcommand("guide", {
    description = "Open the server guide",
    func = function(name)
        show_guide(name, 1)
    end,
})

minetest.register_privilege("gued", {
    description = "Can edit the guide sections",
    give_to_singleplayer = false,
})
