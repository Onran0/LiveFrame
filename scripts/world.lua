local parser = require "lfa/structure_parser"
local analyzer = require "lfa/analyzer"
local loader = require "lfa/loader"

function on_world_open()

    debug.print(
            loader.load(file.read("liveframe:test.lfa"))
    )
end