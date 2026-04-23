local util = require "util/util"
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

    util.foreach(clipsMetadata.interpTypesIndices, function(interpType, interpIndex)
        interpIndexToFunc[interpIndex] = interpolation.functions[interpType]
    end)

    self.fromLocalInterpFieldsIndexToGlobal = fromLocalInterpFieldsIndexToGlobal
    self.interpIndexToFunc = interpIndexToFunc

    return obj
end

function M:get_clip_by_index(index)
    return self.clipsMetadata.clips[index]
end

function M:get_clip_by_name(name)
    return self.clipsMetadata.clips[self:get_clip_index_by_name(name)]
end

function M:get_bone_index_in_clip(name, clipIndex)
    return table.index(self.clipsMetadata.clips[clipIndex].bonesIndices, name)
end

function M:get_clip_index_by_name(name)
    local index

    util.foreach(self.clipsMetadata.clips, function(clip, i)
        if clip.name == name then
            index = i
            return true
        end
    end)

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

function M:__map_interp_fields(interpTypeIndex, keyFields)
    local resultFields = { }

    for i = 1, #keyFields do
        resultFields[self.fromLocalInterpFieldsIndexToGlobal[interpTypeIndex][i]] = keyFields[i]
    end

    return unpack(resultFields)
end

function M:get_bone_transform_sample(boneIndex, currentTime, clipIndex, returnTable)
   local clip = self.clipsMetadata.clips[clipIndex]

    local looped, duration = clip.loop, clip.duration

    -- converting bone name to bone index
    if type(boneIndex) == "string" then
        boneIndex = table.index(clip.bonesKeys, boneIndex)
    end

    local transform = { } -- 1 - translate (vec3), 2 - rotation (quat), 3 - scale (vec3)

    local boneKeys = clip.bonesKeys[boneIndex]

    for i = 1, 3 do
        local transformKeys = boneKeys[i]

        if #transformKeys > 0 then
            local keyFrom, keyTo

            util.foreach(transformKeys, function(key, index)
                local keyTime = key[2]

                if keyTime > currentTime then
                    keyTo = key
                    keyFrom = transformKeys[index - 1]
                    return true
                end
            end)

            if not keyTo and not looped then
                transform[i] = transformKeys[#transformKeys][1]
            elseif not keyFrom and not looped then
                transform[i] = keyTo[1]
            else
                local keyToTime

                if not keyTo then
                    keyTo = transformKeys[1]
                    keyToTime = duration
                end

                if not keyFrom then
                    keyFrom = transformKeys[#transformKeys]
                end

                local keyFromTime = keyFrom[2]
                keyToTime = keyToTime or keyTo[2]
                local interpTypeIndex = keyFrom[3]

                local factor = (currentTime - keyFromTime) / (keyToTime - keyFromTime)

                local interpFunc = self.interpIndexToFunc[interpTypeIndex]

                local value

                if self.fromLocalInterpFieldsIndexToGlobal[interpTypeIndex] then
                    value = interpFunc(
                            keyFrom[1], keyTo[1], factor,
                            self:__map_interp_fields(interpTypeIndex, keyFrom[4])
                    )
                else
                    value = interpFunc(keyFrom[1], keyTo[1], factor)
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

    util.foreach(clip.bonesKeys, function(_, index)
        transforms[
            useIndicesInsteadNames and index or clip.bonesIndices[index]
        ] = self:get_bone_transform_sample(index, currentTime, clipIndex, true)
    end)

    return transforms
end

return M