local lfa_loader = require "lfa/loader"
local animation_player = require "engine/animation_player"

local player = animation_player:new(
        lfa_loader.load(file.read("liveframe:test.lfa")),
        entity.skeleton
)

player:play("anim1")

function on_render(delta)
    player:step(delta)
end