local M = { }

function M.foreach(tbl, func)
    for k, v in pairs(tbl) do
        if func(v, k) then
            break
        end
    end
end

return M