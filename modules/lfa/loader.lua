--[[

output table format:
{
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
            "in-tangent",
            "out-tangent"
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
                }
            }
        }
    }
}
]]--

local quat_math = require "util/math/quat_math"

local util = require "util/util"

local structure_parser = require "lfa/structure_parser"
local analyzer = require "lfa/analyzer"

local function getControlQuat(keys, index, loop)
    local k_curr = keys[index]

    if not k_curr then return quat_math.idt() end

    local k_prev = keys[index - 1]
    local k_next = keys[index + 1]

    if not k_prev then
        if loop then
            k_prev = keys[#keys]
        else
            k_prev = k_curr
        end
    end

    if not k_next then
        if loop then
            k_next = keys[1]
        else
            k_next = k_curr
        end
    end

    local q_curr = k_curr[1]
    local q_prev = k_prev[1]
    local q_next = k_next[1]

    local q_inv = quat_math.inverse(q_curr)

    return quat_math.mul(
            q_curr,
            quat_math.exp(
                    quat_math.scale(
                            quat_math.add(
                                    quat_math.log(
                                            quat_math.mul(
                                                    q_inv,
                                                    q_prev
                                            )
                                    ),
                                    quat_math.log(
                                            quat_math.mul(
                                                    q_inv,
                                                    q_next
                                            )
                                    )
                            ),
                            -0.25
                    )

            )
    )
end

local autoComputeInterpsTypes = {
    ["cubic-spline"] = function(keys, index, duration, loop)
        local k_prev = keys[index - 1]
        local k_curr = keys[index]
        local k_next = keys[index + 1]

        if not k_curr then
            return { ["in-tangent"] = {0,0,0}, ["out-tangent"] = {0,0,0} }
        end

        local t_curr = k_curr[2]
        local t_prev, t_next

        if not k_prev and loop then
            k_prev = keys[#keys]
            t_prev = t_curr - (duration - k_prev[2])
        end

        if not k_next and loop then
            k_next = keys[1]
            t_next = duration
        end

        local p_prev = k_prev and k_prev[1]
        local p_curr = k_curr[1]
        local p_next = k_next and k_next[1]

        t_prev = t_prev or (k_prev and k_prev[2])
        t_next = t_prev or (k_next and k_next[2])

        local inTangent  = {0,0,0}
        local outTangent = {0,0,0}

        if p_prev then
            local dt = t_curr - t_prev
            if dt > 0 then
                inTangent = vec3.div(vec3.sub(p_curr, p_prev), dt)
            end
        end

        if p_next then
            local dt = t_next - t_curr
            if dt > 0 then
                outTangent = vec3.div(vec3.sub(p_next, p_curr), dt)
            end
        end

        if p_prev and p_next then
            local dt = t_next - t_prev
            if dt > 0 then
                local tangent = vec3.div(vec3.sub(p_next, p_prev), dt)

                local d1 = vec3.sub(p_curr, p_prev)
                local d2 = vec3.sub(p_next, p_curr)

                if vec3.dot(d1, d2) <= 0 then
                    tangent = {0,0,0}
                end

                inTangent  = tangent
                outTangent = tangent
            end
        end

        return {
            ["in-tangent"] = inTangent,
            ["out-tangent"] = outTangent
        }
    end,

    ["squad"] = function(keys, index, _, loop)
        return {
            ["in-control"] = getControlQuat(keys, index, loop),
            ["out-control"] = getControlQuat(keys, index + 1, loop)
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

local function loadFromTable(lfaTable)
    local interpTypesIndices = { }
    local interpFieldsIndices = { }
    local bonesIndices = { }

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
            rawType -- possibly a custom interp id, as well as a default interp type
    )
        if not table.has(analyzer.allDefaultInterpTypes, rawType) then
            local customId = rawType
            local type = lfaTable.interps[customId].type

            local fieldsIndices = createOrGetInterpFieldsIndices(type)

            local plainFields = { }
            for name, value in pairs(lfaTable.interps[customId].fields) do
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

        util.foreach(lfaClip.keyframes, function(keyframe)
            local time = keyframe.time

            util.foreach(keyframe.bones, function(bone)
                table.insert_unique(bonesIndices, bone.name)
                local idxInBonesKeys = table.index(bonesIndices, bone.name)
                local boneKeys = bonesKeys[idxInBonesKeys]

                if not boneKeys then
                    boneKeys = { { }, { }, { } }
                    bonesKeys[idxInBonesKeys] = boneKeys
                end

                local bonePosition, boneRotation, boneScale = bone.position, bone.rotation, bone.scale
                local positionKeys, rotationKeys, scaleKeys = boneKeys[1], boneKeys[2], boneKeys[3]

                local function addInterpTypes(transform)
                    util.foreach({
                        transform.interpolation.input,
                        transform.interpolation.output
                    }, function(interpType)
                        if not table.has(analyzer.allDefaultInterpTypes, interpType) then
                            interpType = lfaTable.interps[interpType].type
                        end

                        table.insert_unique(interpTypesIndices, interpType)
                    end)
                end

                local function addToKeys(keys, transform, value)
                    local type, fields

                    if transform.interpolation.input and #keys > 0 then
                        type, fields = getInterpTypeAndFields(transform.interpolation.input)

                        keys[#keys][3] = type
                        keys[#keys][4] = fields

                        tryAddToAutoComputeList(keys, type, lfaClip.loop, fields)
                    end

                    type, fields = getInterpTypeAndFields(transform.interpolation.output)

                    table.insert(keys, {
                        value or transform.value,
                        time,
                        type, fields
                    })

                    tryAddToAutoComputeList(keys, type, lfaClip.loop, fields)
                end

                if bonePosition then
                    addInterpTypes(bonePosition)
                    addToKeys(positionKeys, bonePosition)
                end

                if boneRotation then
                    addInterpTypes(boneRotation)

                    local quatRot

                    if #boneRotation.value == 3 then
                        quatRot = eulerToQuat(boneRotation.value, lfaClip.eulerOrder)
                    else
                        quatRot = quat_math.from_xyzw(boneRotation.value)
                    end

                    addToKeys(rotationKeys, boneRotation, quatRot)
                end

                if boneScale then
                    addInterpTypes(boneScale)
                    addToKeys(scaleKeys, boneScale)
                end
            end)
        end)

        table.insert(clips, {
            name = clipName,
            loop = lfaClip.loop,
            duration = lfaClip.duration,
            bonesKeys = bonesKeys
        })
    end

    util.foreach(deferredAutoComputeInterpsFields, function(deferredRequest)
        local type = deferredRequest.type
        local loop = deferredRequest.loop
        local duration = deferredRequest.duration
        local keys = deferredRequest.keys
        local index = deferredRequest.index

        local plainFields = { }

        for name, value in pairs(autoComputeInterpsTypes[type](keys, index, duration, loop)) do
            plainFields[table.index(createOrGetInterpFieldsIndices(type), name)] = value
        end

        keys[index][4] = plainFields
    end)

    return
    {
        interpTypesIndices = interpTypesIndices,
        interpFieldsIndices = interpFieldsIndices,
        bonesIndices = bonesIndices,
        clips = clips
    }
end

function M.load(value)
    local t = type(value)

    if t == 'table' then
        if value.clips and value.interps then -- check for pure LFA table
            return loadFromTable(value)
        else -- passing analyzed structure
            return loadFromTable(analyzer.analyze(value))
        end
    else
        return loadFromTable(analyzer.analyze(structure_parser.parse(value)))
    end
end

return M