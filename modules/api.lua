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

local loader = require "engine/clips/loader"
local sampler = require "engine/clips/sampler"

local player = require "engine/clips/player"
local animator = require "engine/animator/animator"
local animator_loader = require "engine/animator/animator_loader"

local clips_meta_combiner = require "engine/clips/meta_combiner"

local M = { }

local function loadClipsMetadata(filePath)
    local status, val = pcall(loader.load_from_path, filePath)

    if not status then
        error("failed to load animations file '" .. filePath .. "': " .. val)
    end

    return val
end

local function createPlayer(clipsMetadata, skeleton)
    return player:new(sampler:new(clipsMetadata), skeleton)
end

function M.create_animator(filePath, skeleton)
    local status, res = pcall(animator_loader.load, file.read(filePath))

    if not status then
        error("failed to load animator '" .. filePath .. "': " .. res)
    end

    return animator:new(res, skeleton)
end

function M.create_player(filePath, skeleton)
    return createPlayer(loadClipsMetadata(filePath), skeleton)
end

function M.create_player_multi(skeleton, ...)
    local filesData = { ... }

    local clipsMetadataArray = { }
    local overrideClipNames = { }

    for index, fileData in ipairs(filesData) do
        local isOnlyPath = type(fileData) == "string"

        clipsMetadataArray[index] = loadClipsMetadata(isOnlyPath and fileData or fileData.path)

        if not isOnlyPath then
            overrideClipNames[index] = fileData.overrides
        end
    end

    local clipsMetadata = clips_meta_combiner.combine(clipsMetadataArray, overrideClipNames)

    return createPlayer(clipsMetadata, skeleton)
end

return M