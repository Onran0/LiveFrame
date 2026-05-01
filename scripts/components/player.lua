local FIELD_PATH = "path"
local FIELD_PATHS = "paths"
local FIELD_OVERRIDE_CLIP_NAMES = "override-clip-names"

local api = require "api"

local eventHandlers = { }
local skeleton = entity.skeleton

local player

if ARGS[FIELD_PATH] then
    player = api.create_player(ARGS[FIELD_PATH], skeleton, eventHandlers)
elseif ARGS[FIELD_PATHS] then
    player = api.create_player_multi(
            ARGS[FIELD_PATHS], ARGS[FIELD_OVERRIDE_CLIP_NAMES],
            skeleton, eventHandlers
    )
end

function set_event_handler(name, func)
    eventHandlers[name] = func
end

function get_player()
    return player
end

function on_render(delta)
    player:step(delta)
end