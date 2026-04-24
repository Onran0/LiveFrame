local util = require "util/util"

local M = { }

function M.combine(clipsMetadataArray, overrideClipsNames)
    local combinedInterpTypesIndices = { }
    local combinedInterpFieldsIndices = { }
    local combinedBonesIndices = { }
    local combinedClips = { }

    util.foreach(clipsMetadataArray, function(clipsMetadata, clipsMetadataIndex)
        local fromLocalInterpTypesIndicesToCombined = { }
        local fromLocalInterpFieldsIndicesToCombined = { }
        local fromLocalBoneIndexToCombined = { }

        util.foreach(clipsMetadata.interpTypesIndices, function(type, index)
            if not table.has(combinedInterpTypesIndices, type) then
                table.insert(combinedInterpTypesIndices, type)
                fromLocalInterpTypesIndicesToCombined[index] = index
            else
                fromLocalInterpTypesIndicesToCombined[index] = table.index(
                        combinedInterpTypesIndices, type
                )
            end
        end)

        util.foreach(clipsMetadata.interpFieldsIndices, function(value, type)
            local combinedConcreteInterpFieldsIndices = combinedInterpFieldsIndices[type]

            local tbl = { }

            if not combinedConcreteInterpFieldsIndices then
                combinedInterpFieldsIndices[type] = table.copy(value)

                util.foreach(value, function(_, fieldIndex)
                    tbl[fieldIndex] = fieldIndex
                end)
            else
                util.foreach(value, function(fieldName, fieldIndex)
                    if table.has(combinedConcreteInterpFieldsIndices, fieldName) then
                        tbl[fieldIndex] = table.index(combinedConcreteInterpFieldsIndices, fieldName)
                    else
                        combinedConcreteInterpFieldsIndices[fieldIndex] = fieldName
                        tbl[fieldIndex] = fieldIndex
                    end
                end)
            end

            fromLocalInterpFieldsIndicesToCombined[
                table.index(clipsMetadata.interpTypesIndices, type)
            ] = tbl
        end)

        util.foreach(clipsMetadata.bonesIndices, function(value, index)
            local combinedIndex

            if not table.has(combinedBonesIndices, value) then
                table.insert(combinedBonesIndices, value)
                combinedIndex = #combinedBonesIndices
            else
                combinedIndex = table.index(combinedBonesIndices, value)
            end

            fromLocalBoneIndexToCombined[index] = combinedIndex
        end)

        util.foreach(clipsMetadata.clips, function(clip)
            local combinedClip = {
                name = clip.name,
                loop = clip.loop,
                duration = clip.duration
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
                        util.foreach(transformsKeys[i], function(key)
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
                        end)
                    end

                    combinedBoneKeys[i] = combinedTransformKeys
                end

                combinedBonesKeys[fromLocalBoneIndexToCombined[localBoneIndex]] = combinedBoneKeys
            end

            combinedClip.bonesKeys = combinedBonesKeys

            table.insert(combinedClips, combinedClip)
        end)
    end)

    return {
        interpTypesIndices = combinedInterpTypesIndices,
        interpFieldsIndices = combinedInterpFieldsIndices,
        bonesIndices = combinedBonesIndices,
        clips = combinedClips
    }
end

return M