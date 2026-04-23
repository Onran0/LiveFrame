local timer = require "engine/timer"
local util = require "util/util"

local M = { }

setmetatable(M, { __index = timer })

M.__index = M

function M:new(sampler, skeleton)
    return setmetatable(table.merge(timer:new(), {
        sampler = sampler,
        skeleton = skeleton,
        paused = false
    }), self)
end

function M:get_sampler()
    return self.sampler
end

function M:set_sampler(sampler)
    self.sampler = sampler
end

function M:__update_rig_indices()
    if not self.playingClip then
        self.clipBoneIndexToRigIndex = nil
        return
    end

    local clip = self.sampler:get_clip_by_index(self.playingClip)

    local clipBoneIndexToRigIndex = { }

    util.foreach(clip.bonesIndices, function(boneName, boneIndex)
        clipBoneIndexToRigIndex[boneIndex] = self.skeleton:index(boneName)
    end)

    self.clipBoneIndexToRigIndex = clipBoneIndexToRigIndex
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
    self.clipBoneIndexToRigIndex = nil

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

    util.foreach(
            self.sampler:get_transforms_sample(timer.step(self, delta), self.playingClip, true),
            function(transform, index)
                local boneMatrix

                if transform[1] then
                    boneMatrix = mat4.translate(transform[1])
                else
                    boneMatrix = mat4.idt()
                end

                if transform[2] then
                    boneMatrix = mat4.mul(boneMatrix, mat4.from_quat(transform[2]))
                end

                if transform[3] then
                    boneMatrix = mat4.mul(boneMatrix, mat4.scale(transform[3]))
                end

                self.skeleton:set_matrix(self.clipBoneIndexToRigIndex[index], boneMatrix)
            end
    )
end

return M