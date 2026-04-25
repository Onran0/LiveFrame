local math_util = require "util/math/math_util"
local quat_math = require "util/math/quat_math"

local M = { }

M.__index = M

function M:new(sampler)
    return setmetatable({ sampler = sampler }, self)
end

function M:get_sampler()
    return self.sampler
end

function M:set_sampler(sampler)
    self.sampler = sampler
end

function M:blend_transforms_samples(times, factors, blendingClipsIndices, useIndicesInsteadNames)
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