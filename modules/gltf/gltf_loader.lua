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

local quat_math = require "util/math/quat_math"

local supportedVersion = "2.0"

local bufferMediaTypes = {
    "application/octet-stream",
    "application/gltf-buffer"
}

local pngMediaType = "image/png"
local jpegMediaType = "image/jpeg"

local imageMediaTypes = {
    pngMediaType,
    jpegMediaType
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

local attrPosition = "POSITION"
local attrNormal = "NORMAL"
local attrTangent = "TANGENT"
local attrTexCoord = "TEXCOORD"
local attrColor = "COLOR"
local attrJoints = "JOINTS"
local attrWeights = "WEIGHTS"

local attrTexCoord0 = attrTexCoord .. "_0"
local attrColor0 = attrColor .. "_0"

local meshPrimitiveAttributes = {
    attrPosition,
    attrNormal,
    attrTangent,
    attrTexCoord,
    attrColor,
    attrJoints,
    attrWeights
}

local supportedMeshPrimitiveAttributes = {
    attrPosition,
    attrNormal,
    attrTexCoord0,
    attrColor0
}

local meshPrimitiveAttributeValueTypes = {
    [attrPosition] = { VEC3 },
    [attrNormal] = { VEC3 },
    [attrTexCoord0] = { VEC2 },
    [attrColor0] = { VEC3, VEC4 }
}

local indexComponentTypes = {
    { UNSIGNED_BYTE, UNSIGNED_SHORT, UNSIGNED_INT }
}

local mayMultiMeshPrimitiveAttributes = {
    attrTexCoord,
    attrColor,
    attrJoints,
    attrWeights
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

    return #components == 1 and components[1] or components
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

local function getAttributeType(name)
    local separator = name:find("_")

    if separator then
        return name:sub(1, separator - 1)
    else return name end
end

local function isValidAttributeName(name)
    if not table.has(meshPrimitiveAttributes, name) then
        local separator = name:find("_")

        if separator then
            local attribName = name:sub(1, separator - 1)
            local attribIndex = name:sub(separator + 1, #name)

            if table.has(mayMultiMeshPrimitiveAttributes, attribName) then
                if attribIndex[1] ~= "0" and tonumber(attribIndex) then
                    return true
                end
            end
        end
    else return true end
end

local PRIMITIVE_MODE_POINT = 0
local PRIMITIVE_MODE_LINE_STRIPS = 1
local PRIMITIVE_MODE_LINE_LOOPS = 2
local PRIMITIVE_MODE_LINES = 3
local PRIMITIVE_MODE_TRIANGLES = 4
local PRIMITIVE_MODE_TRIANGLE_STRIPS = 5
local PRIMITIVE_MODE_TRIANGLE_FANS = 6

local primitiveModes = {
    PRIMITIVE_MODE_POINT,
    PRIMITIVE_MODE_LINE_STRIPS,
    PRIMITIVE_MODE_LINE_LOOPS,
    PRIMITIVE_MODE_LINES,
    PRIMITIVE_MODE_TRIANGLES,
    PRIMITIVE_MODE_TRIANGLE_STRIPS,
    PRIMITIVE_MODE_TRIANGLE_FANS
}

local supportedPrimitiveModes = {
    PRIMITIVE_MODE_TRIANGLES
}

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
                mesh = node.mesh,
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
                destNodeTable.matrix = node.matrix
            else
                destNodeTable.matrix = mat4.mul(
                        mat4.mul(
                                mat4.translate(destNodeTable.translation),
                                mat4.from_quat(
                                        quat_math.normalize(quat_math.from_xyzw(destNodeTable.rotation))
                                )
                        ),
                        mat4.scale(destNodeTable.scale)
                )
            end

            nodes[i] = destNodeTable
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

    local function getNodeGlobalMatrix(node)
        if node.parent then
            local parentGlobalMatrix = getNodeGlobalMatrix(nodes[node.parent])

            return mat4.mul(parentGlobalMatrix, node.matrix)
        else return node.matrix end
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

    local function getBufferView(index)
        local bufferView = bufferViews[index + 1]

        if not bufferView then
            error("buffer view with index " .. index .. " is not exists")
        end

        return bufferView
    end

    local function getAccessor(index)
        local accessor = accessors[index + 1]

        if not accessor then
            error("accessor with index " .. index .. " is not exists")
        end

        return accessor
    end

    for i, bufferInfo in ipairs(gltfTable.buffers) do
        buffers[i] = loadBufferData(bufferInfo, loadSettings)
    end

    for i, bufferViewInfo in ipairs(gltfTable.bufferViews) do
        local bufIndex = bufferViewInfo.buffer + 1

        local srcBuffer = buffers[bufIndex]

        if not srcBuffer then
            error("buffer with index " .. (bufIndex - 1) .. " is not exists")
        end

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
            local bufferViewData = getBufferView(accessorInfo.bufferView)

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

            local indicesBufferViewData = getBufferView(indicesInfo.bufferView)

            if not table.has(indexComponentTypes, indicesInfo.componentType) then
                error("componentType " .. indicesInfo.componentType .. " can't be used for indices")
            end

            local indices = deserializeAccessorElements(
                    SCALAR, indicesInfo.componentType,
                    indicesBufferViewData.view, indicesBufferViewData.stride,
                    indicesInfo.byteOffset, sparseCount,
                    false
            )

            local valuesBufferViewData = getBufferView(valuesInfo.bufferView)

            local values = deserializeAccessorElements(
                    type, componentType,
                    valuesBufferViewData.view, valuesBufferViewData.stride,
                    valuesInfo.byteOffset, sparseCount,
                    normalized
            )

            for j = 1, sparseCount do
                elements[indices[j] + 1] = values[j]
            end
        end

        accessors[i] = {
            type = type,
            componentType = componentType,
            values = elements,
            normalized = normalized
        }
    end

    local meshes = { }

    for _, meshInfo in ipairs(gltfTable.meshes) do
        local primitives = { }

        for _, primitiveInfo in ipairs(meshInfo.primitives) do
            if not table.has(primitiveModes, primitiveInfo.mode) then
                error("invalid mesh primitive mode: " .. primitiveInfo.mode)
            end

            if not table.has(supportedPrimitiveModes, primitiveInfo.mode) then
                print(
                        "warning: mesh primitives with mode " ..
                        primitiveInfo.mode .. " is not supported by this loader. skipping it"
                )
            else
                local attributes = { }

                local prevAttribAccessorCount

                for attribName, attribAccessorIndex in pairs(primitiveInfo.attributes) do
                    if not isValidAttributeName(attribName) then
                        error("invalid mesh primitive attribute name: " .. attribName)
                    end

                    if table.has(supportedMeshPrimitiveAttributes, attribName) then
                        local accessor = getAccessor(attribAccessorIndex)

                        local attributeValueType = meshPrimitiveAttributeValueTypes[getAttributeType(attribName)]

                        if not table.has(attributeValueType, accessor.type) then
                            error(
                                    "accessor type doesn't match to mesh primitive attribute value type: "
                                            .. accessor.type .. " != " .. table.concat(attributeValueType, " or ")
                            )
                        end

                        if prevAttribAccessorCount then
                            if prevAttribAccessorCount ~= #accessor.values then
                                error("accessor of mesh primitive attribute " .. attribName .. " have different elements count")
                            end
                        end

                        prevAttribAccessorCount = #accessor.values

                        table.insert(attributes, {
                            type = attribName,
                            values = accessor.values
                        })
                    else
                        print("warning: mesh primitive attributes of type " .. attribName .. " is not supported by this loader. skipping it")
                    end
                end

                local indices = { }

                local attrsCount = table.count_pairs(primitiveInfo.attributes)

                if primitiveInfo.indices then
                    local gltfIndices = getAccessor(primitiveInfo.indices)

                    if not table.has(indexComponentTypes, gltfIndices.componentType) then
                        error("componentType " .. gltfIndices.componentType .. " can't be used for mesh primitive indices")
                    end

                    if gltfIndices.normalized then
                        error("accessor used for mesh primitive indices can't be normalized")
                    end

                    gltfIndices = gltfIndices.values

                    for i = 0, #gltfIndices - 1 do
                        local idx = gltfIndices[i + 1]

                        for j = 1, attrsCount do
                            indices[i * attrsCount + j] = idx
                        end
                    end
                else
                    -- count of accessor for any attribute in mesh.primitive.attributes is equal
                    -- to primitive vertices count when mesh.primitive.indices undefined
                    for i = 0, prevAttribAccessorCount - 1 do
                        for j = 1, attrsCount do
                            indices[i * attrsCount + j] = i
                        end
                    end
                end

                table.insert(primitives, {
                    attributes = attributes,
                    indices = indices,
                    material = primitiveInfo.material
                })
            end
        end

        table.insert(meshes, {
            primitives = primitives
        })
    end

    for _, node in ipairs(nodes) do
        if node.mesh and not meshes[node.mesh] then
            error("node " .. node.name .. " using undefined mesh with index " .. node.mesh)
        end
    end


end

return M