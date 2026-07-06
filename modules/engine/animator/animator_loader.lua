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
result format:
{
    clipsMetadata = { ... }, -- check top of liveframe:lfa/loader.lua
    parametersTypes = {
        ["speed"] = constants.PARAMETER_TYPE_NUMBER,
        ["jump"] = constants.PARAMETER_TYPE_TRIGGER,
    },
    parametersIndices = { -- needs because parametersTypes is unordered dictionary
        ["speed"] = 1,
        ["jump"] = 2
    },
    layers = {
        {
            name = "base",
            affectedBones = { 1, 2 }, -- indices of bones from clipsMetadata affected by this layer
            blendMode = constants.LAYER_BLEND_MODE_OVERRIDE,
            weight = 1.0,
            currentState = 1,
            states = {
                {
                    -- clip index from clipsMetadata
                    name = "state1", -- for event handlers
                    clip = 0, -- base_idle
                    timer = <instance of liveframe:engine/timer.lua>,
                    loop = true
                },
                {
                    clip = 1, -- base_run
                    name = "state2",
                    timer = <instance of liveframe:engine/timer.lua>,
                    loop = true
                },
                {
                    clip = 2, -- base_jump
                    name = "state3",
                    timer = <instance of liveframe:engine/timer.lua>,
                    loop = false
                }
            },
            transitions = {
                {
                    from = 1, -- from is always a one index. loader automatically unwraps from with array
                    to = 2,
                    priority = 0,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    exitTime = 0.0, -- can be nil. for example defined
                    blendCurve = {
                        type = constants.TRANSITION_BLEND_CURVE_LINEAR
                    },
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 2,
                    to = 1,
                    priority = 0,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = {
                        type = constants.TRANSITION_BLEND_CURVE_HERMIT,
                        easeIn = 0,
                        easeOut = 1
                    },
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 1,
                    to = 3,
                    priority = 1,
                    interrupt = constants.INTERRUPT_NONE,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = {
                        type = constants.TRANSITION_BLEND_CURVE_LINEAR
                    },
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 2,
                    to = 3,
                    priority = 1,
                    interrupt = constants.INTERRUPT_NONE,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = {
                        type = constants.TRANSITION_BLEND_CURVE_LINEAR
                    },
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 3,
                    to = 1,
                    priority = 0,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = {
                        type = constants.TRANSITION_BLEND_CURVE_LINEAR
                    }
                },
                {
                    from = 3,
                    to = 2,
                    priority = 1,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = {
                        type = constants.TRANSITION_BLEND_CURVE_LINEAR
                    },
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                }
            }
        }
    }
}
]]--

local util = require "util/util"

local constants = require "engine/animator/constants"
local conditions_loader = require "engine/animator/conditions_loader"

local CURRENT_VERSION = "1.0"

local SUPPORTED_VERSIONS = {
    CURRENT_VERSION
}

local FIELD_VERSION = "version"

local FIELD_CLIPS = "clips"
local FIELD_ID = "id"
local FIELD_FILE = "file"

local FIELD_LOAD_SETTINGS = "load-settings"

local FIELD_NAME = "name"

local FIELD_PARAMETERS = "parameters"
local FIELD_TYPE = "type"

local FIELD_LAYERS = "layers"
local FIELD_BLEND_MODE = "blend-mode"
local FIELD_WEIGHT = "weight"
local FIELD_DEFAULT_STATE = "default-state"

local FIELD_STATES = "states"
local FIELD_CLIP = "clip"
local FIELD_LOOP = "loop"

local FIELD_TRANSITIONS = "transitions"
local FIELD_FROM = "from"
local FIELD_TO = "to"
local FIELD_PRIORITY = "priority"
local FIELD_CAN_INTERRUPT = "can-interrupt"
local FIELD_DURATION = "duration"
local FIELD_EXIT_TIME = "exit-time"
local FIELD_BLEND_CURVE = "blend-curve"
local FIELD_CONDITION = "condition"
local FIELD_CONDITIONS = "conditions"

local STATE_TYPE_CLIP = "clip"
local TRANSITION_BLEND_CURVE_LINEAR = "linear"
local TRANSITION_BLEND_CURVE_HERMIT = "hermite"

local FIELD_BLEND_CURVE_EASE_START = "ease-start"
local FIELD_BLEND_CURVE_EASE_END = "ease-end"

local TRANSITION_INTERRUPT_ANY = "any"
local TRANSITION_INTERRUPT_NONE = "none"
local TRANSITION_INTERRUPT_HIGHER_PRIORITY = "higher-priority"

local LAYER_BLEND_MODE_OVERRIDE = "override"

local STATE_TYPES = {
    STATE_TYPE_CLIP
}

local TRANSITION_BLEND_CURVES = {
    TRANSITION_BLEND_CURVE_LINEAR,
    TRANSITION_BLEND_CURVE_HERMIT
}

local TRANSITION_INTERRUPT_TYPES = {
    TRANSITION_INTERRUPT_ANY,
    TRANSITION_INTERRUPT_NONE,
    TRANSITION_INTERRUPT_HIGHER_PRIORITY
}

local LAYER_BLEND_MODES = {
    LAYER_BLEND_MODE_OVERRIDE
}

local TYPE_LUA = "lua"
local TYPE_STRUCT = "struct"
local TYPE_ARRAY = "array"

local function luaType(str)
    return { type = TYPE_LUA, value = str }
end

local function structureType(str)
    return { type = TYPE_STRUCT, value = str }
end

local function arrayOf(type)
    return { type = TYPE_ARRAY, value = type }
end

local structures = {
    clipsFile = {
        fields = {
            [FIELD_ID] = luaType("string"),
            [FIELD_FILE] = luaType("string"),
            [FIELD_LOAD_SETTINGS] = luaType("table")
        },
        requiredFields = { FIELD_ID, FIELD_FILE }
    },

    parameter = {
        fields = {
            [FIELD_NAME] = luaType("string"),
            [FIELD_TYPE] = luaType("string")
        },
        requiredFields = { FIELD_NAME, FIELD_TYPE }
    },

    layer = {
        fields = {
            [FIELD_NAME] = luaType("string"),
            [FIELD_BLEND_MODE] = luaType("string"),
            [FIELD_WEIGHT] = luaType("number"),
            [FIELD_DEFAULT_STATE] = luaType("string"),
            [FIELD_STATES] = arrayOf(structureType("state")),
            [FIELD_TRANSITIONS] = arrayOf(structureType("transition"))
        },
        requiredFields = { FIELD_NAME, FIELD_DEFAULT_STATE, FIELD_STATES }
    },

    state = {
        fields = {
            [FIELD_NAME] = luaType("string"),
            [FIELD_TYPE] = luaType("string"),
            [FIELD_CLIP] = luaType("string"),
            [FIELD_LOOP] = luaType("boolean")
        },
        requiredFields = { FIELD_NAME }
    },

    transition = {
        fields = {
            [FIELD_FROM] = { luaType("string"), arrayOf(luaType("string")) },
            [FIELD_TO] = luaType("string"),
            [FIELD_PRIORITY] = luaType("number"),
            [FIELD_CAN_INTERRUPT] = luaType("string"),
            [FIELD_DURATION] = luaType("number"),
            [FIELD_EXIT_TIME] = luaType("number"),
            [FIELD_BLEND_CURVE] = { luaType("string"), structureType("blendCurveInfo") },
            [FIELD_CONDITION] = luaType("string"),
            [FIELD_CONDITIONS] = arrayOf(luaType("string"))
        },
        requiredFields = { FIELD_FROM, FIELD_TO, FIELD_DURATION }
    },

    blendCurveInfo = {
        fields = {
            [FIELD_TYPE] = luaType("string"),
            [FIELD_BLEND_CURVE_EASE_START] = luaType("number"),
            [FIELD_BLEND_CURVE_EASE_END] = luaType("number")
        },
        requiredFields = { FIELD_TYPE }
    },

    root = {
        fields = {
            [FIELD_VERSION] = luaType("string"),
            [FIELD_CLIPS] = arrayOf(structureType("clipsFile")),
            [FIELD_PARAMETERS] = arrayOf(structureType("parameter")),
            [FIELD_LAYERS] = arrayOf(structureType("layer"))
        },

        requiredFields = { FIELD_VERSION, FIELD_CLIPS, FIELD_LAYERS }
    }
}

local layerBlendModeTypeToIndex = {
    [LAYER_BLEND_MODE_OVERRIDE] = constants.LAYER_BLEND_MODE_OVERRIDE
}

local transitionBlendCurveTypeToIndex = {
    [TRANSITION_BLEND_CURVE_LINEAR] = constants.TRANSITION_BLEND_CURVE_LINEAR,
    [TRANSITION_BLEND_CURVE_HERMIT] = constants.TRANSITION_BLEND_CURVE_HERMITE
}

local interruptTypeToIndex = {
    [TRANSITION_INTERRUPT_NONE] = constants.INTERRUPT_NONE,
    [TRANSITION_INTERRUPT_ANY] = constants.INTERRUPT_ANY,
    [TRANSITION_INTERRUPT_HIGHER_PRIORITY] = constants.INTERRUPT_HIGHER_PRIORITY
}

local parameterTypeToIndex = {
    number = constants.PARAMETER_TYPE_NUMBER,
    boolean = constants.PARAMETER_TYPE_BOOLEAN,
    trigger = constants.PARAMETER_TYPE_TRIGGER
}

local allParameterTypes = {
    "boolean",
    "number",
    "trigger"
}

local loader = require "engine/loader"
local clips_meta_combiner = require "engine/clips/meta_combiner"
local timer = require "engine/timer"

local M = { }

local function checkValueConsistency(value, valueType, inconsistencies)
    if valueType.type == TYPE_LUA then
        local valType = type(value)
        local expType = valueType.value

        local res = valType == expType

        if not res then
            table.insert(
                    inconsistencies,
                    "expected value of type '" .. expType .. "', given '" .. valType .. "'"
            )
        end

        return res
    elseif valueType.type == TYPE_ARRAY then
        if not is_array(value) then
            table.insert(
                    inconsistencies,
                    "expected array of '" .. valueType.value .. "'"
            )

            return false
        end

        for i = 1, #value do
            if not checkValueConsistency(value[i], valueType.value, inconsistencies) then
                table.insert(
                        inconsistencies,
                        "expected array element type of '" .. valueType.value.value .. "'"
                )

                return false
            end
        end

        return true
    elseif valueType.type == TYPE_STRUCT then
        if type(value) ~= "table" then
            table.insert(
                    inconsistencies,
                    "expected structure of type '" .. valueType.value .. "'"
            )

            return false
        end

        local structure = structures[valueType.value]

        for fieldName, fieldValue in pairs(value) do
            if not structure.fields[fieldName] then
                table.insert(
                        inconsistencies,
                        "field '" .. fieldName .. "' is undefined in structure '" .. valueType.value .. "'"
                )

                return false
            end

            local fieldTypes = structure.fields[fieldName]

            if not is_array(fieldTypes) then
                fieldTypes = { fieldTypes }
            end

            local consistent = false

            for i = 1, #fieldTypes do
                if checkValueConsistency(fieldValue, fieldTypes[i], inconsistencies) then
                    consistent = true
                    break
                end
            end

            if not consistent then
                table.insert(
                        inconsistencies,
                        "invalid type of field '" .. fieldName .. "' in structure '" .. valueType.value .. "'"
                )

                return false
            end
        end

        for _, requiredField in ipairs(structure.requiredFields) do
            if not value[requiredField] then
                table.insert(
                        inconsistencies,
                        "missed required field '" .. requiredField .. "' in structure '" .. valueType.value .. "'"
                )

                return false
            end
        end

        return true
    else
        table.insert(
                inconsistencies,
                "undefined value type: " .. valueType.type
        )

        return false
    end
end

local function loadFromTable(animatorTable)
    local inconsistencies = { }

    if not checkValueConsistency(animatorTable, structureType("root"), inconsistencies) then
        error("invalid file structure: " .. table.concat(inconsistencies, "; "))
    end

    local version = animatorTable[FIELD_VERSION]

    if not table.has(SUPPORTED_VERSIONS, version) then
        error(
                "animator version '" .. version .. "' is not supported by this loader. max supported: "
                        .. CURRENT_VERSION
        )
    end

    version = tonumber(version)

    local clipsMetadataArray = { }
    local clipsMetadataIndices = { }
    local overrideClipsNames = { }

    local layers = { }

    local parametersTypes = { }
    local parametersIndices = { }
    local allFinalStatesArray = { }

    local affectedBonesByClips = { }

    local conditionsParams = { }

    for _, fileInfo in ipairs(animatorTable[FIELD_CLIPS]) do
        if table.has(clipsMetadataIndices, fileInfo[FIELD_ID]) then
            error("clips file with id '" .. fileInfo[FIELD_ID] .. "' already defined")
        end

        local status, res = xpcall(loader.load_from_path, util.include_traceback, fileInfo[FIELD_FILE], fileInfo[FIELD_LOAD_SETTINGS])

        if not status then
            error("failed to load '" .. fileInfo[FIELD_FILE] .. "' animation clips file: " .. res)
        end

        local clipsMetadata = res.clipsMetadata

        for _, clip in ipairs(clipsMetadata.clips) do
            affectedBonesByClips[fileInfo[FIELD_ID] .. "_" .. clip.name] = clip.affectedBones
        end

        table.insert(clipsMetadataIndices, fileInfo[FIELD_ID])
        table.insert(clipsMetadataArray, clipsMetadata)
    end

    if animatorTable[FIELD_PARAMETERS] then
        for index, parameter in ipairs(animatorTable[FIELD_PARAMETERS]) do
            if not table.has(allParameterTypes, parameter.type) then
                error("invalid parameter type: " .. parameter.type)
            end

            if parametersTypes[parameter.name] then
                error("parameter with name '" .. parameter.name .. "' already defined")
            end

            parametersTypes[parameter.name] = parameterTypeToIndex[parameter.type]
            parametersIndices[parameter.name] = index

            table.insert(conditionsParams, parameter)
        end
    end

    -- normalized state time parameter (t)
    table.insert(conditionsParams, {
        name = "t",
        type = "number"
    })

    local layersNames = { }

    for _, layer in ipairs(animatorTable[FIELD_LAYERS]) do
        if table.has(layersNames, layer[FIELD_NAME]) then
            error("layer with name '" .. layer[FIELD_NAME] .. "' already defined")
        end

        local layerStatesIndices = { }

        local statesNames = { }

        local function validateStateExist(stateName)
            if not table.has(statesNames, stateName) then
                error("state with name '" .. stateName .. "' is undefined in layer '" .. layer[FIELD_NAME] .. "'")
            end
        end

        local finalStates = { }
        local affectedBones = { }

        for _, state in ipairs(layer[FIELD_STATES]) do
            if table.has(statesNames, state[FIELD_NAME]) then
                error("state with name '" .. state[FIELD_NAME] .. "' already defined in layer '" .. layer[FIELD_NAME] .. "'")
            end

            local stateType = state[FIELD_TYPE] or STATE_TYPE_CLIP

            if not table.has(STATE_TYPES, stateType) then
                error("unknown state type: '" .. stateType .. "'")
            end

            table.insert(layerStatesIndices, state[FIELD_NAME])

            if stateType == STATE_TYPE_CLIP and not state[FIELD_CLIP] then
                error("clip name for state '" .. state[FIELD_NAME] .. "' is missed")
            end

            local fileId, clipName = unpack(state[FIELD_CLIP]:split(":"))

            local idx = table.index(clipsMetadataIndices, fileId)

            if not idx then
                error("undefined clips file id: " .. fileId)
            end

            local hasClip = false

            for _, clip in ipairs(clipsMetadataArray[idx][FIELD_CLIPS]) do
                if clip[FIELD_NAME] == clipName then
                    hasClip = true
                    break
                end
            end

            if not hasClip then
                error(
                        "clip with name '" .. clipName .. "' is undefined in clips file '" .. fileId .. "'"
                )
            end

            local finalClipName = fileId .. "_" .. clipName

            if not overrideClipsNames[idx] then
                overrideClipsNames[idx] = { }
            end

            for _, affectedBone in ipairs(affectedBonesByClips[finalClipName]) do
                table.insert_unique(affectedBones, affectedBone)
            end

            overrideClipsNames[idx][clipName] = finalClipName

            local stateTimer = timer:new()

            local finalState = {
                name = state[FIELD_NAME],
                clip = finalClipName,
                timer = stateTimer,
                loop = state[FIELD_LOOP]
            }

            table.insert(statesNames, state[FIELD_NAME])

            table.insert(finalStates, finalState)

            table.insert(allFinalStatesArray, finalState)
        end

        local finalTransitions = { }

        if layer[FIELD_TRANSITIONS] then
            for _, transition in ipairs(layer[FIELD_TRANSITIONS]) do
                local conditionFunc

                if transition[FIELD_CONDITION] or transition[FIELD_CONDITIONS] then
                    if transition[FIELD_CONDITION] and transition[FIELD_CONDITIONS] then
                        error(
                                "transition can't have defined 'condition' and 'conditions' properties together. layer '"
                                        .. layer[FIELD_NAME] .. "'"
                        )
                    end

                    local luaExpr, err

                    luaExpr, conditionFunc, err = conditions_loader.load(
                            conditionsParams,
                            transition[FIELD_CONDITION] or transition[FIELD_CONDITIONS]
                    )

                    if err then
                        error(
                                "failed to compile transition condition(-s) '" .. luaExpr .. "' in layer '"
                                        .. layer[FIELD_NAME] .. "': " .. err
                        )
                    end
                end

                local toState = transition[FIELD_TO]
                local duration = transition[FIELD_DURATION]
                local exitTime = transition[FIELD_EXIT_TIME]
                local blendCurve = transition[FIELD_BLEND_CURVE] or TRANSITION_BLEND_CURVE_LINEAR
                local interrupt = transition[FIELD_CAN_INTERRUPT] or TRANSITION_INTERRUPT_NONE

                local hasBlendCurveExtra = type(blendCurve) == "table"
                local blendCurveType = hasBlendCurveExtra and blendCurve.type or blendCurve

                validateStateExist(toState)

                if duration < 0 then
                    error("transition duration can't be negative")
                end

                if exitTime and (exitTime < 0 or exitTime > 1) then
                    error("exit time must be normalized")
                end

                if not table.has(TRANSITION_BLEND_CURVES, blendCurveType) then
                    error("undefined transition blend curve type: " .. blendCurveType)
                end

                if not table.has(TRANSITION_INTERRUPT_TYPES, interrupt) then
                    error("undefined transition interrupt type: " .. interrupt)
                end

                local blendCurveTable = {
                    type = transitionBlendCurveTypeToIndex[blendCurveType]
                }

                if blendCurveType == TRANSITION_BLEND_CURVE_HERMIT then
                    local easeStart = 0
                    local easeEnd = 0

                    if hasBlendCurveExtra then
                        easeStart = blendCurve[FIELD_BLEND_CURVE_EASE_START] or 0
                        easeEnd = blendCurve[FIELD_BLEND_CURVE_EASE_START] or 0
                    end

                    blendCurveTable.easeStart = easeStart
                    blendCurveTable.easeEnd = easeEnd
                elseif blendCurveType == TRANSITION_BLEND_CURVE_LINEAR then
                    if
                        blendCurve[FIELD_BLEND_CURVE_EASE_START] or
                        blendCurve[FIELD_BLEND_CURVE_EASE_END]
                    then
                        error(
                                "blend curve of type 'linear' can't have '" ..
                                FIELD_BLEND_CURVE_EASE_START .. "' or '" ..
                                FIELD_BLEND_CURVE_EASE_END .. "' fields"
                        )
                    end
                end

                local baseTable = {
                    to = table.index(layerStatesIndices, toState),
                    priority = transition[FIELD_PRIORITY] or 0,
                    interrupt = interruptTypeToIndex[interrupt],
                    duration = duration,
                    timer = timer:new(duration),
                    exitTime = exitTime,
                    blendCurve = blendCurveTable,
                    conditionFunc = conditionFunc
                }

                local function addTransition(from, tbl)
                    validateStateExist(from)

                    if from == toState then
                        error("'from' state can't equals to 'to'")
                    end

                    tbl.from = table.index(layerStatesIndices, from)

                    table.insert(finalTransitions, tbl)
                end

                if type(transition.from) == "table" then
                    for _, fromState in ipairs(transition.from) do
                        addTransition(fromState, table.deep_copy(baseTable))
                    end
                else
                    addTransition(transition.from, baseTable)
                end
            end
        end

        local weight = layer.weight or 1.0
        local blendMode = layer[FIELD_BLEND_MODE] or LAYER_BLEND_MODE_OVERRIDE
        local defaultState = layer[FIELD_DEFAULT_STATE]

        if weight < 0 or weight > 1 then
            error("invalid layer weight: " .. weight)
        end

        if not table.has(LAYER_BLEND_MODES, blendMode) then
            error("invalid layer blend mode: " .. blendMode)
        end

        validateStateExist(defaultState)

        table.insert(layers, {
            name = layer[FIELD_NAME],
            affectedBones = affectedBones,
            blendMode = layerBlendModeTypeToIndex[blendMode],
            weight = weight,
            currentState = table.index(layerStatesIndices, defaultState),
            states = finalStates,
            transitions = finalTransitions
        })

        table.insert(layersNames, layer.name)
    end

    local clipsMetadata = clips_meta_combiner.combine(clipsMetadataArray, overrideClipsNames)

    for _, finalState in ipairs(allFinalStatesArray) do
        local clipName = finalState[FIELD_CLIP]
        local clipIndex
        local clip

        for mayClipIndex, mayClip in ipairs(clipsMetadata.clips) do
            if mayClip.name == clipName then
                clipIndex = mayClipIndex
                clip = mayClip
                break
            end
        end

        if not clipIndex then error("unknown clip: " .. clipName) end

        finalState[FIELD_CLIP] = clipIndex

        local stateTimer = finalState.timer

        stateTimer:set_duration(clip[FIELD_DURATION])
        stateTimer:set_loop(finalState[FIELD_LOOP])
    end

    return {
        clipsMetadata = clipsMetadata,
        parametersTypes = parametersTypes,
        parametersIndices = parametersIndices,
        layers = layers
    }
end

function M.load(val)
    if type(val) == "string" then
        return loadFromTable(json.parse(val))
    else
        return loadFromTable(val)
    end
end

return M