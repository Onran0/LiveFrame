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

local place_default_bones_transforms = require "util/place_default_bones_transforms"

local M = { }

local tablesEquals

local function directTablesEquals(a, b)
    for name, value in pairs(a) do
        local bValue = b[name]

        if not bValue then
            return false
        end

        local t = type(bValue)

        if t ~= type(value) then
            return false
        elseif t == "table" then
            if not tablesEquals(value, bValue) then
                return false
            end
        elseif value ~= bValue then return false end
    end

    return true
end

tablesEquals = function(a, b)
    if not directTablesEquals(a, b) then return false end
    if not directTablesEquals(b, a) then return false end

    return true
end

function M.combine(clipsMetadataArray, overrideClipsNames)
    local combinedInterpTypesIndices = { }
    local combinedInterpFieldsIndices = { }
    local combinedBonesIndices = { }
    local combinedClips = { }

    local relativizedTransforms
    local skeleton

    for clipsMetadataIndex, clipsMetadata in ipairs(clipsMetadataArray) do
        if skeleton then
            local prefMsg = "incompatible metadata's: "
            local postMsg = " in " .. clipsMetadataIndex .. "th clip metadata"

            if not tablesEquals(skeleton, clipsMetadata.metadata.skeleton) then
                error(prefMsg .. "different skeleton" .. postMsg)
            elseif relativizedTransforms ~= clipsMetadata.metadata.relativizedTransforms then
                error(prefMsg .. "different relativization" .. postMsg)
            end
        else
            relativizedTransforms = clipsMetadata.metadata.relativizedTransforms
            skeleton = clipsMetadata.metadata.skeleton
        end

        local fromLocalInterpTypesIndicesToCombined = { }
        local fromLocalInterpFieldsIndicesToCombined = { }
        local fromLocalBoneIndexToCombined = { }

        for index, type in ipairs(clipsMetadata.interpTypesIndices) do
            if not table.has(combinedInterpTypesIndices, type) then
                table.insert(combinedInterpTypesIndices, type)
                fromLocalInterpTypesIndicesToCombined[index] = index
            else
                fromLocalInterpTypesIndicesToCombined[index] = table.index(
                        combinedInterpTypesIndices, type
                )
            end
        end

        for type, value in pairs(clipsMetadata.interpFieldsIndices) do
            local combinedTargetedInterpFieldsIndices = combinedInterpFieldsIndices[type]

            local tbl = { }

            if not combinedTargetedInterpFieldsIndices then
                combinedInterpFieldsIndices[type] = table.deep_copy(value)

                for targetId, fieldIndices in pairs(value) do
                    tbl[targetId] = { }

                    for fieldIndex, _ in ipairs(fieldIndices) do
                        tbl[targetId][fieldIndex] = fieldIndex
                    end
                end
            else
                for targetId, fieldIndices in pairs(value) do
                    if not tbl[targetId] then
                        tbl[targetId] = { }
                    end

                    if not combinedTargetedInterpFieldsIndices[targetId] then
                        combinedTargetedInterpFieldsIndices[targetId] = { }
                    end

                    for fieldIndex, fieldName in ipairs(fieldIndices) do
                        if table.has(combinedTargetedInterpFieldsIndices[targetId], fieldName) then
                            tbl[targetId][fieldIndex] = table.index(combinedTargetedInterpFieldsIndices[targetId], fieldName)
                        else
                            combinedTargetedInterpFieldsIndices[targetId][fieldIndex] = fieldName
                            tbl[targetId][fieldIndex] = fieldIndex
                        end
                    end
                end
            end

            fromLocalInterpFieldsIndicesToCombined[
                table.index(clipsMetadata.interpTypesIndices, type)
            ] = tbl
        end

        for index, value in ipairs(clipsMetadata.bonesIndices) do
            local combinedIndex

            if not table.has(combinedBonesIndices, value) then
                table.insert(combinedBonesIndices, value)
                combinedIndex = #combinedBonesIndices
            else
                combinedIndex = table.index(combinedBonesIndices, value)
            end

            fromLocalBoneIndexToCombined[index] = combinedIndex
        end

        for _, clip in ipairs(clipsMetadata.clips) do
            local combinedClip = {
                name = clip.name,
                loop = clip.loop,
                duration = clip.duration,
                events = clip.events
            }

            local combinedBonesKeys = { }

            -- clip name overriding
            if
            overrideClipsNames and
                    overrideClipsNames[clipsMetadataIndex] and
                    overrideClipsNames[clipsMetadataIndex][combinedClip.name]
            then
                combinedClip.name = overrideClipsNames[clipsMetadataIndex][combinedClip.name]
            end

            -- converting interpolation type and fields indices from local metadata space to combined
            for localBoneIndex, transformsKeys in ipairs(clip.bonesKeys) do
                local combinedBoneKeys = { }

                for i = 1, 3 do
                    local combinedTransformKeys = { }

                    if transformsKeys[i] and #transformsKeys[i] > 0 then
                        for _, key in ipairs(transformsKeys[i]) do
                            local localInterpTypeIndex = key[constants.KEY_INTERP_TYPE_INDEX]

                            local combinedKey = table.copy(key)

                            if localInterpTypeIndex then
                                combinedKey[constants.KEY_INTERP_TYPE_INDEX] = fromLocalInterpTypesIndicesToCombined[localInterpTypeIndex]
                            end

                            if combinedKey[constants.KEY_INTERP_FIELDS_INDEX] then
                                local localFieldsValues = combinedKey[constants.KEY_INTERP_FIELDS_INDEX]
                                local combinedFieldsValues = { }

                                local targetId = i == constants.ROTATION_KEYS_INDEX and constants.TARGET_QUAT or constants.TARGET_VEC3

                                for j = 1, #localFieldsValues do
                                    combinedFieldsValues[
                                        fromLocalInterpFieldsIndicesToCombined[localInterpTypeIndex][targetId][j]
                                    ] = localFieldsValues[j]
                                end

                                combinedKey[constants.KEY_INTERP_FIELDS_INDEX] = combinedFieldsValues
                            end

                            table.insert(combinedTransformKeys, combinedKey)
                        end
                    end

                    combinedBoneKeys[i] = combinedTransformKeys
                end

                combinedBonesKeys[fromLocalBoneIndexToCombined[localBoneIndex]] = combinedBoneKeys
            end

            local combinedAffectedBones = { }

            for i, boneIndex in ipairs(clip.affectedBones) do
                combinedAffectedBones[i] = fromLocalBoneIndexToCombined[boneIndex]
            end

            combinedClip.bonesKeys = combinedBonesKeys
            combinedClip.affectedBones = combinedAffectedBones

            table.insert(combinedClips, combinedClip)
        end
    end

    place_default_bones_transforms(combinedClips, combinedBonesIndices, relativizedTransforms, skeleton)

    return {
        metadata = {
            relativizedTransforms = relativizedTransforms,
            skeleton = skeleton
        },
        interpTypesIndices = combinedInterpTypesIndices,
        interpFieldsIndices = combinedInterpFieldsIndices,
        bonesIndices = combinedBonesIndices,
        clips = combinedClips
    }
end

return M