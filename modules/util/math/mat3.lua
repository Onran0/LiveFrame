local M = { }

function M.transpose(m)
    return {
        m[1], m[4], m[7],
        m[2], m[5], m[8],
        m[3], m[6], m[9]
    }
end

return M