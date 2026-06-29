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

local gltf_loader = require "gltf/gltf_loader"

local warnings = true

local MAGIC = 0x46546C67 -- glTF
local CHUNK_TYPE_JSON = 0x4E4F534A -- JSON
local CHUNK_TYPE_BIN = 0x004E4942 -- BIN

local UINT32_SIZE = 4

local supportedContainerVersion = 2

local supportedChunkTypes = {
    CHUNK_TYPE_JSON,
    CHUNK_TYPE_BIN
}

local chunkHexToString = {
    [CHUNK_TYPE_JSON] = "JSON",
    [CHUNK_TYPE_BIN] = "BIN"
}

local function warning(msg)
    if warnings then
        print("warning: " .. msg)
    end
end

local M = { }

function M.load(stream, loadSettings)
    local magic, version, length = stream:read("<III")

    if magic ~= MAGIC then
        error("invalid magic: 0x" .. string.format("%X", magic))
    end

    if version ~= supportedContainerVersion then
        error("unsupported glB version: " .. version)
    end

    local chunkOccurrences = { }

    local jsonChunk
    local binChunk

    while true do
        local chunkLength = stream:read(UINT32_SIZE)

        if #chunkLength ~= 0 and #chunkLength < UINT32_SIZE then
            error("invalid glB chunk")
        end

        chunkLength = byteutil.unpack("<I", chunkLength)

        local chunkType = stream:read("<I")
        local chunkData = stream:read(chunkLength)

        if table.has(supportedChunkTypes, chunkType) then
            if chunkOccurrences[chunkType] then
                error("glB chunk with type " .. chunkHexToString[chunkType] .. " already declared in file")
            end

            if #chunkData < chunkLength then
                error("glB chunk data is less than specified chunk length")
            end

            if chunkType == CHUNK_TYPE_JSON then
                jsonChunk = utf8.tostring(chunkData)
            elseif chunkType == CHUNK_TYPE_BIN then
                if not jsonChunk then
                    error("BIN chunk must be declared after JSON chunk")
                end

                binChunk = chunkData
            end
        else
            warning("skipping unsupported glB chunk of type 0x" .. string.format("%X", chunkType))
        end
    end

    if not jsonChunk then
        error("missing JSON chunk in glB file")
    end

    loadSettings.binaryChunk = binChunk

    local status, res = pcall(function() return { gltf_loader.load(jsonChunk, loadSettings) } end)

    if not status then
        error("failed to load glTF JSON chunk from glB file: " .. res)
    end

    return unpack(res)
end

return M