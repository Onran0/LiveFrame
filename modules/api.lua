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

local function createPlayer(clipsMetadata, skeleton, eventHandlers)
    return player:new(sampler:new(clipsMetadata), skeleton, eventHandlers)
end

function M.create_animator(filePath, skeleton, eventHandlers)
    local status, res = pcall(animator_loader.load, file.read(filePath))

    if not status then
        error("failed to load animator '" .. filePath .. "': " .. res)
    end

    return animator:new(res, skeleton, eventHandlers)
end

function M.create_player(filePath, skeleton, eventHandlers)
    return createPlayer(loadClipsMetadata(filePath), skeleton, eventHandlers)
end

function M.create_player_multi(filePaths, skeleton, overrideClipNames, eventHandlers)
    local clipsMetadataArray = { }

    for index, filePath in ipairs(filePaths) do
        clipsMetadataArray[index] = loadClipsMetadata(filePath)
    end

    local clipsMetadata = clips_meta_combiner.combine(clipsMetadataArray, overrideClipNames)

    return createPlayer(clipsMetadata, skeleton, eventHandlers)
end

return M