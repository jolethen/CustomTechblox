-- =====================
-- GUIDE SYSTEM (with navigation + per-player memory)
-- =====================

local guides_path = minetest.get_worldpath() .. "/guides.txt"
local guides = {
    { name = "General", content = "This is the server guide.\nFollow the basics here." }
}

-- Memory: stores each player's last viewed section
local player_last_section = {}

-- Load / Save
local function load_guides()
    local f = io.open(guides_path, "r")
    if f then
        local data = minetest.deserialize(f:read("*all"))
        f:close()
        if type(data) == "table" then
            guides = data
        end
    end
end

local function save_guides()
    local f = io.open(guides_path, "w")
    if f then
        f:write(minetest.serialize(guides))
        f:close()
    end
end

load_guides()

-- Privilege
minetest.register_privilege("gued", {
    description = "Can edit the server guide",
    give_to_admin = true
})

-- Show Guide Menu
local function show_guide(player_name, section_index)
    section_index = section_index or 1
    local section = guides[section_index]
    if not section then section = { name = "Unnamed", content = "" } end

    -- Save last section for this player
    player_last_section[player_name] = section_index

    -- Top buttons for direct section jump
    local buttons = ""
    local x = 0.5
    for i, sec in ipairs(guides) do
        buttons = buttons .. "button[" .. x .. ",0.5;2.5,1;sec_" .. i .. ";" ..
            minetest.formspec_escape(sec.name) .. "]"
        x = x + 2.7
    end
    if minetest.check_player_privs(player_name, { gued = true }) then
        buttons = buttons .. "button[" .. x .. ",0.5;2,1;add_section;+]"
    end

    -- Navigation arrows
    local nav = ""
    if section_index > 1 then
        nav = nav .. "button[0.5,8;2,1;prev_section;<< Prev]"
    end
    if section_index < #guides then
        nav = nav .. "button[11.5,8;2,1;next_section;Next >>]"
    end

    -- Base formspec
    local formspec = "formspec_version[4]size[14,9]" ..
        buttons ..
        "field[0.5,1.8;6,1;section_name;Section;" .. minetest.formspec_escape(section.name) .. "]" ..
        "textarea[0.5,3;13,5;guide;Content;" .. minetest.formspec_escape(section.content) .. "]" ..
        nav

    if minetest.check_player_privs(player_name, { gued = true }) then
        formspec = formspec ..
            "button[4,8;2,1;delete_section;Delete]" ..
            "button[7,8;2,1;save_guide;Save]"
    else
        formspec = formspec .. "button_exit[6,8;2,1;close;Close]"
    end

    minetest.show_formspec(player_name, "server_tools:guide_" .. section_index, formspec)
end

-- Command
minetest.register_chatcommand("guide", {
    description = "Open the server guide",
    func = function(name)
        local section = player_last_section[name] or 1
        show_guide(name, section)
    end,
})

-- Confirmation Popup
local function confirm_delete(player_name, section_index)
    local sec = guides[section_index]
    if not sec then return end
    local formspec = "formspec_version[4]size[8,3]" ..
        "label[0.5,0.5;Delete section '" .. minetest.formspec_escape(sec.name) .. "'?]" ..
        "button[1,2;2,1;confirm_yes;Yes]" ..
        "button[5,2;2,1;confirm_no;No]"
    minetest.show_formspec(player_name, "server_tools:confirm_" .. section_index, formspec)
end

-- Handle Forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- Main Guide
    local section_index = tonumber(formname:match("^server_tools:guide_(%d+)$"))
    if section_index then
        local section = guides[section_index]
        if fields.save_guide and minetest.check_player_privs(name, { gued = true }) then
            if fields.section_name and fields.section_name ~= "" then
                section.name = fields.section_name
            end
            if fields.guide then
                section.content = fields.guide
            end
            save_guides()
            minetest.chat_send_player(name, "Guide section updated: " .. section.name)
            show_guide(name, section_index)

        elseif fields.add_section and minetest.check_player_privs(name, { gued = true }) then
            table.insert(guides, { name = "New Section", content = "Write here..." })
            save_guides()
            show_guide(name, #guides)

        elseif fields.delete_section and minetest.check_player_privs(name, { gued = true }) then
            confirm_delete(name, section_index)

        elseif fields.prev_section then
            show_guide(name, section_index - 1)

        elseif fields.next_section then
            show_guide(name, section_index + 1)

        else
            for i, sec in ipairs(guides) do
                if fields["sec_" .. i] then
                    show_guide(name, i)
                end
            end
        end
    end

    -- Confirmation Window
    local confirm_index = tonumber(formname:match("^server_tools:confirm_(%d+)$"))
    if confirm_index then
        if fields.confirm_yes and minetest.check_player_privs(name, { gued = true }) then
            local removed = table.remove(guides, confirm_index)
            save_guides()
            minetest.chat_send_player(name, "Deleted section: " .. removed.name)
            show_guide(name, 1)
        elseif fields.confirm_no then
            show_guide(name, confirm_index)
        end
    end
end)
