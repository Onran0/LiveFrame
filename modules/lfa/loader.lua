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

    animations = {
        -- animations in array stored as indices
        {
            name = "some_anim",

            -- indices for bones
            boneIndices = {
                "spine",
                "head"
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
                }
            }
        }
    }
}
]]--

local quat_math = require "math/quat_math"

local util = require "util"

local structure_parser = require "lfa/structure_parser"
local analyzer = require "lfa/analyzer"

local function getKeyValue(keys, index)
    if keys[index] then return keys[index][1] end
end

local autoComputeInterpsTypes = {
    ["cubic-spline"] = function(keys, index)
        local p_prev = getKeyValue(keys, index - 1)
        local p_curr = getKeyValue(keys, index)
        local p_next = getKeyValue(keys, index + 1)

        if not p_curr then
            return { }
        end

        local t

        if p_prev and p_next then
            t = vec3.mul(vec3.sub(p_next, p_prev), 0.5)
        elseif p_next then
            t = vec3.sub(p_next, p_curr)
        elseif p_prev then
            t = vec3.sub(p_curr, p_prev)
        else
            t = { 0, 0, 0 }
        end

        return {
            ["in-tangent"] = t,
            ["out-tangent"] = t
        }
    end,

    ["squad"] = function(keys, index)
        local q_prev = getKeyValue(keys, index - 1)
        local q_curr = getKeyValue(keys, index)
        local q_next = getKeyValue(keys, index + 1)

        if not q_curr then
            return quat_math.idt(), quat_math.idt()
        end

        local function align(a, b)
            if quat_math.dot(a, b) < 0 then
                return -b
            end
            return b
        end

        local inControl
        local outControl

        if q_next then
            local qn = align(q_curr, q_next)
            local inv = quat_math.inverse(q_curr)

            local log_next = quat_math.log(quat_math.mul(inv, qn))

            local log_prev

            if q_prev then
                local qp = align(q_curr, q_prev)
                log_prev = quat_math.log(quat_math.mul(inv, qp))
            else
                log_prev = quat_math.idt_log()
            end

            local avg = quat_math.scale(quat_math.add(log_next, log_prev), -0.25)
            outControl = quat_math.mul(q_curr, quat_math.exp(avg))
        else
            outControl = q_curr
        end

        if q_prev then
            local qp = align(q_curr, q_prev)
            local inv = quat_math.inverse(q_curr)

            local log_prev = quat_math.log(quat_math.mul(inv, qp))

            local log_next
            if q_next then
                local qn = align(q_curr, q_next)
                log_next = quat_math.log(quat_math.mul(inv, qn))
            else
                log_next = quat_math.idt_log()
            end

            local avg = quat_math.scale(quat_math.add(log_prev, log_next), -0.25)
            inControl = quat_math.mul(q_curr, quat_math.exp(avg))
        else
            inControl = q_curr
        end

        return {
            ["in-control"] = inControl,
            ["out-control"] = outControl
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

    local animations = { }

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

    local function tryAddToAutoComputeList(keys, type, fields)
        type = interpTypesIndices[type]

        if not fields and autoComputeInterpsTypes[type] then
            table.insert(deferredAutoComputeInterpsFields, {
                type = type,
                keys = keys,
                index = #keys
            })
        end
    end

    for animationName, lfaAnimation in pairs(lfaTable.animations) do
        local boneIndices = { }
        local bonesKeys = { }

        util.foreach(lfaAnimation.keyframes, function(keyframe)
            local time = keyframe.time

            util.foreach(keyframe.bones, function(bone)
                table.insert_unique(boneIndices, bone.name)
                local idxInBonesKeys = table.index(boneIndices, bone.name)
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

                        tryAddToAutoComputeList(keys, type, fields)
                    end

                    type, fields = getInterpTypeAndFields(transform.interpolation.output)

                    table.insert(keys, {
                        value or transform.value,
                        time,
                        type, fields
                    })

                    tryAddToAutoComputeList(keys, type, fields)
                end

                if bonePosition then
                    addInterpTypes(bonePosition)
                    addToKeys(positionKeys, bonePosition)
                end

                if boneRotation then
                    addInterpTypes(boneRotation)

                    local quatRot

                    if #boneRotation.value == 3 then
                        quatRot = eulerToQuat(boneRotation.value, lfaAnimation.eulerOrder)
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

        table.insert(animations, {
            name = animationName,
            boneIndices = boneIndices,
            bonesKeys = bonesKeys
        })
    end

    util.foreach(deferredAutoComputeInterpsFields, function(deferredRequest)
        local type = deferredRequest.type
        local keys = deferredRequest.keys
        local index = deferredRequest.index

        local plainFields = { }

        for name, value in pairs(autoComputeInterpsTypes[type](keys, index)) do
            plainFields[table.index(createOrGetInterpFieldsIndices(type), name)] = value
        end

        keys[index][4] = plainFields
    end)

    return
    {
        interpTypesIndices = interpTypesIndices,
        interpFieldsIndices = interpFieldsIndices,
        animations = animations
    }
end

function M.load(value)
    local t = type(value)

    if t == 'table' then
        if value.animations and value.interps then -- check for pure LFA table
            return loadFromTable(value)
        else -- passing analyzed structure
            return loadFromTable(analyzer.analyze(value))
        end
    else
        return loadFromTable(analyzer.analyze(structure_parser.parse(value)))
    end
end

return M