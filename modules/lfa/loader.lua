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
            "in-tangent" = 1,
            "out-tangent" =  2
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

local util = require "util"

local structure_parser = require "lfa/structure_parser"
local analyzer = require "lfa/analyzer"

local M = { }

local function eulerToQuat(euler, order)
    if order == 'xyz' then
        return quat.from_euler(euler)
    end

    local m = mat4.idt()

    for i = 1, #order do
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
                        table.insert_unique(interpTypesIndices, interpType)
                    end)
                end

                local function addToKeys(keys, transform, value)
                    if transform.interpolation.input and #keys > 0 then
                        keys[#keys][3] = table.index(interpTypesIndices, transform.interpolation.input)
                    end

                    table.insert(keys, {
                        value or transform.value,
                        time,
                        table.index(interpTypesIndices, transform.interpolation.output)
                    })
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
                        quatRot = boneRotation.value
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