local math_util = require "util/math/math_util"
local quat_math = require "util/math/quat_math"
local util = require "util/util"

local M = { }

M.__index = M

function M:new(player)
    return setmetatable({
        player = player,
        blendingClipsNames = { },
        blendingClipsIndices = { }
    }, self)
end

function M:get_blending_clips()
    return self.blendingClipsNames
end

function M:set_blending_clips(blendingClipsNames)
    self.blendingClipsNames = blendingClipsNames

    local blendingClipsIndices = { }

    util.foreach(blendingClipsNames, function(clipName, index)
        blendingClipsIndices[index] = self.player:get_clip_index_by_name(clipName)
    end)

    self.blendingClipsIndices = blendingClipsIndices
end

function M:blend_transforms_samples(times, factors)
    local blendingClipsIndices = self.blendingClipsIndices

    local clipsTransforms = { }

    for i = 1, #blendingClipsIndices do
        self.player:play_by_index(blendingClipsIndices[i])

        clipsTransforms[i] = self.player:get_transforms_sample(times[i])

        self.player:stop()
    end

    local transform = clipsTransforms[1]

    local factorsTable = type(factors) == 'table'

    for i = 2, #clipsTransforms do
        local factor = factorsTable and factors[i - 1] or factors

        util.foreach(
                clipsTransforms[i],
                function(nextBoneTransform, boneName)
                    local boneTransform = transform[boneName]

                    if nextBoneTransform[1] then
                        boneTransform[1] = math_util.lerp(boneTransform[1] or { 0, 0, 0 }, nextBoneTransform[1], factor)
                    end

                    if nextBoneTransform[2] then
                        boneTransform[2] = quat.slerp(boneTransform[2] or quat_math.idt(), nextBoneTransform[2], factor)
                    end

                    if nextBoneTransform[3] then
                        boneTransform[3] = math_util.lerp(boneTransform[3] or { 0, 0, 0 }, nextBoneTransform[3], factor)
                    end
                end
        )
    end

    return transform
end

return M