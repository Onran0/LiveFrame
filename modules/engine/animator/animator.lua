local constants = require "engine/animator/constants"

local math_util = require "util/math/math_util"

local sampler = require "engine/clips/sampler"
local blender = require "engine/clips/blender"

local M = { }

M.__index = M

function M:new(loadedSettings, skeleton, eventHandlers)
    local samplerInstance = sampler:new(loadedSettings.clipsMetadata)

    local parametersValues = { }

    for i, type in ipairs(loadedSettings.parametersTypes) do
        if type == constants.PARAMETER_TYPE_BOOLEAN or type == constants.PARAMETER_TYPE_TRIGGER then
            parametersValues[i] = false
        elseif type == constants.PARAMETER_TYPE_NUMBER then
            parametersValues[i] = 0
        else
            error("unknown parameter type: " .. type)
        end
    end

    local obj = setmetatable({
        parametersValues = parametersValues,
        sampler = samplerInstance,
        blender = blender:new(samplerInstance),
        parametersTypes = loadedSettings.parametersTypes,
        parametersIndices = loadedSettings.parametersIndices,
        layers = loadedSettings.layers,
        speed = 1,
        paused = false,
        skeleton = skeleton,
        eventHandlers = eventHandlers or { }
    }, self)

    self.__update_rig_indices(obj)

    return obj
end

function M:__update_rig_indices()
    local boneIndexToRigIndex = { }

    for boneIndex, boneName in ipairs(self.sampler:get_clips_metadata().bonesIndices) do
        boneIndexToRigIndex[boneIndex] = self.skeleton:index(boneName)
    end

    self.boneIndexToRigIndex = boneIndexToRigIndex
end

function M:__check_events(prevTime, time, state, layerIndex, inner)
    if prevTime ~= time then
        local clip = self.sampler:get_clips_metadata().clips[state.clip]

        if not inner and state.timer:is_looped() and (prevTime - time) > state.timer:get_duration() / 2 then
            self:__check_events(prevTime, state.timer:get_duration(), state, layerIndex, true)
            self:__check_events(-0.0001, time, state, layerIndex, true)
        else
            for _, event in ipairs(clip.events) do
                local evTime = event.time

                if evTime > prevTime and evTime <= time then
                    local handler = self.eventHandlers[event.name]

                    if handler then
                        handler(event.value, state.name, layerIndex, state, clip)
                    end
                end
            end
        end
    end
end

function M:__step_layer(delta, layer, layerIndex)
    local currentStateIndex = layer.currentState
    local currentTransitionIndex = layer.currentTransition

    local transitions = layer.transitions
    local states = layer.states

    local currentState = states[currentStateIndex]
    local currentTransition = currentTransitionIndex and transitions[currentTransitionIndex]

    local parametersValues = self.parametersValues

    for i = 1, #transitions do
        local transition = transitions[i]

        if currentStateIndex == transition.from then
            local normTime = currentState.timer:get_normalized_time()

            if
            (not transition.conditionFunc or
                    transition.conditionFunc(unpack(parametersValues), normTime)) and
                    (not transition.exitTime or normTime >= transition.exitTime) and
                    (not currentTransition or currentTransition.interrupt == constants.INTERRUPT_ANY
                            or (currentTransition.interrupt == constants.INTERRUPT_HIGHER_PRIORITY and
                            transition.priority > currentTransition.priority))
            then
                transition.timer:reset()

                layer.currentTransition = i
                currentTransitionIndex = i
                currentTransition = transition
            end
        end
    end

    if currentTransition then
        local stateFrom = states[currentTransition.from]
        local stateTo = states[currentTransition.to]

        currentTransition.timer:step(delta)

        local prevFromTime = stateFrom.timer:get_time()
        local prevToTime = stateTo.timer:get_time()

        local fromTime = stateFrom.timer:step(delta)
        local toTime = stateTo.timer:step(delta)

        self:__check_events(prevFromTime, fromTime, stateFrom, layerIndex)
        self:__check_events(prevToTime, toTime, stateTo, layerIndex)

        local transitionNormTime = math.clamp(currentTransition.timer:get_normalized_time(), 0, 1)

        if currentTransition.timer:is_end() then
            stateFrom.timer:reset()

            currentState = stateTo

            layer.currentTransition = nil
            layer.currentState = currentTransition.to
        end

        if currentTransition.blendCurve == constants.TRANSITION_BLEND_CURVE_LINEAR then
            return self.blender:calculate_samples_and_blend(
                    { fromTime, toTime },
                    { stateFrom.clip, stateTo.clip },
                    { 1 - transitionNormTime, transitionNormTime },
                    true
            )
        end
    end

    local prevTime = currentState.timer:get_time()

    local time = currentState.timer:step(delta)

    self:__check_events(prevTime, time, currentState, layerIndex)

    return self.sampler:get_transforms_sample(time, currentState.clip, true)
end

function M:__set_parameter(name, value)
    self.parametersValues[self.parametersIndices[name]] = value
end

function M:set_boolean(name, value)
    self:__set_parameter(name, value)
end

function M:set_number(name, value)
    self:__set_parameter(name, value)
end

function M:set_trigger(name)
    self:__set_parameter(name, true)
end

function M:get_speed()
    return self.speed
end

function M:set_speed(speed)
    self.speed = speed
end

function M:is_paused()
    return self.paused
end

function M:set_paused(paused)
    self.paused = paused
end

function M:get_sampler()
    return self.sampler
end

function M:set_skeleton(skeleton)
    self.skeleton = skeleton

    self:__update_rig_indices()
end

function M:step(delta)
    if self.paused then return end

    delta = delta * self.speed

    local layers = self.layers
    local pose

    if #layers == 1 then
        pose = self:__step_layer(delta, layers[1], 1)
    else
        local transforms = { }
        local weights = { }

        for i = 1, #layers do
            local layer = layers[i]

            transforms[i] = self:__step_layer(delta, layer, i)
            weights[i] = layer.weight
        end

        pose = self.blender:blend_transforms(blender.BLEND_MODE_LAYER, transforms, weights,
            function(layerId, boneId)
                return table.has(layers[layerId].affectedBones, boneId)
            end
        )
    end

    for index, transform in ipairs(pose) do
        self.skeleton:set_matrix(
                self.boneIndexToRigIndex[index],
                math_util.compose_matrix_from_transform(transform)
        )
    end

    for name, type in pairs(self.parametersTypes) do
        if type == constants.PARAMETER_TYPE_TRIGGER then
            self:__set_parameter(name, false)
        end
    end
end

return M