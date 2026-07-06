local M = { }

local typeOrder = {
    ["nil"] = 1,
    ["boolean"] = 2,
    ["number"] = 3,
    ["string"] = 4,
    ["table"] = 5
}

local function crc32ObjectHash(obj, visited)
    local t = type(obj)

    if t == 'table' then
        visited = visited or { }

        if visited[obj] then
            error("unable to hash cyclic reference")
        end

        visited[obj] = true

        local keys = { }

        for k, _ in pairs(obj) do
            table.insert(keys, k)
        end

        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)

            if ta ~= tb then
                return typeOrder[ta] < typeOrder[tb]
            end

            return a < b
        end)

        local hash = crc32(Bytearray("table"))

        for i = 1, #keys do
            local key = keys[i]
            local value = obj[key]

            local keyHash = crc32ObjectHash(key, visited)
            local valueHash = crc32ObjectHash(value, visited)

            hash = crc32(
                    byteutil.unpack("<I",
                            crc32(
                                    byteutil.unpack("<I", keyHash),
                                    valueHash
                            )
                    ),
                    hash
            )
        end

        visited[obj] = nil

        return hash
    else
        if
            t == "function" or t == "thread" or (t == "userdata" and not M.is_bytearray(obj))
        then
            error("unable to hash values of type " .. t)
        end

        return crc32(Bytearray(tostring(obj) .. ":" .. t))
    end
end

local bytearrayMethods = {
    "append", "insert", "remove", "trim", "clear", "reserve", "get_capacity", "slice"
}

function M.is_bytearray(obj)
    if type(obj) == "userdata" then
        local allHas = true

        for _, method in ipairs(bytearrayMethods) do
            if not obj[method] then
                allHas = false
                break
            end
        end

        return allHas
    end

    return false
end

function M.get_object_hash(obj)
    return "crc32_" .. crc32ObjectHash(obj)
end

function M.include_traceback(err)
    return debug.traceback(err, 1)
end

return M