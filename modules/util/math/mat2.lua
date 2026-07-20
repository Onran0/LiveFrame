local M = { }

function M.transpose(m)
    return {
        m[1], m[3],
        m[2], m[4]
    }
end

return M