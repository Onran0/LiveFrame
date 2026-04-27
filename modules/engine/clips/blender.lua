local quat_math = require "util/math/quat_math"

local BLEND_MODE_AVERAGE = 0
local BLEND_MODE_LAYER = 1

local M = {
    BLEND_MODE_AVERAGE = BLEND_MODE_AVERAGE,
    BLEND_MODE_LAYER = BLEND_MODE_LAYER
}

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

local function blendAverage(prevBoneTransform, nextBoneTransform, factor)
    if nextBoneTransform[1] then
        if prevBoneTransform[1] then
            prevBoneTransform[1] = vec3.add(
                    prevBoneTransform[1],
                    vec3.mul(nextBoneTransform[1], factor)
            )
        else
            prevBoneTransform[1] = vec3.mul(nextBoneTransform[1], factor)
        end
    end

    if nextBoneTransform[2] then
        if prevBoneTransform[2] then
            local accumulated = prevBoneTransform[2]
            local next = nextBoneTransform[2]
            local factorMul = 1

            if quat_math.dot(accumulated, next) < 0 then
                factorMul = -1
            end

            prevBoneTransform[2] = quat_math.add(
                    accumulated,
                    quat_math.mul(next, factor * factorMul)
            )
        else
            prevBoneTransform[2] = quat_math.mul(nextBoneTransform[2], factor)
        end
    end

    if nextBoneTransform[3] then
        if prevBoneTransform[3] then
            prevBoneTransform[3] = vec3.add(
                    prevBoneTransform[3],
                    vec3.mul(nextBoneTransform[3], factor)
            )
        else
            prevBoneTransform[3] = vec3.mul(nextBoneTransform[3], factor)
        end
    end
end

local function blendLayer(prevBoneTransform, nextBoneTransform, weight)
    if nextBoneTransform[1] then
        if prevBoneTransform[1] then
            prevBoneTransform[1] = vec3.mix(
                    prevBoneTransform[1],
                    nextBoneTransform[1],
                    weight
            )
        else
            prevBoneTransform[1] = nextBoneTransform[1]
        end
    end

    if nextBoneTransform[2] then
        if prevBoneTransform[2] then
            prevBoneTransform[2] = quat.slerp(
                    prevBoneTransform[2],
                    nextBoneTransform[2],
                    weight
            )
        else
            prevBoneTransform[2] = nextBoneTransform[2]
        end
    end

    if nextBoneTransform[3] then
        if prevBoneTransform[3] then
            prevBoneTransform[3] = vec3.mix(
                    prevBoneTransform[3],
                    nextBoneTransform[3],
                    weight
            )
        else
            prevBoneTransform[3] = nextBoneTransform[3]
        end
    end
end

function M:blend_transforms(mode, blendingTransforms, factors)
    local transform = { }

    local blendFunc = mode == BLEND_MODE_AVERAGE and blendAverage or blendLayer

    for i = 1, #blendingTransforms do
        local factor = factors[i]

        for boneId, nextBoneTransform in pairs(blendingTransforms[i]) do
            local boneTransform = transform[boneId]

            if not boneTransform then
                boneTransform = { }
                transform[boneId] = boneTransform
            end

            blendFunc(boneTransform, nextBoneTransform, factor)
        end
    end

    if mode == BLEND_MODE_AVERAGE then
        for _, boneTransform in pairs(transform) do
            if boneTransform[2] then
                boneTransform[2] = quat_math.normalize(boneTransform[2])
            end
        end
    end

    return transform
end

function M:calculate_samples_and_blend(times, blendingClipsIndices, factors, useIndicesInsteadNames)
    local clipsTransforms = { }

    for i = 1, #blendingClipsIndices do
        clipsTransforms[i] = self.sampler:get_transforms_sample(
                times[i], blendingClipsIndices[i],
                useIndicesInsteadNames
        )
    end

    return self:blend_transforms(BLEND_MODE_AVERAGE, clipsTransforms, factors)
end

return M