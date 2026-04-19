local parse = require "lfa/structure_parser".parse
local analyze = require "lfa/analyzer".analyze
local load = require "lfa/loader".load

function on_world_open()
    debug.print(
            load(file.read("liveframe:test.lfa"))
    )
end