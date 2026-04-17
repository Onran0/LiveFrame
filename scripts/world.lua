local structure_parser = require "lfa/structure_parser"

function on_world_open()
    debug.print(
            structure_parser.parse(file.read("liveframe:test.lfa"))
    )
end