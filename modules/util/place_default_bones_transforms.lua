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