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

local constants = require "general_constants"

local M = { }

function M.lerp(a, b, t)
    return a + (b - a) * t
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

return M