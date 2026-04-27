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
                    blendCurve = constants.TRANSITION_BLEND_CURVE_LINEAR,
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 2,
                    to = 1,
                    priority = 0,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = constants.TRANSITION_BLEND_CURVE_LINEAR,
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 1,
                    to = 3,
                    priority = 1,
                    interrupt = constants.INTERRUPT_NONE,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = constants.TRANSITION_BLEND_CURVE_LINEAR,
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 2,
                    to = 3,
                    priority = 1,
                    interrupt = constants.INTERRUPT_NONE,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = constants.TRANSITION_BLEND_CURVE_LINEAR,
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                },
                {
                    from = 3,
                    to = 1,
                    priority = 0,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = constants.TRANSITION_BLEND_CURVE_LINEAR
                },
                {
                    from = 3,
                    to = 2,
                    priority = 1,
                    interrupt = constants.INTERRUPT_HIGHER_PRIORITY,
                    duration = 0.25,
                    timer = <instance of liveframe:engine/timer.lua>,
                    blendCurve = constants.TRANSITION_BLEND_CURVE_LINEAR,
                    conditionFunc = function(...) local speed, jump, t = ...; return <original condition> end
                }
            }
        }
    }
}
]]--

local constants = require "engine/animator/constants"

local layerBlendModeTypeToIndex = {
    override = constants.LAYER_BLEND_MODE_OVERRIDE
}

local transitionBlendCurveTypeToIndex = {
    linear = constants.TRANSITION_BLEND_CURVE_LINEAR
}

local interruptTypeToIndex = {
    none = constants.INTERRUPT_NONE,
    any = constants.INTERRUPT_ANY,
    ["higher-priority"] = constants.INTERRUPT_HIGHER_PRIORITY
}

local parameterTypeToIndex = {
    number = constants.PARAMETER_TYPE_NUMBER,
    boolean = constants.PARAMETER_TYPE_BOOLEAN,
    trigger = constants.PARAMETER_TYPE_TRIGGER
}

local loaders = require "engine/loaders"
local clips_meta_combiner = require "engine/clips/meta_combiner"
local timer = require "engine/timer"

local M = { }

local function loadSettings(settings)
    local clipsMetadataArray = { }
    local clipsMetadataIndices = { }
    local overrideClipsNames = { }

    local layers = { }

    local parametersTypes = { }
    local parametersIndices = { }
    local allFinalStatesArray = { }

    local affectedBonesByClips = { }

    local conditionsPrefix = "local "

    for _, fileInfo in ipairs(settings.clips) do
        local ext = file.ext(fileInfo.file)

        if not loaders[ext] then
            error("unknown animation clips format: '" .. ext .. "'")
        end

        local status, val = pcall(loaders[ext].load, file.read(fileInfo.file))

        if not status then
            error("failed to load '" .. fileInfo.file .. "' animation clips file: " .. val)
        end

        for _, clip in ipairs(val.clips) do
            affectedBonesByClips[fileInfo.id .. "_" .. clip.name] = clip.affectedBones
        end

        table.insert(clipsMetadataIndices, fileInfo.id)
        table.insert(clipsMetadataArray, val)
    end

    for index, parameter in ipairs(settings.parameters) do
        parametersTypes[parameter.name] = parameterTypeToIndex[parameter.type]
        parametersIndices[parameter.name] = index

        conditionsPrefix = conditionsPrefix .. parameter.name

        if index ~= #settings.parameters then
            conditionsPrefix = conditionsPrefix .. ", "
        end
    end

    conditionsPrefix = conditionsPrefix .. ", t = ...; return "

    for _, layer in ipairs(settings.layers) do
        local layerStatesIndices = { }

        local finalStates = { }
        local affectedBones = { }

        for _, state in ipairs(layer.states) do
            table.insert(layerStatesIndices, state.name)

            local fileId, clipName = unpack(state.clip:split(":"))

            local finalClipName = fileId .. "_" .. clipName

            local idx = table.index(clipsMetadataIndices, fileId)

            if not overrideClipsNames[idx] then
                overrideClipsNames[idx] = { }
            end

            for _, affectedBone in ipairs(affectedBonesByClips[finalClipName]) do
                table.insert_unique(affectedBones, affectedBone)
            end

            overrideClipsNames[idx][clipName] = finalClipName

            local stateTimer = timer:new()

            local finalState = {
                name = state.name,
                clip = finalClipName,
                timer = stateTimer,
                loop = state.loop
            }

            table.insert(finalStates, finalState)

            table.insert(allFinalStatesArray, finalState)
        end

        local finalTransitions = { }

        for _, transition in ipairs(layer.transitions) do
            local conditionFunc, err = load(conditionsPrefix .. transition.condition)

            if err then
                error(
                        "failed to compile transition condition '" .. transition.condition .. "' in layer '"
                                .. layer.name .. "': " .. err
                )
            end

            local baseTable = {
                to = table.index(layerStatesIndices, transition.to),
                priority = transition.priority or 0,
                interrupt = interruptTypeToIndex[transition["can-interrupt"] or "none"],
                duration = transition.duration,
                timer = timer:new(transition.duration),
                exitTime = transition["exit-time"],
                blendCurve = transitionBlendCurveTypeToIndex[transition["blend-curve"] or "linear"],
                conditionFunc = conditionFunc
            }

            if type(transition.from) == "table" then
                for _, fromState in ipairs(transition.from) do
                    local copy = table.copy(baseTable)

                    copy.from = table.index(layerStatesIndices, fromState)

                    table.insert(finalTransitions, copy)
                end
            else
                baseTable.from = table.index(layerStatesIndices, transition.from)

                table.insert(finalTransitions, baseTable)
            end
        end

        table.insert(layers, {
            name = layer.name,
            affectedBones = affectedBones,
            blendMode = layerBlendModeTypeToIndex[layer["blend-mode"] or "override"],
            weight = layer.weight or 1.0,
            currentState = table.index(layerStatesIndices, layer["default-state"]),
            states = finalStates,
            transitions = finalTransitions
        })
    end

    local clipsMetadata = clips_meta_combiner.combine(clipsMetadataArray, overrideClipsNames)

    for _, finalState in ipairs(allFinalStatesArray) do
        local clipName = finalState.clip
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

        finalState.clip = clipIndex

        local stateTimer = finalState.timer

        stateTimer:set_duration(clip.duration)
        stateTimer:set_loop(finalState.loop)
    end

    return {
        clipsMetadata = clipsMetadata,
        parametersTypes = parametersTypes,
        parametersIndices = parametersIndices,
        layers = layers
    }
end

function M.load(settings)
    return loadSettings(
            type(settings) == "string" and
                    json.parse(settings) or
                    settings
    )
end

return M