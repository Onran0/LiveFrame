local M = { }

M.__index = M

function M:new(duration, loop, speed)
    return setmetatable({
        time = 0,
        loop = loop or false,
        speed = speed or 1,
        duration = duration
    }, self)
end

function M:get_time()
    return self.time
end

function M:set_time(time)
    self.time = time
end

function M:reset()
    self.time = 0
end

function M:get_normalized_time()
    return self.time / self.duration
end

function M:set_normalized_time(normTime)
    self.time = normTime * self.duration
end

function M:is_looped()
    return self.loop
end

function M:set_loop(loop)
    self.loop = loop
end

function M:get_speed()
    return self.speed
end

function M:set_speed(speed)
    self.speed = speed
end

function M:get_duration()
    return self.duration
end

function M:set_duration(duration)
    self.duration = duration
end

function M:is_end()
    return self.time >= self.duration
end

function M:step(delta)
    local duration = self.duration
    local time = self.time + delta * self.speed

    if self.loop then
        time = time % duration
    elseif duration and time > duration then
        time = duration
    end

    self.time = time

    return time
end

return M