local constants = require "general_constants"

local interpolation = require "engine/interpolation"

local M = { }

M.__index = M

function M:new(clipsMetadata)
    local obj = {
        clipsMetadata = clipsMetadata
    }

    setmetatable(obj, self)

    local fromLocalInterpFieldsIndexToGlobal = { }

    for interpType, interpFields in pairs(clipsMetadata.interpFieldsIndices) do
        local t = { }

        for i, interpField in ipairs(interpFields) do
            t[i] = table.index(interpolation.customFieldsIndices[interpType], interpField)
        end

        fromLocalInterpFieldsIndexToGlobal[
            table.index(clipsMetadata.interpTypesIndices, interpType)
        ] = t
    end

    local interpIndexToFunc = { }

    for interpIndex, interpType in ipairs(clipsMetadata.interpTypesIndices) do
        interpIndexToFunc[interpIndex] = interpolation.functions[interpType]
    end

    self.fromLocalInterpFieldsIndexToGlobal = fromLocalInterpFieldsIndexToGlobal
    self.interpIndexToFunc = interpIndexToFunc

    return obj
end

function M:__map_interp_fields(interpTypeIndex, keyFields)
    local resultFields = { }

    for i = 1, #keyFields do
        resultFields[self.fromLocalInterpFieldsIndexToGlobal[interpTypeIndex][i]] = keyFields[i]
    end

    return unpack(resultFields)
end

function M:get_clips_metadata()
    return self.clipsMetadata
end

function M:get_clip_by_index(index)
    return self.clipsMetadata.clips[index]
end

function M:get_clip_by_name(name)
    return self.clipsMetadata.clips[self:get_clip_index_by_name(name)]
end

function M:get_bone_index_in_meta(name)
    return table.index(self.clipsMetadata.bonesIndices, name)
end

function M:get_clip_index_by_name(name)
    local index

    for i, clip in ipairs(self.clipsMetadata.clips) do
        if clip.name == name then
            index = i
            break
        end
    end

    return index
end

function M:get_clip_name_by_index(index)
    return self.clipsMetadata.clips[index].name
end

function M:is_clip_looped(index)
    return self.clipsMetadata.clips[index].loop
end

function M:get_clip_duration(index)
    return self.clipsMetadata.clips[index].duration
end

function M:get_bone_transform_sample(boneIndex, currentTime, clipIndex, returnTable)
    local clip = self.clipsMetadata.clips[clipIndex]

    local looped, duration = clip.loop, clip.duration

    local transform = { } -- 1 - translate (vec3), 2 - rotation (quat), 3 - scale (vec3)

    local boneKeys = clip.bonesKeys[boneIndex]

    for i = 1, 3 do
        local transformKeys = boneKeys[i]

        if transformKeys and #transformKeys > 0 then
            local keyFrom, keyTo

            for index, key in ipairs(transformKeys) do
                local keyTime = key[constants.KEY_TIME_INDEX]

                if keyTime > currentTime then
                    keyTo = key
                    keyFrom = transformKeys[index - 1]
                    break
                end
            end

            if not keyTo and not looped then
                transform[i] = transformKeys[#transformKeys][constants.KEY_VALUE_INDEX]
            elseif not keyFrom and not looped then
                transform[i] = keyTo[constants.KEY_VALUE_INDEX]
            else
                local keyToTime

                if not keyTo then
                    keyTo = transformKeys[1]
                    keyToTime = duration
                end

                if not keyFrom then
                    keyFrom = transformKeys[#transformKeys]
                end

                local keyFromTime = keyFrom[constants.KEY_TIME_INDEX]
                keyToTime = keyToTime or keyTo[constants.KEY_TIME_INDEX]
                local interpTypeIndex = keyFrom[constants.KEY_INTERP_TYPE_INDEX]

                local factor = (currentTime - keyFromTime) / (keyToTime - keyFromTime)

                local interpFunc = self.interpIndexToFunc[interpTypeIndex] or interpolation.functions.step

                local value

                if self.fromLocalInterpFieldsIndexToGlobal[interpTypeIndex] then
                    value = interpFunc(
                            keyFrom[constants.KEY_VALUE_INDEX], keyTo[constants.KEY_VALUE_INDEX], factor,
                            self:__map_interp_fields(
                                    interpTypeIndex, keyFrom[constants.KEY_INTERP_FIELDS_INDEX]
                            )
                    )
                else
                    value = interpFunc(
                            keyFrom[constants.KEY_VALUE_INDEX], keyTo[constants.KEY_VALUE_INDEX],
                            factor
                    )
                end

                transform[i] = value
            end
        end
    end

    if not returnTable then
        return transform[1], transform[2], transform[3]
    else
        return transform
    end
end

function M:get_transforms_sample(currentTime, clipIndex, useIndicesInsteadNames)
    local clip = self.clipsMetadata.clips[clipIndex]

    local transforms = { }

    for index, _ in pairs(clip.bonesKeys) do
        transforms[
        useIndicesInsteadNames and index or self.clipsMetadata.bonesIndices[index]
        ] = self:get_bone_transform_sample(index, currentTime, clipIndex, true)
    end

    return transforms
end

return M