local math_util = require "util/math/math_util"
local quat_math = require "util/math/quat_math"
local util = require "util/util"

local M = { }

M.__index = M

function M:new(sampler)
    return setmetatable({
        sampler = sampler,
        blendingClipsNames = { },
        blendingClipsIndices = { }
    }, self)
end

function M:get_sampler()
    return self.sampler
end

function M:set_sampler(sampler)
    self.sampler = sampler
    self:set_blending_clips(self.blendingClipsNames)
end

function M:get_blending_clips()
    return self.blendingClipsNames
end

function M:set_blending_clips(blendingClipsNames)
    self.blendingClipsNames = blendingClipsNames

    local blendingClipsIndices = { }

    util.foreach(blendingClipsNames, function(clipName, index)
        blendingClipsIndices[index] = self.sampler:get_clip_index_by_name(clipName)
    end)

    self.blendingClipsIndices = blendingClipsIndices
end

function M:blend_transforms_samples(times, factors, useIndicesInsteadNames)
    local blendingClipsIndices = self.blendingClipsIndices

    local clipsTransforms = { }

    for i = 1, #blendingClipsIndices do
        clipsTransforms[i] = self.sampler:get_transforms_sample(
                times[i], blendingClipsIndices[i],
                useIndicesInsteadNames
        )
    end

    local transform = clipsTransforms[1]

    for i = 2, #clipsTransforms do
        local factor = factors[i - 1]

        for boneId, nextBoneTransform in pairs(clipsTransforms[i]) do
            local boneTransform = transform[boneId]

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
    end

    return transform
end

return M