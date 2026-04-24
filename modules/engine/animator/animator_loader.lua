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

local M = { }

local function loadSettings(settings)
    local clipsMetadataArray = { }
    local clipsMetadataIndices = { }
    local overrideClipsNames = { }

    local layers = { }

    local parametersTypes = { }
    local parametersIndices = { }

    local conditionsPrefix = "local "

    for _, fileInfo in ipairs(settings.clips) do
        local ext = file.ext(fileInfo.file)

        if not loaders[ext] then
            error("unknown animation clips format: '" .. ext .. "'")
        end

        local val, err = pcall(loaders[ext], file.read(fileInfo.file))

        if err then
            error("failed to load '" .. fileInfo.file .. "' animation clips file: " .. err)
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

        for _, state in ipairs(layer.states) do
            table.insert(layerStatesIndices, state.name)

            local fileId, clipName = parse_path(state.clip)

            local finalClipName = fileId .. "_" .. clipName

            overrideClipsNames[table.index(clipsMetadataIndices, fileId)][clipName] = finalClipName

            table.insert(finalStates, {
                clip = finalClipName,
                loop = state.loop
            })
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
                priority = transition.priority,
                interrupt = interruptTypeToIndex[transition["can-interrupt"] or "none"],
                duration = transition.duration,
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
            masks = (layer.masks or layer.mask) and (layer.masks and layer.masks or { layer.mask }),
            blendMode = layerBlendModeTypeToIndex[layer["blend-mode"] or "override"],
            weight = layer.weight or 1.0,
            defaultState = table.index(layerStatesIndices, layer["default-state"]),
            states = finalStates,
            transitions = finalTransitions
        })
    end

    return {
        clipsMetadataArray = clips_meta_combiner.combine(clipsMetadataArray, overrideClipsNames),
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