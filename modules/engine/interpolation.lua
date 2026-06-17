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

local quat_math = require "util/math/quat_math"
local math_util = require "util/math/math_util"

local M = { }

local function squadSlerp(q1, q2, t)
    local dot = math.clamp(quat_math.dot(q1, q2), -1, 1)

    if dot > 0.9995 then
        return quatNlerp(q1, q2, t)
    end

    local q3 = quat_math.normalize(
            quat_math.sub(q2, quat_math.scale(
                    q1,
                    dot
            ))
    )

    local theta = math.acos(dot) * t

    return quat_math.add(
            quat_math.scale(q1, math.cos(theta)),
            quat_math.scale(q3, math.sin(theta))
    )
end

M.functions = { }

M.functions[constants.TARGET_VEC3] = {
    lerp = function(a, b, t)
        return vec3.mix(a, b, t)
    end,

    ["cubic-spline"] = function(a, b, t, startTangent, endTangent)
        local h00, h10, h01, h11 = math_util.hermite_basis(t)

        return
        vec3.add(
                vec3.add(
                        vec3.mul(a, h00),
                        vec3.mul(startTangent, h10)
                ),
                vec3.add(
                        vec3.mul(b, h01),
                        vec3.mul(endTangent, h11)
                )
        )
    end,

    step = function(a, b, t)
        if t == 1 then return b else return a end
    end
}

M.functions[constants.TARGET_QUAT] = {
    ["cubic-spline"] = function(a, b, t, startTangent, endTangent)
        local h00, h10, h01, h11 = math_util.hermite_basis(t)

        return
        quat_math.normalize(
                vec4.add(
                        vec4.add(
                                vec4.mul(a, h00),
                                vec4.mul(startTangent, h10)
                        ),
                        vec4.add(
                                vec4.mul(b, h01),
                                vec4.mul(endTangent, h11)
                        )
                )
        )
    end,

    nlerp = function(a, b, t)
        return quat_math.normalize(vec4.mix(a, b, t))
    end,

    slerp = quat.slerp,

    squad = function(a, b, t, startControl, endControl)
        return squadSlerp(
                squadSlerp(a, b, t),
                squadSlerp(startControl, endControl, t),
                2 * t * (1 - t)
        )
    end,

    step = function(a, b, t)
        if t == 1 then return b else return a end
    end
}

M.customFieldsIndices = {
    [constants.TARGET_VEC3] = {
        ["cubic-spline"] = {
            "start-tangent",
            "end-tangent"
        }
    },
    [constants.TARGET_QUAT] = {
        ["cubic-spline"] = {
            "start-tangent",
            "end-tangent"
        },
        squad = {
            "start-control",
            "end-control"
        }
    }
}

return M