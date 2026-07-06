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

local function setupModel(entity, modelMetadata)
    local skeletonName = modelMetadata.skeleton
    local bones = modelMetadata.bones
    local meshes = modelMetadata.meshes

    entity:set_skeleton(skeletonName)

    local rig = entity.skeleton

    for boneName, boneInfo in pairs(bones) do
        local ind = rig:index(boneName)

        if boneInfo.mesh then
            rig:set_model(ind, meshes[boneInfo.mesh])
        end

        rig:set_matrix(ind, boneInfo.matrix)
    end
end

local function loadClipsMetadata(filePath, loadSettings)
    local status, res = xpcall(loader.load_from_path, util.include_traceback, filePath, loadSettings)

    if not status then
        error("failed to load animations file '" .. filePath .. "': " .. res)
    end

    return res.clipsMetadata
end

function M.load_model(entity, filePath, loadSettings)
    local status, res = xpcall(loader.load_from_path, util.include_traceback, filePath, loadSettings)

    if not status then
        error("failed to load model file '" .. filePath .. "': " .. res)
    end

    if not res.modelMetadata then
        error("failed to load model from file '" .. filePath .. "'. maybe this format is not supporting models?")
    end

    setupModel(entity, res.modelMetadata)
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