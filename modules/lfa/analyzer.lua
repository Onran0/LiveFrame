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
lfaTable - is a validated and fully correct table with clips and
custom interpolations.

all values are specified explicitly, with no defaults, except the interpolation.input,
this field will not be assigned to default if value not specified explicitly.

the @scope element is completely stripped, and any interpolation attributes
are finalized to the interpolation table in each transformation.

all this is for the convenience of the final LFA animation loader and
predictable behavior.

output lfaTable structure:
{
    metadata = {
        version = 1.0,
        eulerOrder = "xyz",
        relativizeTransforms = true
    },

    skeleton = {
        spine = {
            position = { 0, 0, 0 },
            rotation = { 0, 0, 0, 1 },
            scale = { 1, 1, 1 }
        }
    },

    interps = {
        ["custom"] = {
            id = "custom",
            type = "squad",
            fields = {
                ["start-control"] = { 0, -1, 0, 1 },
                ["end-control"] = { 0, -1, 0, 1 }
            }
        }
    },

    clips = {
        ["main"] = {
            name = "main",
            loop = true,
            duration = 2, -- in seconds
            keyframes = {
                {
                    time = 0,
                    events = {
                        {
                            name = "event1"
                        },
                        {
                            name = "event2",
                            value = 32"
                        }
                    },
                    bones = {
                        {
                            name = "spine",
                            position = {
                                value = { 0, 0, 0 },
                                interpolation = "lerp" -- output interpolation type
                            },
                            rotation = {
                                value = { 0, 0, 0 },
                                interpolation = "slerp"
                            }
                        }
                    }
                },
                {
                    time = 1,
                    events = { },
                    bones = {
                        {
                            name = "spine",
                            position = {
                                value = { 1, 1, 1 },
                                interpolation = "lerp"
                            },
                            rotation = {
                                value = { 45, 45, 90 },
                                interpolation = "lerp"
                            }
                        }
                    }
                }
            }
        }
    }
}
]]--

local CURRENT_VERSION = 1.0

local SUPPORTED_VERSIONS = {
    CURRENT_VERSION
}

-- elements types

local METADATA_TYPE = "metadata"
local SKELETON_TYPE = "skeleton"
local INTERP_TYPE = "interp"
local INTERP_FIELD_TYPE = "field"
local CLIP_TYPE = "clip"

local KEYFRAME_TYPE = "keyframe"

local SCOPE_TYPE = "scope"
local BONE_TYPE = "bone"
local EVENT_TYPE = "event"

local POSITION_TYPE = "position"
local ROTATION_TYPE = "rotation"
local SCALE_TYPE = "scale"

-- attributes names

local ATTR_VERSION = "version"
local ATTR_EULER_ORDER = "euler-order"
local ATTR_RELATIVIZE_TRANSFORMS = "relativize-transforms"

local ATTR_POSITION = "position"
local ATTR_ROTATION = "rotation"
local ATTR_SCALE = "scale"

local ATTR_INTERP = "interp"

local ATTR_NAME = "name"
local ATTR_TIME = "time"
local ATTR_VALUE = "value"

local ATTR_LOOP = "loop"
local ATTR_DURATION = "duration"

local ATTR_ID = "id"
local ATTR_TYPE = "type"
local ATTR_TARGET = "target"

-- attributes values types

local VALUE_TYPE_NUMBER = "number"
local VALUE_TYPE_BOOLEAN = "boolean"
local VALUE_TYPE_STRING = "string"
local VALUE_TYPE_VEC3 = "vec3"
local VALUE_TYPE_QUAT = "quat"
local VALUE_TYPE_OTHER = "other"

-- interpolation types

local INTERP_LERP = "lerp"
local INTERP_CUBIC_SPLINE = "cubic-spline"

local INTERP_NLERP = "nlerp"
local INTERP_SLERP = "slerp"
local INTERP_SQUAD = "squad"

local INTERP_STEP = "step"

-- fields of customizable interpolation types

local CUBIC_SPLINE_START_TANGENT = "start-tangent"
local CUBIC_SPLINE_END_TANGENT = "end-tangent"

local SQUAD_START_CONTROL = "start-control"
local SQUAD_END_CONTROL = "end-control"

-- elements types array

local types = {
    METADATA_TYPE,
    SKELETON_TYPE,
    INTERP_TYPE,
    INTERP_FIELD_TYPE,
    CLIP_TYPE,
    KEYFRAME_TYPE,
    SCOPE_TYPE,
    BONE_TYPE,
    EVENT_TYPE,
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

local interpApplyTable = {
    [INTERP_CUBIC_SPLINE] = {
        VALUE_TYPE_VEC3,
        VALUE_TYPE_QUAT
    },

    [INTERP_SQUAD] = {
        VALUE_TYPE_QUAT
    }
}

local defaultInterpTargetTable = {
    [INTERP_CUBIC_SPLINE] = VALUE_TYPE_VEC3,
    [INTERP_SQUAD] = VALUE_TYPE_QUAT
}

--

local possibleElementsInRoot = { METADATA_TYPE, SKELETON_TYPE, CLIP_TYPE, INTERP_TYPE }

local possibleChildrenTypes = {
    [SKELETON_TYPE] = { BONE_TYPE },
    [INTERP_TYPE] = { INTERP_FIELD_TYPE },
    [CLIP_TYPE] = { KEYFRAME_TYPE },
    [KEYFRAME_TYPE] = { SCOPE_TYPE, BONE_TYPE, EVENT_TYPE },
    [SCOPE_TYPE] = { SCOPE_TYPE, BONE_TYPE },
    [BONE_TYPE] = { POSITION_TYPE, ROTATION_TYPE, SCALE_TYPE },
}

local possibleAttributes = {
    [METADATA_TYPE] = {
        [ATTR_VERSION] = VALUE_TYPE_NUMBER,
        [ATTR_EULER_ORDER] = VALUE_TYPE_STRING,
        [ATTR_RELATIVIZE_TRANSFORMS] = VALUE_TYPE_BOOLEAN
    },
    [SKELETON_TYPE] = { },
    [INTERP_TYPE] = {
        [ATTR_ID] = VALUE_TYPE_STRING,
        [ATTR_TYPE] = VALUE_TYPE_STRING,
        [ATTR_TARGET] = VALUE_TYPE_STRING
    },
    [INTERP_FIELD_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,
        [ATTR_VALUE] = {
            VALUE_TYPE_QUAT, VALUE_TYPE_VEC3,
            VALUE_TYPE_NUMBER, VALUE_TYPE_BOOLEAN,
            VALUE_TYPE_STRING
        }
    },
    [CLIP_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,
        [ATTR_LOOP] = VALUE_TYPE_BOOLEAN,
        [ATTR_DURATION] = VALUE_TYPE_NUMBER
    },
    [KEYFRAME_TYPE] = {
        [ATTR_TIME] = VALUE_TYPE_NUMBER
    },
    [SCOPE_TYPE] = {
        [ATTR_INTERP] = VALUE_TYPE_OTHER
    },
    [BONE_TYPE] = {
        [ATTR_NAME] = VALUE_TYPE_STRING,

        -- in skeleton
        [ATTR_POSITION] = VALUE_TYPE_VEC3,
        [ATTR_ROTATION] = { VALUE_TYPE_VEC3, VALUE_TYPE_QUAT },
        [ATTR_SCALE] = VALUE_TYPE_VEC3
    },
    [EVENT_TYPE] = {
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
        [ATTR_INTERP] = VALUE_TYPE_STRING
    },
    [ROTATION_TYPE] = {
        [ATTR_VALUE] = { VALUE_TYPE_VEC3, VALUE_TYPE_QUAT },
        [ATTR_INTERP] = VALUE_TYPE_STRING
    },
    [SCALE_TYPE] = {
        [ATTR_VALUE] = VALUE_TYPE_VEC3,
        [ATTR_INTERP] = VALUE_TYPE_STRING,
        [ATTR_INTERP] = VALUE_TYPE_STRING,
    }
}

local requiredAttributes = {
    [METADATA_TYPE] = { ATTR_VERSION },
    [SKELETON_TYPE] = { },
    [INTERP_TYPE] = { ATTR_ID, ATTR_TYPE },
    [INTERP_FIELD_TYPE] = { ATTR_NAME, ATTR_VALUE },
    [CLIP_TYPE] = { ATTR_NAME },
    [KEYFRAME_TYPE] = { ATTR_TIME },
    [SCOPE_TYPE] = { ATTR_INTERP },
    [BONE_TYPE] = { ATTR_NAME },
    [EVENT_TYPE] = { ATTR_NAME },
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
    INTERP_CUBIC_SPLINE,
    INTERP_SQUAD,
    INTERP_STEP
}

local allowedCustomizableInterpTypes = {
    INTERP_CUBIC_SPLINE,
    INTERP_SQUAD
}

local requiredCustomizableInterpTypesFields = {
    [INTERP_CUBIC_SPLINE] = {
        [VALUE_TYPE_VEC3] = {
            [CUBIC_SPLINE_END_TANGENT] = VALUE_TYPE_VEC3,
            [CUBIC_SPLINE_START_TANGENT] = VALUE_TYPE_VEC3
        },
        [VALUE_TYPE_QUAT] = {
            [CUBIC_SPLINE_END_TANGENT] = VALUE_TYPE_QUAT,
            [CUBIC_SPLINE_START_TANGENT] = VALUE_TYPE_QUAT
        }
    },
    [INTERP_SQUAD] = {
        [VALUE_TYPE_QUAT] = {
            [SQUAD_END_CONTROL] = VALUE_TYPE_QUAT,
            [SQUAD_START_CONTROL] = VALUE_TYPE_QUAT
        }
    }
}

local allTransformChannelNames = {
    "position",
    "rotation",
    "scale"
}

local M = {
    allDefaultInterpTypes = interpTypes,

    defaultTransformInterpTypes = defaultInterpTypes,
    defaultRotationInterpTypes = defaultRotationInterpTypes,

    requiredCustomizableInterpTypesFields = requiredCustomizableInterpTypesFields,

    interpCubicSpline = INTERP_CUBIC_SPLINE,
    interpSquad = INTERP_SQUAD,

    VALUE_TYPE_VEC3 = VALUE_TYPE_VEC3,
    VALUE_TYPE_QUAT = VALUE_TYPE_QUAT
}

local function validateAndGetValueType(value)
    local type = type(value)

    if type == 'number' then
        return VALUE_TYPE_NUMBER
    elseif type == 'string' then
        return VALUE_TYPE_STRING
    elseif type == 'table' and #value == 3 then
        return VALUE_TYPE_VEC3
    elseif type == 'table' and #value == 4 then
        for i = 1, 4 do
            local comp = value[i]

            if comp > 1 or comp < -1 then
                error("invalid quaternion component: " .. comp)
            end
        end

        return VALUE_TYPE_QUAT
    elseif type == 'boolean' then
        return VALUE_TYPE_BOOLEAN
    else
        return VALUE_TYPE_OTHER
    end
end

local function analyzeElementSpecial(element, lfaTable)
    if not lfaTable.metadata then
        if element.type == METADATA_TYPE then
            local version = element.attributes[ATTR_VERSION]

            if not table.has(SUPPORTED_VERSIONS, version) then
                error("LFA files with format version " .. version .. " is not supported by this analyzer")
            end

            local eulerOrder = element.attributes[ATTR_EULER_ORDER]

            if eulerOrder then
                local counts = { 0, 0, 0 }

                for i = 1, #eulerOrder do
                    local char = eulerOrder[i]

                    local ind = ("xyz"):find(char)

                    if not ind then
                        error('invalid euler-order')
                    else
                        counts[ind] = counts[ind] + 1
                    end
                end

                for i = 1, #counts do
                    local count = counts[i]

                    if count == 0 or count > 1 then
                        error('invalid euler-order')
                    end
                end
            end

            local relativizeTransforms = true

            if element.attributes[ATTR_RELATIVIZE_TRANSFORMS] ~= nil then
                relativizeTransforms = element.attributes[ATTR_RELATIVIZE_TRANSFORMS]
            end

            if element.children then
                error("invalid @metadata structure")
            end

            lfaTable.metadata = {
                version = version,
                eulerOrder = eulerOrder or "xyz",
                relativizeTransforms = relativizeTransforms
            }
        else
            error("@metadata must be first element in file")
        end
    elseif element.type == METADATA_TYPE then
        error("metadata already declared in file")
    end

    --- interpolation types analyze ---
    if element.type == SCOPE_TYPE or
       element.type == POSITION_TYPE or
       element.type == ROTATION_TYPE or
       element.type == SCALE_TYPE
    then
        local function checkInterpolationType(interpAttr, defaultTypes, oppositeTypes, usingScope, forType)
            if interpAttr and not table.has(defaultTypes, interpAttr) then
                local msg = "interpolation '" .. interpAttr .. "' can't be used for " .. usingScope

                if table.has(oppositeTypes, interpAttr) then
                    error(msg)
                elseif not lfaTable.interps[interpAttr] then
                    error("unknown interpolation '" .. interpAttr .. "' (maybe custom declared after clip?)")
                else
                    local customInterp = lfaTable.interps[interpAttr]

                    if
                        not table.has(defaultTypes, customInterp.type) or
                        customInterp.target ~= forType
                    then
                        error("custom " .. msg)
                    end
                end
            end
        end

        local interpAttr = element.attributes[ATTR_INTERP]

        if element.type == SCOPE_TYPE then
            if interpAttr then
                local keyedInterpTable = { }

                for i = 1, #interpAttr do
                    local kv = interpAttr[i]

                    if
                        type(kv) ~= "table" or
                        is_array(kv) or
                        not table.has({ "position", "rotation", "scale" }, kv.key) or
                        type(kv.value) ~= "string"
                    then
                        error("invalid structure of 'interp' attribute in some @scope")
                    end

                    keyedInterpTable[kv.key] = kv.value
                end

                for _, interpType in ipairs({
                    "position", "scale"
                }) do
                    checkInterpolationType(keyedInterpTable[interpType],
                            defaultInterpTypes, defaultRotationInterpTypes, "position or scale", VALUE_TYPE_VEC3
                    )
                end

                checkInterpolationType(keyedInterpTable["rotation"],
                        defaultRotationInterpTypes, defaultInterpTypes, "rotation", VALUE_TYPE_QUAT
                )

                element.attributes[ATTR_INTERP] = keyedInterpTable
            end
        else
            if element.type == ROTATION_TYPE then
                checkInterpolationType(interpAttr, defaultRotationInterpTypes, defaultInterpTypes, "rotation", VALUE_TYPE_QUAT)
            else
                checkInterpolationType(interpAttr, defaultInterpTypes, defaultRotationInterpTypes, "position or scale", VALUE_TYPE_VEC3)
            end
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

        if #lfaTable.clips > 0 then
            error("custom interps must be declared before clips")
        end

        local interpType = element.attributes[ATTR_TYPE]

        local errorPrefix = "(at custom interp " .. id .. "):"

        if not table.has(allowedCustomizableInterpTypes, interpType) then
            error(errorPrefix .. "interpolation type '" .. interpType .. "' is not customizable")
        end

        local target = element.attributes[ATTR_TARGET]

        if target and not table.has(interpApplyTable[interpType], target) then
            error(errorPrefix .. "interpolation '" .. interpType .. "' is not applicable to " .. target)
        end

        target = target or defaultInterpTargetTable[interpType]

        local interpTable = {
            id = id,
            type = interpType,
            target = target,
            fields = { }
        }

        local requiredFields = requiredCustomizableInterpTypesFields[interpType][target]

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
                                .. name .. "' must have type '" .. requiredValueType .. "' with target '"
                                .. target .. "'"
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
        local clip = lfaTable.temp.clipByElement[element]
        local keyframe = lfaTable.temp.keyframeByElement[element]
        local tempBone = lfaTable.temp.boneByTransform[element]
        local bone = keyframe.bones[tempBone.name]

        local errorPrefix = "(clip: " .. clip.name ..
                ", keyframe time: " .. keyframe.time .. ", bone name: " .. bone.name .. ") "

        if element.children then
            error(errorPrefix .. "transformation elements can't have children")
        end

        local attrs = element.attributes

        local transformTable = {
            value = attrs[ATTR_VALUE]
        }

        if element.type == ROTATION_TYPE then
            transformTable.interpolation = attrs[ATTR_INTERP]
                    or tempBone.scopeInterpolation.rotation
                    or INTERP_NLERP
        else
            transformTable.interpolation = attrs[ATTR_INTERP]
                    or tempBone.scopeInterpolation[element.type == POSITION_TYPE and "position" or "scale"]
                    or INTERP_LERP
        end

        bone[element.type] = transformTable
    elseif element.type == SKELETON_TYPE then
        if lfaTable.skeleton then
            error("skeleton already declared in file")
        end

        if not element.children or #element.children == 0 then
            error("skeleton must have at least one bone")
        end

        lfaTable.skeleton = { }
    elseif element.type == BONE_TYPE then
        local parentIsSkeleton = element.parent.type == SKELETON_TYPE

        local attrs = element.attributes
        local name = element.attributes[ATTR_NAME]

        if parentIsSkeleton then
            local errorPrefix = "(bone '" .. name .. "' in skeleton) "

            if element.children then
                error(errorPrefix .. "bone in skeleton can't have children")
            end

            if lfaTable.skeleton[name] then
                error(errorPrefix .. "bone with name '" .. name .. "' already declared in skeleton")
            end

            lfaTable.skeleton[name] = {
                position = attrs[ATTR_POSITION] or { 0, 0, 0 },
                rotation = attrs[ATTR_ROTATION] or { 0, 0, 0, 1 },
                scale = attrs[ATTR_SCALE] or { 1, 1, 1 }
            }
        else
            local clipByElement = lfaTable.temp.clipByElement
            local keyframeByElement = lfaTable.temp.keyframeByElement

            local clip = lfaTable.temp.clipByElement[element]
            local keyframe = lfaTable.temp.keyframeByElement[element]

            local errorPrefix = "(clip: " .. clip.name ..
                    ", keyframe time: " .. keyframe.time .. ", bone name: '" .. name .. "') "

            if not lfaTable.skeleton[name] then
                error(errorPrefix .. "bone is not defined in skeleton")
            end

            if keyframe.bones[name] then
                error(errorPrefix .. "bone with same name already declared in this keyframe")
            end

            if attrs[ATTR_POSITION] or attrs[ATTR_ROTATION] or attrs[ATTR_SCALE] then
                error(errorPrefix .. "bone in keyframe can't have direct transform attributes")
            end

            keyframe.bones[name] = {
                name = name
            }

            local parentScope = lfaTable.temp.scopeByBone and lfaTable.temp.scopeByBone[element] or { }

            local boneTempTable = {
                name = name,

                scopeInterpolation = parentScope.interpolation
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
                clipByElement[child] = clip
            end

            if table.count_pairs(hasTransform) == 0 then
                error(errorPrefix .. " bone can't be declared without any transforms (position, rotation or scale)")
            end

            lfaTable.temp.boneByTransform = table.merge(
                    lfaTable.temp.boneByTransform or {},
                    boneByTransform
            )
        end
    elseif element.type == SCOPE_TYPE then
        local clipByElement = lfaTable.temp.clipByElement
        local keyframeByElement = lfaTable.temp.keyframeByElement

        local clip = lfaTable.temp.clipByElement[element]
        local keyframe = lfaTable.temp.keyframeByElement[element]

        local inheritedInterpTypes = { }

        local scopeNode = element

        while scopeNode.type == SCOPE_TYPE do
            for i = 1, #allTransformChannelNames do
                local channelName = allTransformChannelNames[i]

                if
                    scopeNode.attributes[ATTR_INTERP] and
                    scopeNode.attributes[ATTR_INTERP][channelName] ~= nil and
                    not inheritedInterpTypes[channelName]
                then
                    inheritedInterpTypes[channelName] = scopeNode.attributes[ATTR_INTERP][channelName]
                end
            end

            scopeNode = scopeNode.parent
        end

        local scopeTempTable = {
            interpolation = inheritedInterpTypes
        }

        local scopeByBone = { }

        for i = 1, #element.children do
            local child = element.children[i]

            if child.type == BONE_TYPE then
                scopeByBone[child] = scopeTempTable
            end

            keyframeByElement[child] = keyframe
            clipByElement[child] = clip
        end

        lfaTable.temp.scopeByBone = table.merge(
                lfaTable.temp.scopeByBone or {},
                scopeByBone
        )
    elseif element.type == EVENT_TYPE then
        local keyframe = lfaTable.temp.keyframeByElement[element]

        local value = element.attributes[ATTR_VALUE]

        if value then validateAndGetValueType(value) end

        table.insert(keyframe.events, {
            name = element.attributes[ATTR_NAME],
            value = value
        })
    elseif element.type == KEYFRAME_TYPE then
        local clipByElement = lfaTable.temp.clipByElement
        local clip = clipByElement[element]

        local time = element.attributes[ATTR_TIME]

        local errorPrefix = "(clip: " .. clip.name ..
                ", keyframe time: " .. time .. ") "

        if not element.children or #element.children == 0 then
            error(errorPrefix .. "keyframe can't be without children")
        end

        local keyframeTable = {
            time = time,
            events = { },
            bones = { }
        }

        local keyframeByElement = { }

        for i = 1, #element.children do
            local child = element.children[i]

            keyframeByElement[child] = keyframeTable
            clipByElement[child] = clip
        end

        table.insert(clip.keyframes, keyframeTable)

        lfaTable.temp.keyframeByElement = table.merge(
                lfaTable.temp.keyframeByElement or {},
                keyframeByElement
        )
    elseif element.type == CLIP_TYPE then
        local name = element.attributes[ATTR_NAME]

        if lfaTable.clips[name] then
            error("clip with name '" .. name .. "' already declared")
        end

        local errorPrefix = "(clip: " .. name .. ") "

        if not lfaTable.skeleton then
            error("clips must be declared after skeleton")
        end

        local loop

        if element.attributes[ATTR_LOOP] then
            loop = true
        else
            loop = false
        end

        local clipTable = {
            name = name,
            loop = loop,
            keyframes = { }
        }

        if not element.children or #element.children == 0 then
            error(errorPrefix .. "clip can't be without children")
        end

        local clipByElement = { }

        local previousTime = -1
        local maxTime = 0

        for i = 1, #element.children do
            local keyframe = element.children[i]

            local time = keyframe.attributes[ATTR_TIME]

            if time < 0 then
                error(errorPrefix .. "negative keyframe time: " .. time)
            end

            if previousTime > time then
                error(errorPrefix .. "invalid keyframes order in clip. please sort keyframes by ascending time")
            elseif previousTime == time then
                error(errorPrefix .. "keyframe with time " .. time .. " already declared")
            end

            if previousTime == -1 and time > 0 then
                error(errorPrefix .. "first keyframe time must be 0")
            end

            maxTime = math.max(maxTime, time)

            previousTime = time

            clipByElement[keyframe] = clipTable
        end

        local attrDuration = element.attributes[ATTR_DURATION]

        if not attrDuration then
            clipTable.duration = maxTime
        else
            if attrDuration < maxTime then
                error(errorPrefix .. "last key time (" .. maxTime .. ") is higher than specified duration (" .. attrDuration .. ")")
            end

            clipTable.duration = attrDuration
        end

        lfaTable.clips[name] = clipTable

        lfaTable.temp.clipByElement = table.merge(
                lfaTable.temp.clipByElement or {},
                clipByElement
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
        interps = { },
        clips = { },
        temp = { }
    }

    for i = 1, #structureTable do
        local element = structureTable[i]

        if not table.has(possibleElementsInRoot, element.type) then
            error("elements with type '" .. element.type .. "' can't be declared in the root")
        else
            analyzeElementGeneral(element)
            analyzeElementSpecial(element, lfaTable)
        end
    end

    if not lfaTable.metadata then
        error("metadata is missing")
    end

    if not lfaTable.skeleton then
        error("skeleton is missing")
    end

    lfaTable.temp = nil

    return lfaTable
end

return M