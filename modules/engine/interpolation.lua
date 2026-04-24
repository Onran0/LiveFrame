local quat_math = require "util/math/quat_math"
local math_util = require "util/math/math_util"

local M = { }

local function quatNlerp(a, b, t)
    return quat_math.normalize({
        math_util.lerp(a[1], b[1], t),
        math_util.lerp(a[2], b[2], t),
        math_util.lerp(a[3], b[3], t),
        math_util.lerp(a[4], b[4], t)
    })
end

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

M.functions = {
    lerp = function(a, b, t)
        return {
            math_util.lerp(a[1], b[1], t),
            math_util.lerp(a[2], b[2], t),
            math_util.lerp(a[3], b[3], t)
        }
    end,
    ["cubic-spline"] = function(a, b, t, inTangent, outTangent)
        local t2 = t * t
        local t3 = t2 * t

        -- Hermite basis functions
        local h00 =  2 * t3 - 3 * t2 + 1
        local h10 =  t3 - 2 * t2 + t
        local h01 = -2 * t3 + 3 * t2
        local h11 = t3 - t2

        return
        vec3.add(
                vec3.add(
                        vec3.mul(a, h00),
                        vec3.mul(outTangent, h10)
                ),
                vec3.add(
                        vec3.mul(b, h01),
                        vec3.mul(inTangent, h11)
                )
        )
    end,

    nlerp = quatNlerp,

    slerp = quat.slerp,

    squad = function(a, b, t, inControl, outControl)
        return squadSlerp(
                squadSlerp(a, b, t),
                squadSlerp(inControl, outControl, t),
                2 * t * (1 - t)
        )
    end,

    step = function(a, b, t)
        if t == 1 then return b else return a end
    end
}

M.customFieldsIndices = {
    ["cubic-spline"] = {
        "in-tangent",
        "out-tangent"
    },
    squad = {
        "in-control",
        "out-control"
    }
}

return M