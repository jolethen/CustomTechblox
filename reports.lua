-- =====================
-- REPORT SYSTEM
-- =====================

local reports = {}
local report_id = 0

minetest.register_privilege("redit", {
    description = "Can comment on reports",
    give_to_admin = true
})

-- /report <message>
minetest.register_chatcommand("report", {
    params = "<message>",
    description = "File a report",
    func = function(name, param)
        if param == "" then
            return false, "Usage: /report <message>"
        end
        report_id = report_id + 1
        reports[report_id] = { owner = name, message = param, comments = {} }
        return true, "Report #" .. report_id .. " submitted."
    end
})

-- /comment <id> <message>
minetest.register_chatcommand("comment", {
    params = "<id> <message>",
    description = "Comment on a report",
    privs = { redit = true },
    func = function(name, param)
        local id, msg = param:match("^(%d+)%s+(.+)$")
        id = tonumber(id)
        if not id or not msg or not reports[id] then
            return false, "Invalid usage. /comment <id> <message>"
        end
        table.insert(reports[id].comments, name .. ": " .. msg)
        return true, "Comment added to report #" .. id
    end
})
