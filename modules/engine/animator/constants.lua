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

local LAYER_BLEND_MODE_OVERRIDE = 1

local PARAMETER_TYPE_NUMBER = 1
local PARAMETER_TYPE_BOOLEAN = 2
local PARAMETER_TYPE_TRIGGER = 3

local TRANSITION_BLEND_CURVE_LINEAR = 1
local TRANSITION_BLEND_CURVE_HERMITE = 2

local INTERRUPT_NONE = 1
local INTERRUPT_ANY = 2
local INTERRUPT_HIGHER_PRIORITY = 3

return {
    LAYER_BLEND_MODE_OVERRIDE = LAYER_BLEND_MODE_OVERRIDE,

    LAYER_BLEND_MODES = {
        LAYER_BLEND_MODE_OVERRIDE
    },

    TRANSITION_BLEND_CURVE_LINEAR = TRANSITION_BLEND_CURVE_LINEAR,
    TRANSITION_BLEND_CURVE_HERMITE = TRANSITION_BLEND_CURVE_HERMITE,

    TRANSITION_BLEND_CURVES = {
        TRANSITION_BLEND_CURVE_LINEAR,
        TRANSITION_BLEND_CURVE_HERMITE
    },

    PARAMETER_TYPE_NUMBER = PARAMETER_TYPE_NUMBER,
    PARAMETER_TYPE_BOOLEAN = PARAMETER_TYPE_BOOLEAN,
    PARAMETER_TYPE_TRIGGER = PARAMETER_TYPE_TRIGGER,

    INTERRUPT_NONE = INTERRUPT_NONE,
    INTERRUPT_ANY = INTERRUPT_ANY,
    INTERRUPT_HIGHER_PRIORITY = INTERRUPT_HIGHER_PRIORITY
}