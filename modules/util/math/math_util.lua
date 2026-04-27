local M = { }

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.compose_matrix_from_transform(transform)
    local matrix

    if transform[1] then
        matrix = mat4.translate(transform[1])
    else
        matrix = mat4.idt()
    end

    if transform[2] then
        matrix = mat4.mul(matrix, mat4.from_quat(transform[2]))
    end

    if transform[3] then
        matrix = mat4.mul(matrix, mat4.scale(transform[3]))
    end

    return matrix
end

return M