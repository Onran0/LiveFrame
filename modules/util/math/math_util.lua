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

local quat_math = require "util/math/quat_math"
local constants = require "general_constants"

local M = { }

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.hermite_basis(t)
    local t2 = t * t
    local t3 = t2 * t

    local h00 =  2 * t3 - 3 * t2 + 1
    local h10 =  t3 - 2 * t2 + t
    local h01 = -2 * t3 + 3 * t2
    local h11 = t3 - t2

    return h00, h10, h01, h11
end

function M.hermite_spline(a, b, t, startTangent, outTangent)
    local h00, h10, h01, h11 = M.hermite_basis(t)

    return a * h00 + startTangent * h10 + b * h01 + outTangent * h11
end

function M.hermite_easing(t, easeStart, easeEnd)
    return M.hermite_spline(0, 1, t, easeStart, easeEnd)
end

function M.compose_matrix_from_transform(transform)
    local matrix

    if transform[constants.POSITION_INDEX] then
        matrix = mat4.translate(transform[constants.POSITION_INDEX])
    else
        matrix = mat4.idt()
    end

    if transform[constants.ROTATION_INDEX] then
        matrix = mat4.mul(matrix, mat4.from_quat(transform[constants.ROTATION_INDEX]))
    end

    if transform[constants.SCALE_INDEX] then
        matrix = mat4.mul(matrix, mat4.scale(transform[constants.SCALE_INDEX]))
    end

    return matrix
end

function M.relativize_position(position, base)
    return vec3.sub(position, base)
end

function M.relativize_rotation(rotation, base) -- accepts normalized quaternions
    if quat_math.dot(rotation, base) < 0 then
        rotation = quat_math.negate(rotation)
    end

    return quat_math.mul(quat_math.conj(base), rotation)
end

function M.relativize_scale(scale, base)
    return vec3.div(scale, base)
end

local relativizeFuncsTable = {
    [constants.RELATIVIZE_KEYS_POSITION] = M.relativize_position,
    [constants.RELATIVIZE_KEYS_ROTATION] = M.relativize_rotation,
    [constants.RELATIVIZE_KEYS_SCALE] = M.relativize_scale
}

function M.relativize_channel(type, value, base)
    return relativizeFuncsTable[type](value, base)
end

return M