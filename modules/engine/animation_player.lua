local util = require "util/util"
local interpolation = require "engine/interpolation"

local M = { }

M.__index = M

function M:new(animationsMetadata, skeleton)
    local obj = {
        animationsMetadata = animationsMetadata,
        skeleton = skeleton,
        time = 0,
        speed = 1,
        paused = false,
        looped = false
    }

    setmetatable(obj, self)

    local fromLocalInterpFieldsIndexToGlobal = { }

    for interpType, interpFields in pairs(animationsMetadata.interpFieldsIndices) do
        local t = { }

        for i, interpField in ipairs(interpFields) do
            t[i] = table.index(interpolation.customFieldsIndices[interpType], interpField)
        end

        fromLocalInterpFieldsIndexToGlobal[
            table.index(animationsMetadata.interpTypesIndices, interpType)
        ] = t
    end

    local interpIndexToFunc = { }

    util.foreach(animationsMetadata.interpTypesIndices, function(interpType, interpIndex)
        interpIndexToFunc[interpIndex] = interpolation.functions[interpType]
    end)

    self.fromLocalInterpFieldsIndexToGlobal = fromLocalInterpFieldsIndexToGlobal
    self.interpIndexToFunc = interpIndexToFunc

    return obj
end

function M:__update_rig_indices()
    if not self.playingAnimation then
        self.animBoneIndexToRigIndex = nil
        return
    end

    local animation = self.animationsMetadata.animations[self.playingAnimation]

    local animBoneIndexToRigIndex = { }

    util.foreach(animation.boneIndices, function(boneName, boneIndex)
        animBoneIndexToRigIndex[boneIndex] = self.skeleton:index(boneName)
    end)

    self.animBoneIndexToRigIndex = animBoneIndexToRigIndex
end

function M:set_skeleton(skeleton)
    self.skeleton = skeleton

    self:__update_rig_indices()
end

function M:play(name)
    local index

    util.foreach(self.animationsMetadata.animations, function(anim, i)
        if anim.name == name then
            index = i
            return true
        end
    end)

    if not index then error("undefined animation: '" .. name .. "'") end

    self:play_by_index(index)
end

function M:play_by_index(index)
    local animation = self.animationsMetadata.animations[index]

    self.duration = animation.duration
    self.looped = animation.loop
    self.paused = false
    self.time = 0

    self.playingAnimation = index

    self:__update_rig_indices()
end

function M:get_playing_animation()
    if self.playingAnimation then
        return self.animationsMetadata.animations[self.playingAnimation].name
    end
end

function M:get_playing_animation_index()
    return self.playingAnimation
end

function M:get_animation_duration()
    return self.duration
end

function M:is_paused()
    return self.paused
end

function M:stop()
    self.animBoneIndexToRigIndex = nil

    self.paused = false
    self.time = 0
    self.duration = nil

    self.playingAnimation = nil
end

function M:pause()
    self.paused = true
end

function M:resume()
    self.paused = false
end

function M:get_time()
    return self.time
end

function M:set_time(time)
    self.time = time
end

function M:get_speed()
    return self.speed
end

function M:set_speed(speed)
    self.speed = speed
end

function M:is_looped()
    return self.looped
end

function M:set_loop(looped)
    self.looped = looped
end

function M:__map_interp_fields(interpTypeIndex, keyFields)
    local resultFields = { }

    for i = 1, #keyFields do
        resultFields[self.fromLocalInterpFieldsIndexToGlobal[interpTypeIndex][i]] = keyFields[i]
    end

    return unpack(resultFields)
end

function M:get_bone_transform_sample(boneIndex, currentTime, animation, returnTable)
    if not animation then
        animation = self.animationsMetadata.animations[self.playingAnimation]
    end

    -- converting bone name to bone index
    if type(boneIndex) == "string" then
        boneIndex = table.index(animation.bonesKeys, boneIndex)
    end

    if not currentTime then
        currentTime = self.time
    end

    local looped = self.looped

    local transform = { } -- 1 - translate (vec3), 2 - rotation (quat), 3 - scale (vec3)

    local boneKeys = animation.bonesKeys[boneIndex]

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
                    keyToTime = self.duration
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

function M:get_transforms_sample(currentTime, animation, useIndicesInsteadNames)
    if not animation then
        animation = self.animationsMetadata.animations[self.playingAnimation]
    end

    if not currentTime then
        currentTime = self.time
    end

    local transforms = { }

    util.foreach(animation.bonesKeys, function(name, index)
        transforms[
            useIndicesInsteadNames and index or name
        ] = self:get_bone_transform_sample(index, currentTime, animation)
    end)

    return transforms
end

function M:step(delta)
    if not self.playingAnimation or self.paused then
        return
    elseif not self.looped and (self.time >= self.duration or (self.time < 0 and delta < 0)) then
        return
    elseif delta == 0 then
        return
    end

    local animation = self.animationsMetadata.animations[self.playingAnimation]

    local currentTime = self.time + delta * self.speed

    if self.looped then
        currentTime = currentTime % self.duration
    end

    util.foreach(
            self:get_transforms_sample(currentTime, animation, true),
            function(index, transform)
        local boneMatrix

        if transform[1] then
            boneMatrix = mat4.translate(transform[1])
        else
            boneMatrix = mat4.idt()
        end

        if transform[2] then
            boneMatrix = mat4.mul(boneMatrix, mat4.from_quat(transform[2]))
        end

        if transform[3] then
            boneMatrix = mat4.mul(boneMatrix, mat4.scale(transform[3]))
        end

        self.skeleton:set_matrix(self.animBoneIndexToRigIndex[index], boneMatrix)
    end)

    self.time = currentTime
end

return M