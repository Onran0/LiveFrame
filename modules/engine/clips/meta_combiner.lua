local place_default_bones_transforms = require "util/place_default_bones_transforms"

local M = { }

function M.combine(clipsMetadataArray, overrideClipsNames)
    local combinedInterpTypesIndices = { }
    local combinedInterpFieldsIndices = { }
    local combinedBonesIndices = { }
    local combinedClips = { }

    for clipsMetadataIndex, clipsMetadata in ipairs(clipsMetadataArray) do
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
            local combinedConcreteInterpFieldsIndices = combinedInterpFieldsIndices[type]

            local tbl = { }

            if not combinedConcreteInterpFieldsIndices then
                combinedInterpFieldsIndices[type] = table.copy(value)

                for fieldIndex, _ in ipairs(value) do
                    tbl[fieldIndex] = fieldIndex
                end
            else
                for fieldIndex, fieldName in ipairs(value) do
                    if table.has(combinedConcreteInterpFieldsIndices, fieldName) then
                        tbl[fieldIndex] = table.index(combinedConcreteInterpFieldsIndices, fieldName)
                    else
                        combinedConcreteInterpFieldsIndices[fieldIndex] = fieldName
                        tbl[fieldIndex] = fieldIndex
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
            for localBoneIndex, transformsKeys in pairs(clip.bonesKeys) do
                local combinedBoneKeys = { }

                for i = 1, 3 do
                    local combinedTransformKeys = { }

                    if transformsKeys[i] and #transformsKeys[i] > 0 then
                        for _, key in ipairs(transformsKeys[i]) do
                            local localInterpTypeIndex = key[3]

                            local combinedKey = table.copy(key)

                            if localInterpTypeIndex then
                                combinedKey[3] = fromLocalInterpTypesIndicesToCombined[localInterpTypeIndex]
                            end

                            if combinedKey[4] then
                                local localFieldsValues = combinedKey[4]
                                local combinedFieldsValues = { }

                                for j = 1, #localFieldsValues do
                                    combinedFieldsValues[
                                    fromLocalInterpFieldsIndicesToCombined[localInterpTypeIndex][j]
                                    ] = localFieldsValues[j]
                                end

                                combinedKey[4] = combinedFieldsValues
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

    place_default_bones_transforms(combinedClips, combinedBonesIndices)

    return {
        interpTypesIndices = combinedInterpTypesIndices,
        interpFieldsIndices = combinedInterpFieldsIndices,
        bonesIndices = combinedBonesIndices,
        clips = combinedClips
    }
end

return M