local FIELD_PATH = "path"

local api = require "api"

local eventHandlers = { }
local skeleton = entity.skeleton

local animator = api.create_animator(ARGS[FIELD_PATH], skeleton, eventHandlers)

function set_event_handler(name, func)
    eventHandlers[name] = func
end

function get_animator()
    return animator
end

function on_render(delta)
    animator:step(delta)
end