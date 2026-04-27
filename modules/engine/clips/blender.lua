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

function M:blend_transforms(blendingTransforms, factors)
    local transform = { }

    for i = 1, #blendingTransforms do
        local factor = factors[i]

        for boneId, nextBoneTransform in pairs(blendingTransforms[i]) do
            local boneTransform = transform[boneId]

            if not boneTransform then
                boneTransform = { }
                transform[boneId] = boneTransform
            end

            if nextBoneTransform[1] then
                if boneTransform[1] then
                    boneTransform[1] = vec3.add(
                            boneTransform[1],
                            vec3.mul(nextBoneTransform[1], factor)
                    )
                else
                    boneTransform[1] = vec3.mul(nextBoneTransform[1], factor)
                end
            end

            if nextBoneTransform[2] then
                if boneTransform[2] then
                    local accumulated = boneTransform[2]
                    local next = nextBoneTransform[2]
                    local factorMul = 1

                    if quat_math.dot(accumulated, next) < 0 then
                        factorMul = -1
                    end

                    boneTransform[2] = quat_math.add(
                            accumulated,
                            quat_math.mul(next, factor * factorMul)
                    )
                else
                    boneTransform[2] = quat_math.mul(nextBoneTransform[2], factor)
                end
            end

            if nextBoneTransform[3] then
                if boneTransform[3] then
                    boneTransform[3] = vec3.add(
                            boneTransform[3],
                            vec3.mul(nextBoneTransform[3], factor)
                    )
                else
                    boneTransform[3] = vec3.mul(nextBoneTransform[3], factor)
                end
            end
        end
    end

    for _, boneTransform in pairs(transform) do
        if boneTransform[2] then
            boneTransform[2] = quat_math.normalize(boneTransform[2])
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

    return self:blend_transforms(clipsTransforms, factors)
end

return M