local constants = require "general_constants"

return function(clips, bonesIndices, relativizedTransforms, skeleton)
    local defaultPos = { 0, 0, 0 }
    local defaultRot = { 1, 0, 0, 0 }
    local defaultScale = { 1, 1, 1 }

    for _, clip in ipairs(clips) do
        local bonesKeys = clip.bonesKeys

        for index, name in ipairs(bonesIndices) do
            local bindPose = skeleton[name]

            if not bonesKeys[index] then
                bonesKeys[index] = {
                    { { relativizedTransforms and defaultPos or bindPose.position, 0 } }, -- default position
                    { { relativizedTransforms and defaultRot or bindPose.rotation, 0 } }, -- default rotation
                    { { relativizedTransforms and defaultScale or bindPose.scale, 0 } } -- default scale
                }
            else
                local boneKeys = bonesKeys[index]

                if not boneKeys[constants.POSITION_KEYS_INDEX] or #boneKeys[constants.POSITION_KEYS_INDEX] == 0 then
                    boneKeys[constants.POSITION_KEYS_INDEX] = { { relativizedTransforms and defaultPos or bindPose.position, 0 } }
                end

                if not boneKeys[constants.ROTATION_KEYS_INDEX] or #boneKeys[constants.ROTATION_KEYS_INDEX] == 0 then
                    boneKeys[constants.ROTATION_KEYS_INDEX] = { { relativizedTransforms and defaultRot or bindPose.rotation, 0 } }
                end

                if not boneKeys[constants.SCALE_KEYS_INDEX] or #boneKeys[constants.SCALE_KEYS_INDEX] == 0 then
                    boneKeys[constants.SCALE_KEYS_INDEX] = { { relativizedTransforms and defaultScale or bindPose.scale, 0 } }
                end
            end
        end
    end
end