local parser = require "lfa/structure_parser"
local analyzer = require "lfa/analyzer"

function on_world_open()

    debug.print(
            analyzer.analyze(
                    parser.parse(file.read("liveframe:test.lfa"))
            )
    )
end