--[[
lfaTable - is a validated and fully correct table with animations and
custom interpolations.

all values are specified explicitly, with no defaults, except the interpolation.input,
this field will not be assigned to default if value not specified explicitly.

the @scope element is completely stripped, and any interpolation attributes
are finalized to the interpolation table in each transformation.

all this is for the convenience of the final LFA animation loader and
predictable behavior.

output lfaTable structure:
{
    interps = {
        ["custom"] = {
            id = "custom",
            type = "squad",
            fields = {
                ["in-control"] = { 0, -1, 0, 1 },
                ["out-control"] = { 0, -1, 0, 1 }
            }
        }
    },

    animations = {
        ["main"] = {
            name = "main",
            eulerOrder = "xyz",
            loop = true,
            duration = 2, -- in seconds
            keyframes = {
                {
                    time = 0,
                    bones = {
                        {
                            name = "spine",
                            position = {
                                value = { 0, 0, 0 },
                                interpolation = {
                                    output = "lerp"
                                }
                            },
                            rotation = {
                                value = { 0, 0, 0 },
                                interpolation = {
                                    input = "nlerp",
                                    output = "slerp"
                                }
                            }
                        }
                    }
                },
                {
                    time = 1,
                    bones = {
                        {
                            name = "spine",
                            position = {
                                value = { 1, 1, 1 },
                                interpolation = {
                                    input = "lerp",
                                    output = "lerp"
                                }
                            },
                            rotation = {
                                value = { 45, 45, 90 },
                                interpolation = {
                                    input = "nlerp",
                                    output = "slerp"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
]]--

-- elements types

local INTERP_TYPE = "interp"
local INTERP_FIELD_TYPE = "field"
local ANIMATION_TYPE = "animation"

local KEYFRAME_TYPE = "keyframe"

local SCOPE_TYPE = "scope"
local BONE_TYPE = "bone"
local TRIGGER_TYPE = "trigger"

local POSITION_TYPE = "position"
local ROTATION_TYPE = "rotation"
local SCALE_TYPE = "scale"

-- attributes names

local ATTR_INTERP = "interp"
local ATTR_IN_INTERP = "in-interp"
local ATTR_OUT_INTERP = "out-interp"

local ATTR_ROTATION_INTERP = "rotation-interp"
local ATTR_IN_ROTATION_INTERP = "in-rotation-interp"
local ATTR_OUT_ROTATION_INTERP = "out-rotation-interp"

local ATTR_NAME = "name"
local ATTR_TIME = "time"
local ATTR_VALUE = "value"

local ATTR_LOOP = "loop"

local ATTR_EULER_ORDER = "euler-order"

local ATTR_ID = "id"
local ATTR_TYPE = "type"

-- attributes values types

local VALUE_TYPE_NUMBER = "number"
local VALUE_TYPE_BOOLEAN = "boolean"
local VALUE_TYPE_STRING = "string"
local VALUE_TYPE_VEC3 = "vec3"
local VALUE_TYPE_QUAT = "quat"

-- interpolation types

local INTERP_LERP = "lerp"
local INTERP_CUBIC_SPLINE = "cubic-spline"

local INTERP_NLERP = "nlerp"
local INTERP_SLERP = "slerp"
local INTERP_SQUAD = "squad"

local INTERP_STEP = "step"

-- fields of customizable interpolation types

local CUBIC_SPLINE_IN_TANGENT = "in-tangent"
local CUBIC_SPLINE_OUT_TANGENT = "out-tangent"

local SQUAD_IN_CONTROL = "in-control"
local SQUAD_OUT_CONTROL = "out-control"

-- elements types array

local types = {
    INTERP_TYPE,
    INTERP_FIELD_TYPE,
    ANIMATION_TYPE,
    KEYFRAME_TYPE,
    SCOPE_TYPE,
    BONE_TYPE,
    TRIGGER_TYPE,
    POSITION_TYPE,
    ROTATION_TYPE,
    SCALE_TYPE
}

-- interpolation types array

local interpTypes = {
    INTERP_LERP,
    INTERP_CUBIC_SPLINE,

    INTERP_NLERP,
    INTERP_SLERP,
    INTERP_SQUAD,

    INTERP_STEP
}

--

local possibleElementsInRoot = { ANIMATION_TYPE, INTERP_TYPE }

local possibleChildrenTypes = {
    [INTERP_TYPE] = { INTERP_FIELD_TYPE },
    [ANIMATION_TYPE] = { KEYFRAME_TYPE },
    [KEYFRAME_TYPE] = { SCOPE_TYPE, BONE_TYPE, TRIGGER_TYPE },
    [SCOPE_TYPE] = { SCOPE_TYPE, BONE_TYPE },
    [BONE_TYPE] = { POSITION_TYPE, ROTATION_TYPE, SCALE_TYPE },
}

local possibleAttributes = {
    [INTERP_TYPE] = {
        [ATTR_ID] = VALUE_TYPE_STRING,
        [ATTR_TYPE] = VALUE_TYPE_STRING
    },
    [INTERP_FIELD_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,
        [ATTR_VALUE] = {
            VALUE_TYPE_QUAT, VALUE_TYPE_VEC3,
            VALUE_TYPE_NUMBER, VALUE_TYPE_BOOLEAN,
            VALUE_TYPE_STRING
        }
    },
    [ANIMATION_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,
        [ATTR_EULER_ORDER] = VALUE_TYPE_STRING,
        [ATTR_LOOP] = VALUE_TYPE_BOOLEAN
    },
    [KEYFRAME_TYPE] = {
        [ATTR_TIME] = VALUE_TYPE_NUMBER
    },
    [SCOPE_TYPE] = {
        [ATTR_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_INTERP] = VALUE_TYPE_STRING,
        [ATTR_ROTATION_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_ROTATION_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_ROTATION_INTERP] = VALUE_TYPE_STRING
    },
    [BONE_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,
        [ATTR_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_INTERP] = VALUE_TYPE_STRING,
        [ATTR_ROTATION_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_ROTATION_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_ROTATION_INTERP] = VALUE_TYPE_STRING
    },
    [TRIGGER_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,
        [ATTR_VALUE] = {
            VALUE_TYPE_NUMBER,
            VALUE_TYPE_BOOLEAN,
            VALUE_TYPE_STRING,
            VALUE_TYPE_VEC3,
            VALUE_TYPE_QUAT
        }
    },
    [POSITION_TYPE] = {
        [ATTR_VALUE] = VALUE_TYPE_VEC3,
        [ATTR_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_INTERP] = VALUE_TYPE_STRING,
    },
    [ROTATION_TYPE] = {
        [ATTR_VALUE] = { VALUE_TYPE_VEC3, VALUE_TYPE_QUAT },
        [ATTR_ROTATION_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_ROTATION_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_ROTATION_INTERP] = VALUE_TYPE_STRING
    },
    [SCALE_TYPE] = {
        [ATTR_VALUE] = VALUE_TYPE_VEC3,
        [ATTR_INTERP] = VALUE_TYPE_STRING,
        [ATTR_IN_INTERP] = VALUE_TYPE_STRING,
        [ATTR_OUT_INTERP] = VALUE_TYPE_STRING,
    }
}

local requiredAttributes = {
    [INTERP_TYPE] = { ATTR_ID, ATTR_TYPE },
    [INTERP_FIELD_TYPE] = { ATTR_NAME, ATTR_VALUE },
    [ANIMATION_TYPE] = { ATTR_NAME },
    [KEYFRAME_TYPE] = { ATTR_TIME },
    [SCOPE_TYPE] = { },
    [BONE_TYPE] = { ATTR_NAME },
    [TRIGGER_TYPE] = { ATTR_NAME },
    [POSITION_TYPE] = { ATTR_VALUE },
    [ROTATION_TYPE] = { ATTR_VALUE },
    [SCALE_TYPE] = { ATTR_VALUE }
}

local defaultInterpTypes = {
    INTERP_LERP,
    INTERP_CUBIC_SPLINE,
    INTERP_STEP
}

local defaultRotationInterpTypes = {
    INTERP_NLERP,
    INTERP_SLERP,
    INTERP_SQUAD,
    INTERP_STEP
}

local interpAttributes = {
    ATTR_INTERP,
    ATTR_IN_INTERP,
    ATTR_OUT_INTERP
}

local rotationInterpAttributes = {
    ATTR_ROTATION_INTERP,
    ATTR_IN_ROTATION_INTERP,
    ATTR_OUT_ROTATION_INTERP
}

local allInterpAttributes = table.merge(table.copy(interpAttributes), rotationInterpAttributes)

local allowedCustomizableInterpTypes = {
    INTERP_CUBIC_SPLINE,
    INTERP_SQUAD
}

local requiredCustomizableInterpTypesFields = {
    [INTERP_CUBIC_SPLINE] = {
        [CUBIC_SPLINE_IN_TANGENT] = VALUE_TYPE_VEC3,
        [CUBIC_SPLINE_OUT_TANGENT] = VALUE_TYPE_VEC3
    },
    [INTERP_SQUAD] = {
        [SQUAD_IN_CONTROL] = VALUE_TYPE_QUAT,
        [SQUAD_OUT_CONTROL] = VALUE_TYPE_QUAT
    }
}

local M = {
    allDefaultInterpTypes = interpTypes,

    defaultTransformInterpTypes = defaultInterpTypes,
    defaultRotationInterpTypes = defaultRotationInterpTypes,

    requiredCustomizableInterpTypesFields = requiredCustomizableInterpTypesFields
}

local function validateAndGetValueType(value)
    local type = type(value)

    if type == 'number' then
        return VALUE_TYPE_NUMBER
    elseif type == 'string' then
        return VALUE_TYPE_STRING
    elseif type == 'table' then
        if #value == 3 then
            return VALUE_TYPE_VEC3
        elseif #value == 4 then
            for i = 1, 4 do
                local comp = value[i]

                if comp > 1 or comp < -1 then
                    error("invalid quaternion component: " .. comp)
                end
            end

            return VALUE_TYPE_QUAT
        else error('invalid array size: ' .. #value) end
    elseif type == 'boolean' then
        return VALUE_TYPE_BOOLEAN
    else error('invalid value type: ' .. value) end
end

local function analyzeElementSpecial(element, lfaTable)
    --- interpolation types analyze ---
    if element.type == SCOPE_TYPE or
       element.type == BONE_TYPE or
       element.type == POSITION_TYPE or
       element.type == ROTATION_TYPE or
       element.type == SCALE_TYPE
    then
        local function checkInterpAttributes(attributesList, defaultTypes, oppositeTypes, usingScope)
            for i = 1, #attributesList do
                local interpAttr = element.attributes[attributesList[i]]

                if interpAttr and not table.has(defaultTypes, interpAttr) then
                    local msg = "interpolation '" .. interpAttr .. "' can't be used for " .. usingScope

                    if table.has(oppositeTypes, interpAttr) then
                        error(msg)
                    elseif not lfaTable.interps[interpAttr] then
                        error("unknown interpolation '" .. interpAttr .. "'")
                    elseif not table.has(defaultTypes, lfaTable.interps[interpAttr].type) then
                        error("custom " .. msg)
                    end
                end
            end
        end

        if element.type ~= ROTATION_TYPE then
            checkInterpAttributes(interpAttributes, defaultInterpTypes, defaultRotationInterpTypes, 'position or scale')
        end

        if element.type ~= POSITION_TYPE and element.type ~= SCALE_TYPE then
            checkInterpAttributes(rotationInterpAttributes, defaultRotationInterpTypes, defaultInterpTypes, 'rotation')
        end
    end
    --- ---

    if element.type == INTERP_TYPE then
        local id = element.attributes[ATTR_ID]

        if lfaTable.interps[id] then
            error("custom interp with id '" .. id .. "' already declared")
        end

        if table.has(interpTypes, id) then
            error("custom interp can't have id '" .. id .. "' because it used by default interpolation type")
        end

        local interpType = element.attributes[ATTR_TYPE]

        local errorPrefix = "(at custom interp" .. id .. "):"

        if not table.has(allowedCustomizableInterpTypes, interpType) then
            error(errorPrefix .. "interpolation type '" .. interpType .. "' is not customizable")
        end

        local interpTable = {
            id = id,
            type = interpType,
            fields = { }
        }

        local requiredFields = requiredCustomizableInterpTypesFields[interpType]

        for i = 1, #element.children do
            local field = element.children[i]

            local name = field.attributes[ATTR_NAME]

            if interpTable.fields[name] then
                error(errorPrefix .. "field with name '" .. name "' already declared")
            end

            if not requiredFields[name] then
                error(errorPrefix .. "interpolation type '" .. interpType .. "' haven't field with name '" .. name .. "'")
            end

            local value = field.attributes[ATTR_VALUE]
            local requiredValueType = requiredFields[name]

            if requiredValueType ~= validateAndGetValueType(value) then
                error(
                        errorPrefix .. "in interpolation type '" .. interpType .. "' field '"
                                .. name .. "' must have type '" .. requiredValueType .. "'"
                )
            end

            interpTable.fields[name] = value
        end

        for name, _ in pairs(requiredFields) do
            if not interpTable.fields[name] then
                error(errorPrefix .. "missing required field: '" .. name .. "'")
            end
        end

        lfaTable.interps[id] = interpTable
    elseif
        element.type == POSITION_TYPE or
        element.type == ROTATION_TYPE or
        element.type == SCALE_TYPE
    then
        local animation = lfaTable.temp.animationByElement[element]
        local keyframe = lfaTable.temp.keyframeByElement[element]
        local tempBone = lfaTable.temp.boneByTransform[element]
        local bone = keyframe.bones[tempBone.name]

        local errorPrefix = "(animation: " .. animation.name ..
                ", keyframe time: " .. keyframe.time .. ", bone name: " .. bone.name .. ") "

        if element.children then
            error(errorPrefix .. "transformation elements can't have children")
        end

        local attrs = element.attributes

        local transformTable = {
            value = attrs[ATTR_VALUE],
            interpolation = { }
        }

        if element.type == ROTATION_TYPE then
            transformTable.interpolation.input = attrs[ATTR_IN_ROTATION_INTERP]
                    or attrs[ATTR_ROTATION_INTERP]
                    or tempBone.in_rotation_interp

            transformTable.interpolation.output = attrs[ATTR_OUT_ROTATION_INTERP]
                    or attrs[ATTR_ROTATION_INTERP]
                    or tempBone.out_rotation_interp
                    or INTERP_NLERP
        else
            transformTable.interpolation.input = attrs[ATTR_IN_INTERP] or attrs[ATTR_INTERP] or tempBone.in_interp

            transformTable.interpolation.output = attrs[ATTR_OUT_INTERP] or attrs[ATTR_INTERP] or tempBone.out_interp
                                       or INTERP_LERP
        end

        bone[element.type] = transformTable
    elseif element.type == BONE_TYPE then
        local animationByElement = lfaTable.temp.animationByElement
        local keyframeByElement = lfaTable.temp.keyframeByElement

        local animation = lfaTable.temp.animationByElement[element]
        local keyframe = lfaTable.temp.keyframeByElement[element]

        local name = element.attributes[ATTR_NAME]

        local errorPrefix = "(animation: " .. animation.name ..
                ", keyframe time: " .. keyframe.time .. ", bone name: " .. name .. ") "

        if keyframe.bones[name] then
            error(errorPrefix .. "bone with same name already declared in this keyframe")
        end

        keyframe.bones[name] = {
            name = name
        }

        local parentScope = lfaTable.temp.scopeByBone[element] or { }

        local attrs = element.attributes

        local boneTempTable = {
            name = name,

            in_interp = attrs[ATTR_IN_INTERP] or attrs[ATTR_INTERP] or parentScope.in_interp,
            out_interp = attrs[ATTR_OUT_INTERP] or attrs[ATTR_INTERP] or parentScope.out_interp,

            in_rotation_interp = attrs[ATTR_IN_ROTATION_INTERP] or attrs[ATTR_ROTATION_INTERP]
                                                                or parentScope.in_rotation_interp,

            out_rotation_interp = attrs[ATTR_OUT_ROTATION_INTERP] or attrs[ATTR_ROTATION_INTERP]
                                                                  or parentScope.out_rotation_interp,
        }

        local boneByTransform = { }

        local hasTransform = { }

        for i = 1, #element.children do
            local child = element.children[i]

            if hasTransform[child.type] then
                error(errorPrefix .. child.type .. " already declared in this bone")
            else
                hasTransform[child.type] = true
            end

            boneByTransform[child] = boneTempTable
            keyframeByElement[child] = keyframe
            animationByElement[child] = animation
        end

        if table.count_pairs(hasTransform) == 0 then
            error(errorPrefix .. " bone can't be declared without any transforms (position, rotation or scale)")
        end

        lfaTable.temp.boneByTransform = table.merge(
                lfaTable.temp.boneByTransform or {},
                boneByTransform
        )
    elseif element.type == SCOPE_TYPE then
        local animationByElement = lfaTable.temp.animationByElement
        local keyframeByElement = lfaTable.temp.keyframeByElement

        local animation = lfaTable.temp.animationByElement[element]
        local keyframe = lfaTable.temp.keyframeByElement[element]

        local inheritedInterpAttribs = { }

        local scopeNode = element

        while scopeNode.type == SCOPE_TYPE do
            for i = 1, #allInterpAttributes do
                local attrName = allInterpAttributes[i]

                if
                    scopeNode.attributes[attrName] ~= nil and
                    not inheritedInterpAttribs[attrName]
                then
                    inheritedInterpAttribs[attrName] = scopeNode.attributes[attrName]
                end
            end

            scopeNode = scopeNode.parent
        end

        local scopeTempTable = {
            in_interp = inheritedInterpAttribs[ATTR_IN_INTERP] or inheritedInterpAttribs[ATTR_INTERP],
            out_interp = inheritedInterpAttribs[ATTR_OUT_INTERP] or inheritedInterpAttribs[ATTR_INTERP],

            in_rotation_interp = inheritedInterpAttribs[ATTR_IN_ROTATION_INTERP] or
                    inheritedInterpAttribs[ATTR_ROTATION_INTERP],

            out_rotation_interp = inheritedInterpAttribs[ATTR_OUT_ROTATION_INTERP] or
                    inheritedInterpAttribs[ATTR_ROTATION_INTERP]
        }

        local scopeByBone = { }

        for i = 1, #element.children do
            local child = element.children[i]

            if child.type == BONE_TYPE then
                scopeByBone[child] = scopeTempTable
            end

            keyframeByElement[child] = keyframe
            animationByElement[child] = animation
        end

        lfaTable.temp.scopeByBone = table.merge(
                lfaTable.temp.scopeByBone or {},
                scopeByBone
        )
    elseif element.type == KEYFRAME_TYPE then
        local animationByElement = lfaTable.temp.animationByElement
        local animation = animationByElement[element]

        local time = element.attributes[ATTR_TIME]

        local errorPrefix = "(animation: " .. animation.name ..
                ", keyframe time: " .. time .. ") "

        if not element.children or #element.children == 0 then
            error(errorPrefix .. "keyframe can't be without children")
        end

        local keyframeTable = {
            time = time,
            bones = { }
        }

        local keyframeByElement = { }

        for i = 1, #element.children do
            local child = element.children[i]

            keyframeByElement[child] = keyframeTable
            animationByElement[child] = animation
        end

        table.insert(animation.keyframes, keyframeTable)

        lfaTable.temp.keyframeByElement = table.merge(
                lfaTable.temp.keyframeByElement or {},
                keyframeByElement
        )
    elseif element.type == ANIMATION_TYPE then
        local name = element.attributes[ATTR_NAME]

        if lfaTable.animations[name] then
            error("animation with name '" .. name .. "' already declared")
        end

        local errorPrefix = "(animation: " .. name .. ") "

        local eulerOrder = element.attributes[ATTR_EULER_ORDER]

        if element.attributes[ATTR_EULER_ORDER] then
            local counts = { 0, 0, 0 }

            for i = 1, #eulerOrder do
                local char = eulerOrder[i]

                local ind = ("xyz"):find(char)

                if not ind then
                    error(errorPrefix .. 'invalid euler-order')
                else
                    counts[ind] = counts[ind] + 1
                end
            end

            for i = 1, #counts do
                local count = counts[i]

                if count == 0 or count > 1 then
                    error(errorPrefix .. 'invalid euler-order')
                end
            end
        end

        local loop

        if element.attributes[ATTR_LOOP] then
            loop = true
        else
            loop = false
        end

        local animationTable = {
            name = name,
            eulerOrder = eulerOrder or 'xyz',
            loop = loop,
            keyframes = { }
        }

        if not element.children or #element.children == 0 then
            error(errorPrefix .. "animation can't be without children")
        end

        local animationByElement = { }

        local previousTime = -1
        local maxTime = 0

        for i = 1, #element.children do
            local keyframe = element.children[i]

            local time = keyframe.attributes[ATTR_TIME]

            if time < 0 then
                error(errorPrefix .. "negative keyframe time: " .. time)
            end

            if previousTime > time then
                error(errorPrefix .. "invalid keyframes order in animation. please sort keyframes by ascending time")
            elseif previousTime == time then
                error(errorPrefix .. "keyframe with time " .. time .. " already declared")
            end

            if previousTime == -1 and time > 0 then
                error(errorPrefix .. "first keyframe time must be 0")
            end

            maxTime = math.max(maxTime, time)

            previousTime = time

            animationByElement[keyframe] = animationTable
        end

        animationTable.duration = maxTime

        lfaTable.animations[name] = animationTable

        lfaTable.temp.animationByElement = table.merge(
                lfaTable.temp.animationByElement or {},
                animationByElement
        )
    end

    if element.children and #element.children then
        for i = 1, #element.children do
            analyzeElementSpecial(element.children[i], lfaTable)
        end
    end
end

local function analyzeElementGeneral(element)
    local elementType = element.type

    if not table.has(types, elementType) then
        error("unknown element type '" .. elementType .. "'")
    end

    local possibleChildren = possibleChildrenTypes[elementType]
    local possibleAttribs = possibleAttributes[elementType]

    for attrName, attrValue in pairs(element.attributes) do
        if not possibleAttribs[attrName] then
            error("attribute '" .. attrName .. "' is not defined for elements of type '" .. elementType .. "'")
        end

        local requiredType = possibleAttribs[attrName]
        local valueType = validateAndGetValueType(attrValue)

        local unmatch = false

        if type(requiredType) == "table" then
            unmatch = not table.has(requiredType, valueType)
        else
            unmatch = requiredType ~= valueType
        end

        if unmatch then
            local msg = "attribute '" .. attrName .. "' in elements of type '" .. elementType .. "' must have a value of "

            if type(requiredType) == "table" then
                error(msg .. "one of next types: '" .. table.concat(requiredType, ', ') .. "'")
            else
                error(msg .. "type '" .. requiredType .. "'")
            end
        end
    end

    for i = 1, #requiredAttributes[elementType] do
        local requiredAttrib = requiredAttributes[elementType][i]

        if not element.attributes[requiredAttrib] then
            error("missing required attribute '" .. requiredAttrib .. "' for element of type '" .. elementType .. "'")
        end
    end

    if possibleChildren and element.children and #element.children then
        for i = 1, #element.children do
            local child = element.children[i]

            if not table.has(possibleChildren, child.type) then
                error("element of type '" .. child.type .. "' can't be a child of '" .. elementType .. "'")
            end

            analyzeElementGeneral(child)
        end
    end
end

function M.analyze(structureTable)
    local lfaTable = {
        animations = { },
        interps = { },
        temp = { }
    }

    local sortedStructureTable = { }

    for i = 1, #structureTable do
        local e = structureTable[i]

        if e.type == INTERP_TYPE then
            table.insert(sortedStructureTable, e)
        end
    end

    for i = 1, #structureTable do
        local e = structureTable[i]

        if e.type == ANIMATION_TYPE then
            table.insert(sortedStructureTable, e)
        end
    end

    for i = 1, #sortedStructureTable do
        local element = sortedStructureTable[i]

        if not table.has(possibleElementsInRoot, element.type) then
            error("elements with type '" .. element.type .. "' can't be declared in the root")
        else
            analyzeElementGeneral(element)
            analyzeElementSpecial(element, lfaTable)
        end
    end

    lfaTable.temp = nil

    return lfaTable
end

return M