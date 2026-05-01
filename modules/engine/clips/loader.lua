local loaders = {
    lfa = {
        binary = false,
        func = require("lfa/loader").load
    }
}

local M = { }

function M.load_from_path(filePath)
    local ext = file.ext(filePath)

    local loader = loaders[ext]

    if not loader then
        error("unsupported animations format: " .. ext)
    end

    return loader.func(loader.binary and file.read_bytes(filePath) or file.read(filePath))
end

function M.get_load_function_by_extension(ext)
    return loaders[ext].func
end

function M.is_binary_format(ext)
    return loaders[ext].binary
end

return M