local util = require "util/util"

local M = { }

function M.combine(clipsMetadataArray, overrideClipsNames)
    if #clipsMetadataArray < 2 then
        return clipsMetadataArray and clipsMetadataArray[1]
    end

    local combinedInterpTypesIndices = { }
    local combinedInterpFieldsIndices = { }
    local combinedClips = { }

    util.foreach(clipsMetadataArray, function(clipsMetadata, clipsMetadataIndex)
        local fromLocalInterpTypesIndicesToCombined = { }
        local fromLocalInterpFieldsIndicesToCombined = { }

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

        util.foreach(clipsMetadata.clips, function(clip)
            local combinedClip = table.copy(clip)

            -- clip name overriding
            if
                overrideClipsNames and
                overrideClipsNames[clipsMetadataIndex] and
                overrideClipsNames[clipsMetadataIndex][combinedClip.name]
            then
                combinedClip.name = overrideClipsNames[clipsMetadataIndex][combinedClip.name]
            end

            -- converting interpolation type and fields indices from local metadata space to combined
            util.foreach(combinedClip.bonesKeys, function(transformsKeys)
                for i = 1, 3 do
                    if transformsKeys[i] and #transformsKeys[i] > 0 then
                        util.foreach(transformsKeys[i], function(key)
                            local localInterpTypeIndex = key[3]

                            if localInterpTypeIndex then
                                key[3] = fromLocalInterpTypesIndicesToCombined[localInterpTypeIndex]
                            end

                            if key[4] then
                                local localFieldsValues = key[4]
                                local combinedFieldsValues = { }

                                for j = 1, #localFieldsValues do
                                    combinedFieldsValues[
                                        fromLocalInterpFieldsIndicesToCombined[localInterpTypeIndex][j]
                                    ] = localFieldsValues[j]
                                end

                                key[4] = combinedFieldsValues
                            end
                        end)
                    end
                end
            end)

            table.insert(combinedClips, combinedClip)
        end)
    end)

    return {
        interpTypesIndices = combinedInterpTypesIndices,
        interpFieldsIndices = combinedInterpFieldsIndices,
        clips = combinedClips
    }
end

return M