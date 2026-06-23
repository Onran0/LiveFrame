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

local supportedVersion = "2.0"

local bufferMediaTypes = {
    "application/octet-stream",
    "application/gltf-buffer"
}

local imageMediaTypes = {
    "image/png",
    "image/jpeg"
}

local SIGNED_BYTE = 5120
local UNSIGNED_BYTE = 5121
local SIGNED_SHORT = 5122
local UNSIGNED_SHORT = 5123
local UNSIGNED_INT = 5125
local FLOAT = 5126

local componentTypes = {
    SIGNED_BYTE,
    UNSIGNED_BYTE,
    SIGNED_SHORT,
    UNSIGNED_SHORT,
    UNSIGNED_INT,
    FLOAT
}

local integerComponentTypes = {
    SIGNED_BYTE,
    UNSIGNED_BYTE,
    SIGNED_SHORT,
    UNSIGNED_SHORT,
    UNSIGNED_INT
}

local componentSizesInBytes = {
    [SIGNED_BYTE] = 1,
    [UNSIGNED_BYTE] = 1,
    [SIGNED_SHORT] = 2,
    [UNSIGNED_SHORT] = 2,
    [UNSIGNED_INT] = 4,
    [FLOAT] = 4
}

local componentTypeMaxValues = {
    [SIGNED_BYTE] = 127,
    [UNSIGNED_BYTE] = 255,
    [SIGNED_SHORT] = 32767,
    [UNSIGNED_SHORT] = 65535,
    [UNSIGNED_INT] = 4294967295
}

local componentTypeFormats = {
    [SIGNED_BYTE] = 'b',
    [UNSIGNED_BYTE] = 'B',
    [SIGNED_SHORT] = 'h',
    [UNSIGNED_SHORT] = 'H',
    [UNSIGNED_INT] = 'I',
    [FLOAT] = 'f'
}

local SCALAR = "SCALAR"
local VEC2 = "VEC2"
local VEC3 = "VEC3"
local VEC4 = "VEC4"
local MAT2 = "MAT2"
local MAT3 = "MAT3"
local MAT4 = "MAT4"

local elementTypes = {
    SCALAR, VEC2, VEC3, VEC4, MAT2, MAT3, MAT4
}

local matrixTypes = {
    MAT2, MAT3, MAT4
}

local elementTypeComponentsCount = {
    [SCALAR] = 1,
    [VEC2] = 2,
    [VEC3] = 3,
    [VEC4] = 4,
    [MAT2] = 4,
    [MAT3] = 9,
    [MAT4] = 16
}

local matrixColumnsCount = {
    [MAT2] = 2,
    [MAT3] = 3,
    [MAT4] = 4
}

local matrixRowsCount = {
    [MAT2] = 2,
    [MAT3] = 3,
    [MAT4] = 4
}

local function deserializeAccessorElement(type, componentType, bytes, normalized)
    local componentsCount = elementTypeComponentsCount[type]
    local componentFormat = componentTypeFormats[componentType]

    local format = "<"
    local components

    if not table.has(matrixTypes, type) then
        format = format .. componentFormat:rep(componentsCount)
        components = { byteutil.unpack(format, bytes) }
    else
        local componentSize = componentSizesInBytes[componentType]

        local columnPaddingBytes = (componentSize * matrixRowsCount[type]) % 4

        format = format .. (componentFormat:rep(componentsCount)
                             .. ("?") -- '?' is boolean format
                                :rep(columnPaddingBytes)):rep(matrixColumnsCount[type])

        -- padding bytes will be read as booleans

        format = format:sub(1, #format - columnPaddingBytes) -- removing trailing padding bytes cuz they may missing

        components = table.filter(
                { byteutil.unpack(format, bytes) },

                function(_, value)
                    return type(value) ~= "boolean" -- trick for simple remove padding bytes
                end
        )
    end

    if normalized then
        local max = componentTypeMaxValues[componentType]

        for i = 1, #components do
            components[i] = math.clamp(components[i] / max, -1, 1)
        end
    end

    return components
end

local function deserializeAccessorElements(type, componentType, view, stride, offset, count, normalized)
    local elements = { }

    local componentSize = componentSizesInBytes[componentType]

    local elementSize = componentSize * elementTypeComponentsCount[type]

    local columnPaddingBytes

    local isMatrixType = table.has(matrixTypes, type)

    if isMatrixType then
        columnPaddingBytes = (componentSize * matrixRowsCount[type]) % 4

        elementSize = elementSize + columnPaddingBytes * matrixColumnsCount[type]
    end

    stride = stride or elementSize

    for i = 0, count - 1 do
        if isMatrixType and i == count - 1 then
            elementSize = elementSize - columnPaddingBytes
        end

        local elementBytes = view:slice(offset + i * stride + 1, elementSize)

        table.insert(elements, deserializeAccessorElement(
                type,
                componentType,
                elementBytes,
                normalized
        ))
    end

    return elements
end

local function splitVersionToMajorMinor(strVersion)
    if strVersion:find(".", 1, true) then
        local split = strVersion:split(".")

        if #split <= 2 then
            local major, minor = tonumber(split[1]), tonumber(split[2])

            if major and minor then
                return major, minor
            end
        end
    end

    error("invalid version format: " .. strVersion)
end

local majorSupportedVersion, minorSupportedVersion = splitVersionToMajorMinor(supportedVersion)

local M = { }

function unescapeUri(uri)
    return uri:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

function loadBufferData(bufferInfo, loadSettings)
    local bytes

    if bufferInfo.uri then
        local srcUri = bufferInfo.uri
        local uri = unescapeUri(srcUri)

        local colon = uri:find("/", 1, true)

        local firstSegment = colon and uri:sub(1, colon - 1) or uri

        local schemeNameEnd = firstSegment:find(":", 1, true)

        if not schemeNameEnd then -- path-noscheme / ipath-noscheme
            local path = file.join(file.parent(loadSettings.sourceFilePath), uri)

            if not file.exists(path) then
                error("buffer file doesn't exists: " .. path)
            end

            bytes = file.read_bytes(path)
        else
            local schemeEnd = uri:find(":", 1, true)

            local scheme = uri:sub(1, schemeEnd - 1)

            if scheme == "data" then
                local commaPos = uri:find(",", 1, true)

                if not commaPos then
                    error("invalid data uri: " .. srcUri)
                end

                local firstSemicolon = uri:find(";", 1, true)

                local mediaType = uri:sub(schemeEnd + 1, firstSemicolon - 1)

                if not table.has(bufferMediaTypes, mediaType) then
                    error("invalid media type for buffer: " .. mediaType)
                end

                local params = uri:sub(firstSemicolon, commaPos)

                if params ~= ";base64," then
                    error("unsupported data uri parameters for buffer: " .. params)
                end

                local payload = uri:sub(commaPos + 1)

                bytes = base64.decode(payload)
            else
                error("unsupported uri scheme: " .. scheme)
            end
        end
    else
        bytes = loadSettings.binaryChunk:slice(1, bufferInfo.byteLength)
    end

    if #bytes == bufferInfo.byteLength then
        return bytes
    else
        return bytes:slice(1, bufferInfo.byteLength)
    end
end

function M.load(value, loadSettings)
    local gltfTable = json.parse(value)

    if not gltfTable.asset or not gltfTable.asset.version then
        error("invalid glTF")
    end

    if gltfTable.asset.minVersion then
        local majorVersion, minorVersion = splitVersionToMajorMinor(gltfTable.asset.minVersion)

        if majorSupportedVersion ~= majorVersion or minorSupportedVersion < minorVersion then
            error("file requires support of glTF " .. gltfTable.asset.minVersion .. ", but max supported by loader is " .. supportedVersion)
        end
    else
        local majorVersion = splitVersionToMajorMinor(gltfTable.asset.version)

        if majorSupportedVersion ~= majorVersion then
            error("glTF files with version " .. majorVersion .. ".x is not supported by this loader")
        end
    end

    local nodes = { }

    if gltfTable.nodes then
        for i, node in ipairs(gltfTable.nodes) do
            local destNodeTable = {
                name = node.name,
                translation = node.translation or { 0, 0, 0 },
                rotation = node.rotation or { 1, 0, 0, 0 },
                scale = node.scale or { 1, 1, 1 }
            }

            if node.matrix then
                if node.translation or node.rotation or node.scale then
                    error("node matrix present with translation/rotation/scale")
                end

                local decomposed = mat4.decompose(node.matrix)

                if not decomposed then
                    error("not decomposable matrix defined in node")
                end

                destNodeTable.translation = decomposed.translation
                destNodeTable.rotation = decomposed.quaternion
                destNodeTable.scale = decomposed.scale
            end
        end

        for i, node in ipairs(gltfTable.nodes) do
            if node.children then
                local children = { }

                for j, childIndex in ipairs(node.children) do
                    children[j] = childIndex + 1

                    nodes[childIndex + 1].parent = i
                end

                nodes[i].children = children
            end
        end
    end

    local scenes = { }

    for i, scene in ipairs(gltfTable.scenes) do
        local sceneNodes = { }

        for j, nodeIndex in ipairs(scene.nodes) do
            sceneNodes[j] = nodeIndex + 1

            if nodes[nodeIndex + 1].parent then
                error("scene nodes must be roots (without parent)")
            end
        end

        scenes[i] = {
            name = scene.name,
            nodes = sceneNodes
        }
    end

    local sceneIndex = gltfTable.scene

    if sceneIndex then
        sceneIndex = sceneIndex + 1
    else sceneIndex = loadSettings.sceneIndex end

    if sceneIndex then
        error("display scene index is undefined in gltf file, and in load settings")
    end

    local scene = scenes[sceneIndex]

    local buffers = { }
    local bufferViews = { }
    local accessors = { }

    for i, bufferInfo in ipairs(gltfTable.buffers) do
        buffers[i] = loadBufferData(bufferInfo, loadSettings)
    end

    for i, bufferViewInfo in ipairs(gltfTable.bufferViews) do
        local srcBuffer = buffers[bufferViewInfo.buffer + 1]

        local viewedBuffer = srcBuffer:slice(
            bufferViewInfo.byteOffset + 1,
            bufferViewInfo.byteLength
        )

        bufferViews[i] = {
            view = viewedBuffer,
            stride = bufferViewInfo.byteStride
        }
    end

    for i, accessorInfo in ipairs(gltfTable.accessors) do
        local componentType = accessorInfo.componentType
        local type = accessorInfo.type
        local normalized = accessorInfo.normalized

        if not table.has(componentTypes, componentType) then
            error("unsupported accessor componentType: " .. componentType)
        end

        if not table.has(elementTypes, type) then
            error("unsupported accessor type: " ..type)
        end

        if componentType == FLOAT and normalized ~= nil then
            error("accessor.normalized defined when componentType is 5126 (float)")
        end

        local elements

        if accessorInfo.bufferView then
            local bufferViewData = bufferViews[accessorInfo.bufferView]

            elements = deserializeAccessorElements(
                    type, componentType,
                    bufferViewData.view, bufferViewData.stride,
                    accessorInfo.byteOffset, accessorInfo.count,
                    normalized
            )
        else
            elements = { }

            local defaultValue = { }

            for j = 1, elementTypeComponentsCount do
                defaultValue[j] = 0
            end

            for j = 1, accessorInfo.count do
                elements[j] = table.copy(defaultValue)
            end
        end

        local sparse = accessorInfo.sparse

        if sparse then
            local sparseCount = sparse.count
            local indicesInfo = sparse.indices
            local valuesInfo = sparse.values

            if not table.has(integerComponentTypes, indicesInfo.componentType) then
                error("componentType " .. indicesInfo.componentType " in accessor.sparse.indices is unknown or non-integer (float)")
            end

            local indicesBufferViewData = bufferViews[indicesInfo.bufferView]

            local indices = deserializeAccessorElements(
                    SCALAR, indicesInfo.componentType,
                    indicesBufferViewData.view, indicesBufferViewData.stride,
                    indicesInfo.byteOffset, sparseCount,
                    false
            )

            local valuesBufferViewData = bufferViews[valuesInfo.bufferView]

            local values = deserializeAccessorElements(
                    type, componentType,
                    valuesBufferViewData.view, valuesBufferViewData.stride,
                    valuesInfo.byteOffset, sparseCount,
                    false
            )

            for j = 1, sparseCount do
                elements[indices[j][1] + 1] = values[j]
            end
        end

        accessors[i] = elements
    end


end

return M