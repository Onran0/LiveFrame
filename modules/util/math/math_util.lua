local M = { }

function M.lerp(a, b, t)
    return a + (b - a) * t
end

return M