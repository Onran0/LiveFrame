return function(clips, bonesIndices)
    for _, clip in ipairs(clips) do
        local bonesKeys = clip.bonesKeys

        for index, _ in ipairs(bonesIndices) do
            if not bonesKeys[index] then
                bonesKeys[index] = {
                    { { { 0, 0, 0 }, 0 } }, -- default position
                    { { { 1, 0, 0, 0 }, 0 } }, -- default rotation
                    { { { 1, 1, 1 }, 0 } } -- default scale
                }
            else
                local boneKeys = bonesKeys[index]

                if not boneKeys[1] or #boneKeys[1] == 0 then
                    boneKeys[1] = { { { 0, 0, 0 }, 0 } }
                end

                if not boneKeys[2] or #boneKeys[2] == 0 then
                    boneKeys[2] = { { { 1, 0, 0, 0 }, 0 } }
                end

                if not boneKeys[3] or #boneKeys[3] == 0 then
                    boneKeys[3] = { { { 1, 1, 1 }, 0 } }
                end
            end
        end
    end
end