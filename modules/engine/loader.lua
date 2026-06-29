--[[
   Copyright 2026 Onran

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]]--

local util = require "util/util"

local loaders = {
    ["lfa"] = {
        binary = false,
        funcs = require("lfa/loader")
    },
    ["gltf"] = {
        binary = false,
        funcs = require("gltf/gltf_loader")
    },
    ["glb"] = {
        binary = true,
        requiresStream = true,
        funcs = require("gltf/glb_loader")
    }
}

local loadSettingsAliases = {
    relativizeTransforms = "relativize-transforms"
}

local cache = { }

local M = { }

function M.load_from_path(filePath, loadSettings, noCache)
    if loadSettings then
        for name, alias in pairs(loadSettingsAliases) do
            if loadSettings[alias] ~= nil then
                loadSettings[name] = loadSettings[alias]
                loadSettings[alias] = nil
            end
        end
    end

    local loadSettingsHash

    if not noCache then
       loadSettingsHash = util.get_object_hash(loadSettings)

        if cache[filePath] and cache[filePath][loadSettingsHash] then
            return unpack(cache[filePath][loadSettingsHash])
        end
    end

    local ext = file.ext(filePath)

    local loader = loaders[ext]

    if not loader then
        error("unsupported file format: " .. ext)
    end

    loadSettings = loadSettings or { }

    loadSettings.sourceFile = filePath

    local rawIsStream
    local raw

    if loader.binary then
        if loader.requiresStream then
            raw = file.open(filePath, "r")
            rawIsStream = true
        else
            raw = file.read_bytes(filePath)
        end
    else
        raw = file.read(filePath)
    end

    local status, result = pcall(function() return { loader.funcs.load(raw, loadSettings) } end)

    if rawIsStream then
        raw:close()
    end

    if not status then
        error(result)
    end

    if not noCache then
        local fileCaches = cache[filePath]

        if not fileCaches then
            fileCaches = { }
            cache[filePath] = fileCaches
        end

        fileCaches[loadSettingsHash] = result
    end

    return unpack(result)
end

function M.setup_model(filePath, entity, loaderTemp)
    local ext = file.ext(filePath)

    local loader = loaders[ext]

    if not loader then
        error("unsupported file format: " .. ext)
    end

    loader.funcs.setup_model(entity, loaderTemp)
end

function M.remove_from_cache(filePath, loadSettings)
    if cache[filePath] then
        if loadSettings ~= nil then
            local hash = util.get_object_hash(loadSettings)

            if cache[filePath][hash] then
                cache[filePath][hash] = nil
                return true
            else return false end
        else
            cache[filePath] = nil
            return true
        end
    else return false end
end

function M.get_load_function_by_extension(ext)
    return loaders[ext].funcs.load
end

function M.is_binary_format(ext)
    return loaders[ext].binary
end

return M