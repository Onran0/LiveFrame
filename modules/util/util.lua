local M = { }

function M.get_object_hash(obj)
    local t = type(obj)

    if t == 'table' then
        local keys = { }

        for k, _ in pairs(obj) do
            table.insert(keys, k)
        end

        table.sort(keys)

        local hash = ''

        for i = 1, #keys do
            local key = keys[i]
            local value = obj[key]

            hash = hash .. base64.encode( M.get_object_hash(key) .. M.get_object_hash(value) )
        end

        return hash
    else return tostring(obj) end
end

return M