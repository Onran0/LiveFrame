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

--[[

output table format:
{
    metadata = {
        relativizedTransforms = true,
        skeleton = {
            spine = {
                position = { 0, 0, 0 },
                rotation = { 1, 0, 0, 0 },
                scale = { 1, 1, 1 }
            },
            head = {
                position = { 0, 0, 0 },
                rotation = { 1, 0, 0, 0 },
                scale = { 1, 1, 1 }
            }
        }
    },

    -- indices for interpolation types
    interpTypesIndices = {
        lerp,
        ["cubic-spline"],
        slerp
    },

    -- indices for specific fields of some interpolation types
    -- sets order for array in third field in transform keys
    interpFieldsIndices = {
        ["cubic-spline"] = {
            "start-tangent",
            "end-tangent"
        }
    },

    -- indices for bones
    bonesIndices = {
        "spine",
        "head"
    },

    clips = {
        {
            name = "some_clip",
            loop = true,
            duration = 2,

            affectedBones = { 1 }, -- indices of affected bones

            events = {
                {
                    name = "event1",
                    time = 1
                },
                {
                    name = "event1",
                    value = { 1, 2, 3, 5 }",
                    time = 2
                }
            },

            bonesKeys = {
                -- first bone (with index 1)
                -- arrays of position, rotation and scale keys
                {
                    -- position keys
                    {
                        -- first position key
                        {
                            { 0, 0, 0 }, -- value
                            0, -- time of the key in seconds
                            2, -- output interpolation type index
                            { { 5, 0, 0 }, { 10, 0, 0 } } -- values of interpolation fields (if needed)
                        },
                        {
                            { 0, 1, 0 },
                            0.5,
                            1
                        },
                        { -- if output interpolation defined in last key,
                          -- they will be ignored, because the next key doesn't exist
                            { 0, 2, 0 },
                            1
                        },
                    },
                    -- rotation keys
                    {
                        { { 0, 0, 0, 1 }, 0, 3 }, -- as values u can pass only quaternions
                        { { -1, 1, 0.32, 0.98 }, 0.5 }
                    },
                    -- scale keys (here's no one)
                    { }
                },
                 -- for bones which undefined in LFA will auto generate default keys.
                 -- these bones indices will not be added into affectedBones field.
                 -- also, if bone transform defined, but one component is missing,
                 -- for it will auto generate default key.
                {
                    {
                        {
                            { 0, 0, 0 },
                            0
                        }
                    },
                    {
                        {
                            { 1, 0, 0, 0 },
                            0
                        }
                    },
                    {
                        {
                            { 1, 1, 1 },
                            0
                        }
                    }
                }
            }
        }
    }
}
]]--

local constants = require "general_constants"

local KEY_TYPE_POSITION = 1
local KEY_TYPE_ROTATION = 2
local KEY_TYPE_SCALE = 3

local quat_math = require "util/math/quat_math"

local structure_parser = require "lfa/structure_parser"
local analyzer = require "lfa/analyzer"

local place_default_bones_transforms = require "util/place_default_bones_transforms"

local function getKeyDataForAutoCalculation(keys, duration, loop, index)
    local k

    if not loop or index >= 1 and index <= #keys then
        k = keys[index]
    else
        if #keys > 2 then
            if index == #keys + 1 then
                local key = keys[2]

                return
                keys[#keys][constants.KEY_TIME_INDEX] +
                        (key[constants.KEY_TIME_INDEX] - keys[1][constants.KEY_TIME_INDEX]),
                key[constants.KEY_VALUE_INDEX]
            elseif index == 0 then
                local key = keys[#keys - 1]

                return keys[1][constants.KEY_TIME_INDEX] - (duration - key[constants.KEY_TIME_INDEX]), key[constants.KEY_VALUE_INDEX]
            else return end
        else return end
    end

    return k[constants.KEY_TIME_INDEX], k[constants.KEY_VALUE_INDEX]
end

local function getSquadControlQuat(keys, index, duration, loop)
    local t_prev, q_prev = getKeyDataForAutoCalculation(keys, duration, loop, index - 1)
    local t_curr, q_curr = getKeyDataForAutoCalculation(keys, duration, loop, index)
    local t_next, q_next = getKeyDataForAutoCalculation(keys, duration, loop, index + 1)

    if not q_prev or not q_curr or not q_next then
        return quat_math.idt()
    end

    local dt1 = t_curr - t_prev
    local dt2 = t_next - t_curr

    if dt1 <= 0 then dt1 = 1.0 end
    if dt2 <= 0 then dt2 = 1.0 end

    if quat_math.dot(q_prev, q_curr) < 0 then q_prev = quat_math.negate(q_prev) end
    if quat_math.dot(q_next, q_curr) < 0 then q_next = quat_math.negate(q_next) end

    local q_inv = quat_math.inverse(q_curr)

    local log_prev = quat_math.log(
            quat_math.mul(
                    q_inv,
                    q_prev
            )
    )

    local log_next = quat_math.log(
            quat_math.mul(
                    q_inv,
                    q_next
            )
    )

    local w_prev = -dt2 / (2 * (dt1 + dt2))
    local w_next = -dt1 / (2 * (dt1 + dt2))

    return quat_math.mul(
            q_curr,
            quat_math.exp(
                    quat_math.add(
                            quat_math.scale(log_prev, w_prev),
                            quat_math.scale(log_next, w_next)
                    )

            )
    )
end

local function getHermiteTangentsByCatmullrom(keys, index, duration, loop)
    local t_prev, p_prev = getKeyDataForAutoCalculation(keys, duration, loop, index - 1)
    local t_curr, p_curr = getKeyDataForAutoCalculation(keys, duration, loop, index)
    local t_next, p_next = getKeyDataForAutoCalculation(keys, duration, loop, index + 1)

    local inTangent, outTangent = { 0, 0, 0 }, { 0, 0, 0}

    if p_prev and p_next then
        local dt = t_next - t_prev
        if dt > 0 then
            local tangent = vec3.div(vec3.sub(p_next, p_prev), dt)

            local d1 = vec3.sub(p_curr, p_prev)
            local d2 = vec3.sub(p_next, p_curr)

            if vec3.dot(d1, d2) <= 0 then
                tangent = { 0, 0, 0 }
            end

            inTangent = tangent
            outTangent = tangent
        end
    elseif p_prev then
        local dt = t_curr - t_prev
        if dt > 0 then
            inTangent = vec3.div(vec3.sub(p_curr, p_prev), dt)
        end
    elseif p_next then
        local dt = t_next - t_curr
        if dt > 0 then
            outTangent = vec3.div(vec3.sub(p_next, p_curr), dt)
        end
    end

    return { inTangent, outTangent }
end

local autoComputeInterpsTypes = {
    [analyzer.interpCubicSpline] = function(keys, index, duration, loop)
        local t_curr = getKeyDataForAutoCalculation(keys, duration, loop, index)
        local t_next = getKeyDataForAutoCalculation(keys, duration, loop, index + 1)

        if not t_next then
            return { ["start-tangent"] = { 0, 0, 0 }, ["end-tangent"] = { 0, 0, 0 } }
        end

        local startTangent = getHermiteTangentsByCatmullrom(keys, index, duration, loop)[2]
        local endTangent = getHermiteTangentsByCatmullrom(keys, index + 1, duration, loop)[1]

        -- tangents normalization
        local dt = t_next - t_curr

        startTangent = vec3.mul(startTangent, dt)
        endTangent = vec3.mul(endTangent, dt)

        return {
            ["start-tangent"] = startTangent,
            ["end-tangent"] = endTangent
        }
    end,

    [analyzer.interpSquad] = function(keys, index, duration, loop)
        local nextInd = index + 1

        if loop and not keys[nextInd] then
            nextInd = 1
        end

        return {
            ["start-control"] = getSquadControlQuat(keys, index, duration, loop),
            ["end-control"] = getSquadControlQuat(keys, nextInd, duration, loop)
        }
    end
}

local M = { }

local function eulerToQuat(euler, order)
    if order == "xyz" then
        return quat.from_euler(euler)
    end

    local m = mat4.idt()

    for i = #order, 1, -1 do
        local axis = { 0, 0, 0 }

        local ind = ("xyz"):find(order[i])

        axis[ind] = 1

        m = mat4.mul(m, mat4.rotate(axis, euler[ind]))
    end

    return quat.from_mat4(m)
end

local function loadFromTable(lfaTable, loadSettings)
    local interpTypesIndices = { }
    local interpFieldsIndices = { }
    local bonesIndices = { }

    local eulerOrder = lfaTable.metadata.eulerOrder
    local relativizeTransforms

    if loadSettings.relativizeTransforms ~= nil then
        relativizeTransforms = loadSettings.relativizeTransforms
    else
        relativizeTransforms = lfaTable.metadata.relativizeTransforms
    end

    local skeleton = table.deep_copy(lfaTable.skeleton)

    for _, value in pairs(skeleton) do
        if #value.rotation == 3 then
            value.rotation = eulerToQuat(value.rotation, eulerOrder)
        else
            value.rotation = quat_math.normalize(quat_math.from_xyzw(value.rotation))
        end

        value.invRotation = quat_math.conj(value.rotation)
    end

    local clips = { }

    local function createOrGetInterpFieldsIndices(type)
        local fieldsIndices

        if not interpFieldsIndices[type] then
            fieldsIndices = { }

            for name, _ in pairs(analyzer.requiredCustomizableInterpTypesFields[type]) do
                table.insert(fieldsIndices, name)
            end

            interpFieldsIndices[type] = fieldsIndices
        else
            fieldsIndices = interpFieldsIndices[type]
        end

        return fieldsIndices
    end

    local function getInterpTypeAndFields(
            rawType, -- possibly a custom interp id, as well as a default interp type
            base, -- base for fields relativization (for rotation is inverted for higher load speed)
            keyTime, -- key time
            keyVal, -- value of key (may relativized),
            keyType,
            nextKeyTime -- next key time (may be nil)
    )
        if not table.has(analyzer.allDefaultInterpTypes, rawType) then
            local customId = rawType
            local type = lfaTable.interps[customId].type

            local fieldsIndices = createOrGetInterpFieldsIndices(type)

            local plainFields = { }

            for name, value in pairs(lfaTable.interps[customId].fields) do
                if type == analyzer.interpSquad then
                    value = quat_math.normalize(quat_math.from_xyzw(value))
                end

                if relativizeTransforms then
                    if type == analyzer.interpSquad then
                        value = quat_math.mul(base, value)

                        if quat_math.dot(value, keyVal) < 0 then
                            value = quat_math.negate(value)
                        end
                    elseif type == analyzer.interpCubicSpline and keyType == KEY_TYPE_SCALE then
                        value = vec3.div(value, base)
                    end
                end

                -- hermit tangents normalization
                if type == analyzer.interpCubicSpline and nextKeyTime then
                    value = vec3.mul(value, nextKeyTime - keyTime)
                end

                plainFields[table.index(fieldsIndices, name)] = value
            end

            return table.index(interpTypesIndices, type), plainFields
        else
            return table.index(interpTypesIndices, rawType)
        end
    end

    local deferredAutoComputeInterpsFields = { }

    local function tryAddToAutoComputeList(keys, type, loop, duration, fields)
        type = interpTypesIndices[type]

        if not fields and autoComputeInterpsTypes[type] then
            table.insert(deferredAutoComputeInterpsFields, {
                type = type,
                loop = loop,
                duration = duration,
                keys = keys,
                index = #keys
            })
        end
    end

    for clipName, lfaClip in pairs(lfaTable.clips) do
        local bonesKeys = { }
        local affectedBones = { }
        local events = { }

        local keyframes = lfaClip.keyframes

        for i = 1, #keyframes do
            local keyframe = keyframes[i]
            local nextKeyframe = keyframes[i + 1]

            local time = keyframe.time

            local nextTime

            if nextKeyframe then
                nextTime = nextKeyframe.time
            end

            for _, event in ipairs(keyframe.events) do
                table.insert(events, {
                    name = event.name,
                    value = event.value,
                    time = time
                })
            end

            for _, bone in pairs(keyframe.bones) do
                local boneName = bone.name

                table.insert_unique(bonesIndices, boneName)
                table.insert_unique(affectedBones, table.index(bonesIndices, boneName))

                local idxInBonesKeys = table.index(bonesIndices, boneName)
                local boneKeys = bonesKeys[idxInBonesKeys]

                if not boneKeys then
                    boneKeys = { { }, { }, { } }
                    bonesKeys[idxInBonesKeys] = boneKeys
                end

                local bonePosition, boneRotation, boneScale = bone.position, bone.rotation, bone.scale
                local positionKeys, rotationKeys, scaleKeys = boneKeys[constants.POSITION_KEYS_INDEX],
                                                              boneKeys[constants.ROTATION_KEYS_INDEX],
                                                              boneKeys[constants.SCALE_KEYS_INDEX]

                local function addInterpTypes(transform)
                    local interpType = transform.interpolation

                    if not table.has(analyzer.allDefaultInterpTypes, interpType) then
                        interpType = lfaTable.interps[interpType].type
                    end

                    table.insert_unique(interpTypesIndices, interpType)
                end

                local function addToKeys(keys, transform, value, base, keyType)
                    local type, fields

                    type, fields = getInterpTypeAndFields(transform.interpolation, base, time, value, keyType, nextTime)

                    table.insert(keys, {
                        value,
                        time,
                        type, fields
                    })

                    tryAddToAutoComputeList(keys, type, lfaClip.loop, lfaClip.duration, fields)
                end

                if bonePosition then
                    addInterpTypes(bonePosition)

                    addToKeys(
                            positionKeys, bonePosition,
                            relativizeTransforms and
                            vec3.sub(bonePosition.value, skeleton[boneName].position) or
                            bonePosition.value,
                            skeleton[boneName].position,
                            KEY_TYPE_POSITION
                    )
                end

                if boneRotation then
                    addInterpTypes(boneRotation)

                    local quatRot

                    if #boneRotation.value == 3 then
                        quatRot = eulerToQuat(boneRotation.value, eulerOrder)
                    else
                        quatRot = quat_math.normalize(quat_math.from_xyzw(boneRotation.value))
                    end

                    if relativizeTransforms then
                        if quat_math.dot(quatRot, skeleton[boneName].rotation) < 0 then
                            quatRot = quat_math.negate(quatRot)
                        end

                        quatRot = quat_math.mul(skeleton[boneName].invRotation, quatRot)
                    end

                    addToKeys(rotationKeys, boneRotation, quatRot, skeleton[boneName].invRotation, KEY_TYPE_ROTATION)

                    local len = #rotationKeys

                    if len > 1 then
                        if quat_math.dot(
                                rotationKeys[len][constants.KEY_VALUE_INDEX],
                                rotationKeys[len-1][constants.KEY_VALUE_INDEX]
                            ) < 0
                        then
                            rotationKeys[len][constants.KEY_VALUE_INDEX] = quat_math.negate(rotationKeys[len][constants.KEY_VALUE_INDEX])
                        end
                    end
                end

                if boneScale then
                    addInterpTypes(boneScale)
                    addToKeys(
                            scaleKeys, boneScale,
                            relativizeTransforms and
                            vec3.div(boneScale.value, skeleton[boneName].scale) or
                            boneScale.value,
                            skeleton[boneName].scale,
                            KEY_TYPE_SCALE
                    )
                end
            end
        end

        table.insert(clips, {
            name = clipName,
            loop = lfaClip.loop,
            duration = lfaClip.duration,
            affectedBones = affectedBones,
            events = events,
            bonesKeys = bonesKeys
        })
    end

    for _, deferredRequest in ipairs(deferredAutoComputeInterpsFields) do
        local type = deferredRequest.type
        local loop = deferredRequest.loop
        local duration = deferredRequest.duration
        local keys = deferredRequest.keys
        local index = deferredRequest.index

        local plainFields = { }

        for name, value in pairs(autoComputeInterpsTypes[type](keys, index, duration, loop)) do
            plainFields[table.index(createOrGetInterpFieldsIndices(type), name)] = value
        end

        keys[index][constants.KEY_INTERP_FIELDS_INDEX] = plainFields
    end

    for _, boneBindPose in pairs(lfaTable.skeleton) do
        local rotation = boneBindPose.rotation

        if #rotation == 3 then
            rotation = eulerToQuat(rotation, eulerOrder)
        else
            rotation = quat_math.from_xyzw(rotation)
        end

        boneBindPose.rotation = rotation
    end

    place_default_bones_transforms(clips, bonesIndices, relativizeTransforms, lfaTable.skeleton)

    return
    {
        metadata = {
            relativizedTransforms = relativizeTransforms,
            skeleton = lfaTable.skeleton
        },
        interpTypesIndices = interpTypesIndices,
        interpFieldsIndices = interpFieldsIndices,
        bonesIndices = bonesIndices,
        clips = clips
    }
end

function M.load(value, loadSettings)
    local t = type(value)

    if t == 'table' then
        if value.clips and value.interps then -- check for pure LFA table
            return loadFromTable(value, loadSettings)
        else -- passing analyzed structure
            return loadFromTable(analyzer.analyze(value), loadSettings)
        end
    else
        return loadFromTable(analyzer.analyze(structure_parser.parse(value)), loadSettings)
    end
end

return M