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

local loader = require "engine/loader"
local sampler = require "engine/clips/sampler"

local player = require "engine/clips/player"
local animator = require "engine/animator/animator"
local animator_loader = require "engine/animator/animator_loader"

local clips_meta_combiner = require "engine/clips/meta_combiner"

local M = { }

local function loadClipsMetadata(filePath, loadSettings)
    local status, val = xpcall(loader.load_from_path, util.include_traceback, filePath, loadSettings)

    if not status then
        error("failed to load animations file '" .. filePath .. "': " .. val)
    end

    return val
end

function M.load_model(entity, filePath, loadSettings)
    local status, clipsMetadataOrError, loaderTemp = xpcall(loader.load_from_path, util.include_traceback, filePath, loadSettings)

    if not status then
        error("failed to load model file '" .. filePath .. "': " .. clipsMetadataOrError)
    end

    if not loaderTemp then
        error("failed to load model from file '" .. filePath .. "'. maybe this format is not supporting models?")
    end

    local err
    status, err = xpcall(loader.setup_model, util.include_traceback, filePath, entity, loaderTemp)

    if not status then
        error("failed to setup model on entity: " .. err)
    end
end

function M.load_animator(skeleton, filePath)
    local status, res = xpcall(animator_loader.load, util.include_traceback,  file.read(filePath))

    if not status then
        error("failed to load animator '" .. filePath .. "': " .. res)
    end

    return animator:new(res, skeleton)
end

function M.create_player(skeleton, ...)
    local filesData = { ... }

    local clipsMetadataArray = { }
    local overrideClipNames = { }

    for index, fileData in ipairs(filesData) do
        local isOnlyPath = type(fileData) == "string"

        if isOnlyPath then
            clipsMetadataArray[index] = loadClipsMetadata(fileData)
        else
            clipsMetadataArray[index] = loadClipsMetadata(fileData.path, fileData.loadSettings)

            overrideClipNames[index] = fileData.overrides
        end
    end

    return player:new(
                sampler:new(
                        clips_meta_combiner.combine(clipsMetadataArray, overrideClipNames)
                ), skeleton
    )
end

return M