local M = { }

function M.get_object_hash(obj)
    local t = type(obj)

    if t == 'table' then
        local keys = { }

        for k, _ in pairs(obj) do
            table.insert(keys, k)
        end

        table.sort(keys)

        local hash = 0

        for i = 1, #keys do
            local key = keys[i]
            local value = obj[key]

            hash = bit.bxor(hash, crc32(Bytearray(M.get_object_hash(key) .. M.get_object_hash(value))))
        end

        return "crc32_" .. hash
    else return "crc32_" .. crc32(Bytearray(tostring(obj))) end
end

return M