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

local api = require "api"

local eventHandlers = { }
local skeleton = entity.skeleton

local animator = api.create_animator(ARGS[FIELD_PATH], skeleton, eventHandlers)

function get()
    return animator
end

function on_render(delta)
    animator:step(delta)
end