local M = { }

function M.foreach(array, func)
    for i = 1, #array do
        if func(array[i], i) then
            break
        end
    end
end

return M