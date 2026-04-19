local M = { }

function M.from_xyzw(q)
    return { q[4], q[1], q[2], q[3] }
end

function M.idt()
    return {1, 0, 0, 0}
end

function M.dot(a, b)
    return a[1]*b[1] + a[2]*b[2] + a[3]*b[3] + a[4]*b[4]
end

function M.inverse(q)
    return {q[1], -q[2], -q[3], -q[4]}
end

function M.add(a, b)
    return {
        a[1] + b[1],
        a[2] + b[2],
        a[3] + b[3],
        a[4] + b[4]
    }
end

function M.mul(a, b)
    local aw, ax, ay, az = a[1], a[2], a[3], a[4]
    local bw, bx, by, bz = b[1], b[2], b[3], b[4]

    return {
        aw*bw - ax*bx - ay*by - az*bz,
        aw*bx + ax*bw + ay*bz - az*by,
        aw*by - ax*bz + ay*bw + az*bx,
        aw*bz + ax*by - ay*bx + az*bw
    }
end

function M.scale(q, s)
    return {
        q[1] * s,
        q[2] * s,
        q[3] * s,
        q[4] * s
    }
end

function M.log(q)
    local w, x, y, z = q[1], q[2], q[3], q[4]

    local v_len = math.sqrt(x*x + y*y + z*z)

    if v_len < 1e-8 then
        return {0, 0, 0, 0}
    end

    local angle = math.atan2(v_len, w)
    local scale = angle / v_len

    return {
        0,
        x * scale,
        y * scale,
        z * scale
    }
end

function M.idt_log()
    return {0, 0, 0, 0}
end

function M.exp(q)
    local x, y, z = q[1], q[2], q[3]

    local angle = math.sqrt(x*x + y*y + z*z)

    if angle < 1e-8 then
        return {0, 0, 0, 1}
    end

    local sin_a = math.sin(angle)
    local cos_a = math.cos(angle)

    local scale = sin_a / angle

    return {
        cos_a,
        x * scale,
        y * scale,
        z * scale
    }
end

function M.normalize(q)
    local len = math.sqrt(M.dot(q, q))

    return {
        q[1]/len,
        q[2]/len,
        q[3]/len,
        q[4]/len
    }
end

return M