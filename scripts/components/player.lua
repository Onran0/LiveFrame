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