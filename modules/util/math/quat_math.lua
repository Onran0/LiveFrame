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
    local len = M.length(q)

    if len > 0 then
        return {
            q[1] / len,
            -q[2] / len,
            -q[3] / len,
            -q[4] / len
        }
    else return q end
end

function M.conj(q)
    return { q[1], -q[2], -q[3], -q[4] }
end

function M.negate(q)
    return { -q[1], -q[2], -q[3], -q[4] }
end

function M.add(a, b)
    return {
        a[1] + b[1],
        a[2] + b[2],
        a[3] + b[3],
        a[4] + b[4]
    }
end

function M.sub(a, b)
    return {
        a[1] - b[1],
        a[2] - b[2],
        a[3] - b[3],
        a[4] - b[4]
    }
end

function M.mul(a, b)
    if type(b) == 'number' then
        return M.scale(a, b)
    end

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

    local theta = math.acos(math.max(-1, math.min(1, w)))
    local sinTheta = math.sin(theta)

    if math.abs(sinTheta) < 0.0001 then
        return { 0, x, y, z }
    end

    local coeff = theta / sinTheta
    return { 0, x * coeff, y * coeff, z * coeff }
end

function M.idt_log()
    return {0, 0, 0, 0}
end

function M.exp(q)
    local x, y, z = q[2], q[3], q[4]
    local theta = math.sqrt(x*x + y*y + z*z)
    local sinTheta = math.sin(theta)

    if theta < 0.0001 then
        return M.idt()
    end

    local coeff = sinTheta / theta
    return { math.cos(theta), x * coeff, y * coeff, z * coeff }
end

function M.length_sqr(q)
    return q[1]^2 + q[2]^2 + q[3]^2 + q[4]^2
end

function M.length(q)
    return math.sqrt(M.length_sqr(q))
end

function M.img_length_sqr(q)
    return q[2]^2 + q[3]^2 + q[4]^2
end

function M.img_length(q)
    return math.sqrt(M.img_length_sqr(q))
end

function M.normalize(q)
    local len = M.length(q)

    return {
        q[1]/len,
        q[2]/len,
        q[3]/len,
        q[4]/len
    }
end

return M