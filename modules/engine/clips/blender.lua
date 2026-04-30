local constants = require "general_constants"

local posIndex, rotIndex, sclIndex = constants.POSITION_INDEX, constants.ROTATION_INDEX, constants.SCALE_INDEX

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
    if nextBoneTransform[posIndex] then
        if prevBoneTransform[posIndex] then
            prevBoneTransform[posIndex] = vec3.add(
                    prevBoneTransform[posIndex],
                    vec3.mul(nextBoneTransform[posIndex], factor)
            )
        else
            prevBoneTransform[posIndex] = vec3.mul(nextBoneTransform[posIndex], factor)
        end
    end

    if nextBoneTransform[rotIndex] then
        if prevBoneTransform[rotIndex] then
            local accumulated = prevBoneTransform[rotIndex]
            local next = nextBoneTransform[rotIndex]
            local factorMul = 1

            if quat_math.dot(accumulated, next) < 0 then
                factorMul = -1
            end

            prevBoneTransform[rotIndex] = quat_math.add(
                    accumulated,
                    quat_math.mul(next, factor * factorMul)
            )
        else
            prevBoneTransform[rotIndex] = quat_math.mul(nextBoneTransform[rotIndex], factor)
        end
    end

    if nextBoneTransform[sclIndex] then
        if prevBoneTransform[sclIndex] then
            prevBoneTransform[sclIndex] = vec3.add(
                    prevBoneTransform[sclIndex],
                    vec3.mul(nextBoneTransform[sclIndex], factor)
            )
        else
            prevBoneTransform[sclIndex] = vec3.mul(nextBoneTransform[sclIndex], factor)
        end
    end
end

local function blendLayer(prevBoneTransform, nextBoneTransform, weight)
    if nextBoneTransform[posIndex] then
        if prevBoneTransform[posIndex] then
            prevBoneTransform[posIndex] = vec3.mix(
                    prevBoneTransform[posIndex],
                    nextBoneTransform[posIndex],
                    weight
            )
        else
            prevBoneTransform[posIndex] = nextBoneTransform[posIndex]
        end
    end

    if nextBoneTransform[rotIndex] then
        if prevBoneTransform[rotIndex] then
            prevBoneTransform[rotIndex] = quat.slerp(
                    prevBoneTransform[rotIndex],
                    nextBoneTransform[rotIndex],
                    weight
            )
        else
            prevBoneTransform[rotIndex] = nextBoneTransform[rotIndex]
        end
    end

    if nextBoneTransform[sclIndex] then
        if prevBoneTransform[sclIndex] then
            prevBoneTransform[sclIndex] = vec3.mix(
                    prevBoneTransform[sclIndex],
                    nextBoneTransform[sclIndex],
                    weight
            )
        else
            prevBoneTransform[sclIndex] = nextBoneTransform[sclIndex]
        end
    end
end

function M:blend_transforms(mode, blendingTransforms, factors, canApplyBlendCheck)
    local transform = { }

    local blendFunc = mode == BLEND_MODE_AVERAGE and blendAverage or blendLayer

    for i = 1, #blendingTransforms do
        local factor = factors[i]

        for boneId, nextBoneTransform in ipairs(blendingTransforms[i]) do
            local boneTransform = transform[boneId]

            if not boneTransform then
                boneTransform = { }
                transform[boneId] = boneTransform
            end

            if not canApplyBlendCheck or canApplyBlendCheck(i, boneId) then
                blendFunc(boneTransform, nextBoneTransform, factor)
            end
        end
    end

    if mode == BLEND_MODE_AVERAGE then
        for _, boneTransform in ipairs(transform) do
            if boneTransform[rotIndex] then
                boneTransform[rotIndex] = quat_math.normalize(boneTransform[rotIndex])
            end
        end
    end

    return transform
end

function M:calculate_samples_and_blend(times, blendingClipsIndices, factors)
    local clipsTransforms = { }

    for i = 1, #blendingClipsIndices do
        clipsTransforms[i] = self.sampler:get_transforms_sample(times[i], blendingClipsIndices[i])
    end

    return self:blend_transforms(BLEND_MODE_AVERAGE, clipsTransforms, factors)
end

return M