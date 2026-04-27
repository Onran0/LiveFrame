local math_util = require "util/math/math_util"
local timer = require "engine/timer"

local M = { }

setmetatable(M, { __index = timer })

M.__index = M

function M:new(sampler, skeleton, eventHandlers)
    local obj = setmetatable(table.merge(timer:new(), {
        sampler = sampler,
        skeleton = skeleton,
        paused = false,
        eventHandlers = eventHandlers or { }
    }), self)

    obj:__update_rig_indices()

    return obj
end

function M:__update_rig_indices()
    local boneIndexToRigIndex = { }

    for boneIndex, boneName in ipairs(self.sampler:get_clips_metadata().bonesIndices) do
        boneIndexToRigIndex[boneIndex] = self.skeleton:index(boneName)
    end

    self.boneIndexToRigIndex = boneIndexToRigIndex
end

function M:__check_events(prevTime, time, inner)
    if prevTime ~= time then
        local clip = self.sampler:get_clips_metadata().clips[self.playingClip]

        if not inner and self:is_looped() and (prevTime - time) > self:get_duration() / 2 then
            self:__check_events(prevTime, self:get_duration(), true)
            self:__check_events(-0.0001, time, true)
        else
            for _, event in ipairs(clip.events) do
                local evTime = event.time

                if evTime > prevTime and evTime <= time then
                    local handler = self.eventHandlers[event.name]

                    if handler then
                        handler(event.value, clip.name, clip)
                    end
                end
            end
        end
    end
end

function M:get_sampler()
    return self.sampler
end

function M:set_sampler(sampler)
    self.sampler = sampler

    self:__update_rig_indices()
end

function M:set_skeleton(skeleton)
    self.skeleton = skeleton

    self:__update_rig_indices()
end

function M:play(name)
    self:play_by_index(self.sampler:get_clip_index_by_name(name))
end

function M:play_by_index(index)
    local clip = self.sampler:get_clip_by_index(index)

    self.duration = clip.duration
    self.loop = clip.loop
    self.paused = false
    self.time = 0

    self.playingClip = index

    self:__update_rig_indices()
end

function M:get_playing_clip_name()
    if self.playingClip then
        return self.sampler:get_clip_name_by_index(self.playingClip)
    end
end

function M:get_playing_clip_index()
    return self.playingClip
end

function M:get_clip_duration()
    return self.duration
end

function M:is_paused()
    return self.paused
end

function M:stop()
    self.boneIndexToRigIndex = nil

    self.paused = false
    self.time = 0
    self.duration = nil

    self.playingClip = nil
end

function M:pause()
    self.paused = true
end

function M:resume()
    self.paused = false
end

function M:step(delta)
    if not self.playingClip or self.paused then
        return
    elseif not self.loop and (self.time >= self.duration or (self.time < 0 and delta < 0)) then
        return
    elseif delta == 0 then
        return
    end

    local prevTime = timer.get_time(self)
    local time = timer.step(self, delta)

    self:__check_events(prevTime, time)

    for index, transform in ipairs(self.sampler:get_transforms_sample(time, self.playingClip, true)) do
        self.skeleton:set_matrix(
                self.boneIndexToRigIndex[index],
                math_util.compose_matrix_from_transform(transform)
        )
    end
end

return M