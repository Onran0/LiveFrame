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

local warnings = true

local supportedVersion = "2.0"

local bufferMediaTypes = {
    "application/octet-stream",
    "application/gltf-buffer"
}

local pngMediaType = "image/png"
local jpegMediaType = "image/jpeg"

local pngMagic = Bytearray({ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })
local jpegMagic = Bytearray({ 0xFF, 0xD8, 0xFF })

local imageMediaTypes = {
    pngMediaType,
    jpegMediaType
}

local supportedImageMediaTypes = {
    pngMediaType
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
    UNSIGNED_BYTE,
    UNSIGNED_SHORT,
    UNSIGNED_INT
}

local mayMultiMeshPrimitiveAttributes = {
    attrTexCoord,
    attrColor,
    attrJoints,
    attrWeights
}

local function bytearrayStartsWith(bytes, startBytes)
    if #bytes < #startBytes then
        return false
    end

    for i = 1, #startBytes do
        if bytes[i] ~= startBytes[i] then
            return false
        end
    end

    return true
end

local function getMimeType(bytes)
    if bytearrayStartsWith(bytes, jpegMagic) then
        return jpegMediaType
    elseif bytearrayStartsWith(bytes, pngMagic) then
        return pngMediaType
    else
        return nil
    end
end

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
        local currentElementSize = elementSize

        if isMatrixType and i == count - 1 then
            currentElementSize = currentElementSize - columnPaddingBytes
        end

        local elementBytes = view:slice(offset + i * stride + 1, currentElementSize)

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

local unsignedIntChars = "0123456789"

local function containsOnly(str, from)
    for i = 1, utf8.length(str) do
        local char = utf8.sub(str, i, i)

        local correct = false

        for j = 1, utf8.length(from) do
            if char == utf8.sub(from, j, j) then
                correct = true
                break
            end
        end

        if not correct then
            return false
        end
    end

    return true
end

local function isValidAttributeName(name)
    if not table.has(meshPrimitiveAttributes, name) then
        local separator = name:find("_")

        if separator then
            local attribName = name:sub(1, separator - 1)
            local attribIndex = name:sub(separator + 1, #name)

            if table.has(mayMultiMeshPrimitiveAttributes, attribName) then
                local fChar = attribIndex[1]

                if
                    attribIndex == "0"
                    or (
                       fChar ~= "0" and fChar ~= "-" and containsOnly(attribIndex, unsignedIntChars)
                    )
                then
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

local targetTranslationPath = "translation"
local targetRotationPath = "rotation"
local targetScalePath = "scale"
local targetWeightsPath = "weights"

local animationChannelTargetPaths = {
    targetTranslationPath,
    targetRotationPath,
    targetScalePath,
    targetWeightsPath
}

local supportedAnimationChannelTargetPaths = {
    targetTranslationPath,
    targetRotationPath,
    targetScalePath
}

local animationChannelTargetPathDataTypes = {
    [targetTranslationPath] = VEC3,
    [targetRotationPath] = VEC4,
    [targetScalePath] = VEC3,
    [targetWeightsPath] = SCALAR
}

local animationInterpolationTypeStep = "STEP"
local animationInterpolationTypeLinear = "LINEAR"
local animationInterpolationTypeCubicSpline = "CUBICSPLINE"

local animationInterpolationTypes = {
    animationInterpolationTypeStep,
    animationInterpolationTypeLinear,
    animationInterpolationTypeCubicSpline
}

local supportedAnimationInterpolationTypes = {
    animationInterpolationTypeStep,
    animationInterpolationTypeLinear,
    animationInterpolationTypeCubicSpline
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

local function warning(msg)
    if warnings then
        print("warning: " .. msg)
    end
end

local uniqueModelIndex = 0

local majorSupportedVersion, minorSupportedVersion = splitVersionToMajorMinor(supportedVersion)

local M = { }

local function vec4XyzwToWxyz(vec)
    return {
        vec[4], vec[1], vec[2], vec[3]
    }
end

local nodeNameCharsToEscape = {
    "\\",
    "/"
}

local function escapeNodeName(name)
    local escapedName = ""

    for i = 1, utf8.length(name) do
        local char = utf8.sub(name, i, i)

        if table.has(nodeNameCharsToEscape, char) then
            escapedName = escapedName .. "\\"
        end

        escapedName = escapedName .. char
    end

    return escapedName
end

local function unescapeUri(uri)
    return uri:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

local function loadBytearrayFromURI(srcUri, sourceFile)
    local bytes

    local uri = unescapeUri(srcUri)

    local colon = uri:find("/", 1, true)

    local firstSegment = colon and uri:sub(1, colon - 1) or uri

    local schemeNameEnd = firstSegment:find(":", 1, true)

    if not schemeNameEnd then -- path-noscheme / ipath-noscheme
        local path = file.join(file.parent(sourceFile), uri)

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

    return bytes
end

function M.get_node_name_in_skeleton(nameChain)
    local escapedNameChain = { }

    for i = 1, #nameChain do
        escapedNameChain[i] = escapeNodeName(nameChain[i])
    end

    return table.concat(escapedNameChain, "/")
end

function M.extract_gltf_data(rawJson, loadSettings)
    local gltfTable = json.parse(rawJson)

    if not gltfTable.asset or not gltfTable.asset.version then
        error("invalid glTF")
    end

    if gltfTable.asset.minVersion then
        local majorVersion, minorVersion = splitVersionToMajorMinor(gltfTable.asset.minVersion)

        if majorSupportedVersion ~= majorVersion or minorSupportedVersion < minorVersion then
            error("file requires support of glTF " .. gltfTable.asset.minVersion .. ", but max supported by loader is " .. supportedVersion)
        end
    else
        local majorVersion, _ = splitVersionToMajorMinor(gltfTable.asset.version)

        if majorSupportedVersion ~= majorVersion then
            error("glTF files with version " .. majorVersion .. ".x is not supported by this loader")
        end
    end

    uniqueModelIndex = uniqueModelIndex + 1

    local nodes = { }

    if gltfTable.nodes then
        for i, node in ipairs(gltfTable.nodes) do
            local destNodeTable = {
                name = node.name,
                translation = node.translation or { 0, 0, 0 },
                rotation = node.rotation and quat_math.normalize(quat_math.from_xyzw(node.rotation)) or { 1, 0, 0, 0 },
                scale = node.scale or { 1, 1, 1 }
            }

            if node.mesh then
                destNodeTable.mesh = node.mesh + 1
            end

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
                                mat4.from_quat(destNodeTable.rotation)
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

    local function getUniqueNodeName(node)
        if node.parent then
            local parentNameChain = getUniqueNodeName(nodes[node.parent])

            return parentNameChain .. "/" .. escapeNodeName(node.name)
        else return escapeNodeName(node.name) end
    end

    local function getUpperNodeParentIndex(nodeIndex)
        local parent = nodes[nodeIndex].parent

        if parent then
            return getUpperNodeParentIndex(parent)
        else return nodeIndex end
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

    if not sceneIndex then
        error("display scene index is undefined in gltf file, and in load settings")
    end

    local scene = scenes[sceneIndex]

    if not scene then
        error("scene with index " .. sceneIndex .. " is undefined")
    end

    local function hasNodeInScene(nodeIndex)
        return table.has(scene.nodes, getUpperNodeParentIndex(nodeIndex))
    end

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
        local bytes

        if bufferInfo.uri then
            bytes = loadBytearrayFromURI(bufferInfo.uri, loadSettings.sourceFile)
        else
            bytes = loadSettings.binaryChunk
        end

        if #bytes < bufferInfo.byteLength then
            error("buffer length is less than buffer.byteLength (" .. #bytes .. " < " .. bufferInfo.byteLength .. ")")
        elseif #bytes == bufferInfo.byteLength then
            buffers[i] = bytes
        else
            buffers[i] = bytes:slice(1, bufferInfo.byteLength)
        end
    end

    for i, bufferViewInfo in ipairs(gltfTable.bufferViews) do
        local bufIndex = bufferViewInfo.buffer + 1

        local srcBuffer = buffers[bufIndex]

        if not srcBuffer then
            error("buffer with index " .. (bufIndex - 1) .. " is not exists")
        end

        local off = bufferViewInfo.byteOffset
        local requiredLength = off + bufferViewInfo.byteLength

        if requiredLength < #srcBuffer then
            error("length of pointed buffer is less than bufferView.byteLength (required " .. requiredLength .. " bytes, got " .. #srcBuffer .. ")")
        end

        local viewedBuffer = srcBuffer:slice(
            off + 1,
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

            for j = 1, elementTypeComponentsCount[type] do
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
                error("componentType " .. indicesInfo.componentType .. " in accessor.sparse.indices is unknown or non-integer (float)")
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
                if indices[j] >= accessorInfo.count then
                    error("sparse accessor index " .. indices[j] .. " is >= than accessor.count (" .. accessorInfo.count .. ")")
                end

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

    local images = { }
    local textures = { }
    local materials = { }

    local defaultMaterial = {
        texture = "white"
    }

    if gltfTable.images then
        for i, imageInfo in ipairs(gltfTable.images) do
            local bytes, mimeType

            if imageInfo.bufferView then
                if not imageInfo.mimeType then
                    error("image refers to bufferView must define mimeType")
                end

                bytes = getBufferView(imageInfo.bufferView).view
                mimeType = imageInfo.mimeType
            elseif imageInfo.uri then
                bytes = loadBytearrayFromURI(imageInfo.uri, loadSettings.sourceFile)

                if imageInfo.mimeType then
                    mimeType = imageInfo.mimeType
                else
                    mimeType = getMimeType(bytes)

                    if not mimeType then
                        error("failed to determine mimeType of image at index " .. i)
                    end
                end
            end

            if not table.has(imageMediaTypes, mimeType) then
                error("unknown mimeType of image at index " .. i)
            end

            if not table.has(supportedImageMediaTypes, mimeType) then
                warning(
                        "images of mimeType=" ..
                                mimeType .. " is not supported by this loader. image will be replaced with a placeholder"
                )

                images[i] = "notfound"
            else
                local textureName = "lf_gltf_" .. uniqueModelIndex .. "_" .. i

                if mimeType == pngMediaType then
                    assets.load_texture(bytes, textureName, "png")
                end

                images[i] = textureName
            end
        end
    end

    if gltfTable.textures then
        for i, textureInfo in ipairs(gltfTable.textures) do
            if textureInfo.sampler then
                warning("texture samplers is not supported by this loader. texture will be loaded with default render engine parameters")
            end

            local textureName

            if not textureInfo.source then
                textureName = "notfound"
            else
                local source = textureInfo.source + 1

                if not images[source] then
                    error("image with index " .. source .. " used at texture " .. i .. " is undefined")
                else
                    textureName = images[source]
                end
            end

            textures[i] = textureName
        end
    end

    if gltfTable.materials then
        for i, materialInfo in ipairs(gltfTable.materials) do
            local printWarning = materialInfo.normalTexture
                    or materialInfo.emissiveFactor
                    or materialInfo.alphaMode
                    or materialInfo.alphaCutoff
                    or materialInfo.doubleSided

            local pbr = materialInfo.pbrMetallicRoughness

            local textureName = "white"

            if pbr then
                printWarning = printWarning
                        or pbr.baseColorFactor
                        or pbr.metallicFactor
                        or pbr.roughnessFactor

                local baseTexture = pbr.baseColorTexture

                if baseTexture then
                    printWarning = printWarning or baseTexture.texCoord ~= 0

                    local baseTextureIndex = baseTexture.index + 1

                    textureName = textures[baseTextureIndex]

                    if not textureName then
                        error("texture with index " .. baseTextureIndex .. " used in material with index " .. i .. " is undefined")
                    end
                end
            end

            materials[i] = {
                texture = textureName
            }

            if printWarning then
                warning("of all materials properties supported only base color texture")
            end
        end
    end

    local meshes = { }

    if gltfTable.meshes then
        for _, meshInfo in ipairs(gltfTable.meshes) do
            local primitives = { }

            for _, primitiveInfo in ipairs(meshInfo.primitives) do
                local mode = primitiveInfo.mode or PRIMITIVE_MODE_TRIANGLES

                if not table.has(primitiveModes, mode) then
                    error("invalid mesh primitive mode: " .. mode)
                end

                if not table.has(supportedPrimitiveModes, mode) then
                    warning(
                            "mesh primitives with mode " ..
                                    mode .. " is not supported by this loader. skipping it"
                    )
                else
                    local attributes = { }

                    local supportedAttrsCount = 0

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

                            supportedAttrsCount = supportedAttrsCount + 1
                        else
                            warning("mesh primitive attributes of type " .. attribName .. " is not supported by this loader. skipping it")
                        end
                    end

                    local indices = { }

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

                            if idx >= prevAttribAccessorCount then
                                error("mesh primitive index " .. idx .. " is >= than attribute accessor count (" .. prevAttribAccessorCount .. ")")
                            end

                            for j = 1, supportedAttrsCount do
                                indices[i * supportedAttrsCount + j] = idx
                            end
                        end
                    else
                        -- count of accessor for any attribute in mesh.primitive.attributes is equal
                        -- to primitive vertices count when mesh.primitive.indices undefined
                        for i = 0, prevAttribAccessorCount - 1 do
                            for j = 1, supportedAttrsCount do
                                indices[i * supportedAttrsCount + j] = i
                            end
                        end
                    end

                    local material

                    if primitiveInfo.material then
                        local materialIndex = primitiveInfo.material + 1

                        material = materials[materialIndex]

                        if not material then
                            error("material with index " .. materialIndex .. " used in some mesh primitive is undefined")
                        end
                    else
                        material = defaultMaterial
                    end

                    table.insert(primitives, {
                        attributes = attributes,
                        indices = indices,
                        material = material
                    })
                end
            end

            table.insert(meshes, {
                primitives = primitives
            })
        end
    end

    local function getMeshCopyWithInvertedWinding(mesh)
        local invMesh = table.deep_copy(mesh)

        for _, primitive in ipairs(invMesh.primitives) do
            local indices = primitive.indices
            local attrsCount = #primitive.attributes

            local trianglesCount = #indices / attrsCount / 3

            for triangleIndex = 0, trianglesCount - 1 do
                local vertexIndex = triangleIndex * 3

                for attrIndex = 1, attrsCount do
                    local attrIndexInVertexA = vertexIndex * attrsCount + attrIndex
                    local attrIndexInVertexC = (vertexIndex + 2) * attrsCount + attrIndex

                    local temp = indices[attrIndexInVertexC]

                    indices[attrIndexInVertexC] = indices[attrIndexInVertexA]
                    indices[attrIndexInVertexA] = temp
                end
            end
        end

        return invMesh
    end

    for _, node in ipairs(nodes) do
        if node.mesh and not meshes[node.mesh] then
            error("node " .. node.name .. " using undefined mesh with index " .. node.mesh)
        end
    end

    local animations = { }

    if gltfTable.animations then
        for _, animationInfo in ipairs(gltfTable.animations) do
            local usedNodeIndices = { }
            local nodePathSamplers = { }

            local nodeAnimations = { }

            for _, channelInfo in ipairs(animationInfo.channels) do
                local target = channelInfo.target

                local nodeIndex = target.node + 1

                if not nodes[nodeIndex] then
                    error("node with index " .. (nodeIndex - 1) .. " used in animation " .. animationInfo.name .. " is undefined")
                end

                if hasNodeInScene(nodeIndex) then
                    local samplerIndex = channelInfo.sampler + 1

                    if not animationInfo.samplers[samplerIndex] then
                        error("sampler with index " .. (nodeIndex - 1) .. " used in animation " .. animationInfo.name .. " is undefined")
                    end

                    if not table.has(animationChannelTargetPaths, target.path) then
                        error("invalid animation channel target path: " .. target.path)
                    end

                    if table.has(supportedAnimationChannelTargetPaths, target.path) then
                        table.insert_unique(usedNodeIndices, nodeIndex)

                        local obj = nodePathSamplers[nodeIndex] or { }

                        obj[target.path] = samplerIndex

                        nodePathSamplers[nodeIndex] = obj
                    else
                        warning("animation channel targets with path '" .. target.path .. "' is not supported by this loader. skipping it")
                    end
                end
            end

            for _, nodeIndex in ipairs(usedNodeIndices) do
                for path, samplerIndex in pairs(nodePathSamplers[nodeIndex]) do
                    local sampler = animationInfo.samplers[samplerIndex]

                    local timesAccessor = getAccessor(sampler.input)
                    local valuesAccessor = getAccessor(sampler.output)

                    if timesAccessor.type ~= SCALAR or timesAccessor.componentType ~= FLOAT then
                        error(
                                "sampler input accessor must have SCALAR type and FLOAT ("
                                .. FLOAT .. ") component type"
                        )
                    end

                    if valuesAccessor.type ~= animationChannelTargetPathDataTypes[path] then
                        error(
                                "sampler output accessor must have "
                                        .. animationChannelTargetPathDataTypes[path]
                                        .. " type for channel targets with path '" .. path .. "'"
                        )
                    end

                    local interpolationType = sampler.interpolation or animationInterpolationTypeLinear

                    if not table.has(animationInterpolationTypes, interpolationType) then
                        error("unknown interpolation type " .. interpolationType)
                    end

                    if table.has(supportedAnimationInterpolationTypes, interpolationType) then
                        if not nodeAnimations[nodeIndex] then
                            nodeAnimations[nodeIndex] = { }
                        end

                        local keyframes = { }

                        local times = timesAccessor.values
                        local values = valuesAccessor.values

                        for i = 1, #times do
                            local value, inTangent, outTangent

                            if interpolationType == animationInterpolationTypeCubicSpline then
                                inTangent = values[(i - 1) * 3 + 1]
                                value = values[(i - 1) * 3 + 2]
                                outTangent = values[(i - 1) * 3 + 3]

                                if path == targetRotationPath then
                                    inTangent = vec4XyzwToWxyz(inTangent)
                                    outTangent = vec4XyzwToWxyz(outTangent)
                                end
                            else
                                value = values[i]
                            end

                            if path == targetRotationPath then
                                value = quat_math.normalize(quat_math.from_xyzw(value))
                            end

                            keyframes[i] = {
                                time = times[i],
                                value = value,
                                inTangent = inTangent,
                                outTangent = outTangent
                            }
                        end

                        nodeAnimations[nodeIndex][path] = {
                            interpolation = interpolationType,
                            keyframes = keyframes
                        }
                    else
                        warning("interpolation type " .. interpolationType .. " is not supported. skipping this channel")
                    end
                end
            end

            table.insert(animations, {
                name = animationInfo.name,
                nodes = nodeAnimations
            })
        end
    end

    local finalNodes = { }
    local finalMeshes = { }

    local windingDefaultMeshesMap = { }
    local windingInvertedMeshesMap = { }

    for nodeIndex, node in ipairs(nodes) do
        if hasNodeInScene(nodeIndex) then
            local nodeCopy = table.deep_copy(node)

            local meshIndex = nodeCopy.mesh

            if meshIndex then
                if mat4.determinant(getNodeGlobalMatrix(nodeCopy)) >= 0 then
                    if not windingDefaultMeshesMap[meshIndex] then
                        table.insert(finalMeshes, meshes[meshIndex])
                        windingDefaultMeshesMap[meshIndex] = #finalMeshes
                    end

                    meshIndex = windingDefaultMeshesMap[meshIndex]
                else
                    if not windingInvertedMeshesMap[meshIndex] then
                        table.insert(finalMeshes, getMeshCopyWithInvertedWinding(meshes[meshIndex]))
                        windingInvertedMeshesMap[meshIndex] = #finalMeshes
                    end

                    meshIndex = windingInvertedMeshesMap[meshIndex]
                end

                nodeCopy.mesh = meshIndex
            end

            if nodeCopy.children then
                local newChildren = { }

                for _, childIndex in ipairs(nodeCopy.children) do
                    if hasNodeInScene(childIndex) then
                        table.insert(newChildren, childIndex)
                    end
                end

                nodeCopy.children = newChildren
            end

            table.insert(finalNodes, nodeCopy)
        end
    end

    --[[
    nodes = {
        {
            name: string,
            mesh: int,
            translation: vec3,
            rotation: quat,
            scale: vec3,
            matrix: mat4,
            [optional] children: table<int>,
            [optional] parent: int
        },
        ...
    },

    meshes = {
        {
            primitives: {
                {
                    attributes = {
                        {
                            type: string, -- may POSITION|NORMAL|TEXCOORD_0|COLOR_0
                            values: any -- vec3 for POSITION, NORMAL; vec2 for TEXCOORD_0; vec3|vec4 for COLOR_0
                        }
                    },
                    indices: table<int> -- { [attr_1_value_1], [attr_2_value_1], [attr_3_value_1], ... } , every 3 indices is one vertex
                    material = {
                        texture: string
                    }
                },
                ...
            }
        },
        ...
    },

    animations = {
        {
            name: string,
            nodes = {
                [targetNodeIndex] = {
                    [targetPath] = { -- may "translation|rotation|scale"
                        interpolation: string -- may "STEP|LINEAR|CUBICSPLINE",
                        keyframes = {
                            { -- in/out Tangents defined only when interpolation == "CUBICSPLINE"
                                time: number,
                                value: vec3|vec4,
                                [optional] inTangent: vec3|vec4,
                                [optional] outTangent: vec3|vec4
                            },
                            ...
                        }
                    }
                },
                ...
            }
        },
        ...
    }
    ]]--
    return {
        nodes = finalNodes,
        meshes = finalMeshes,
        animations = animations
    }
end

function M.load(value, loadSettings)
    local data = M.extract_gltf_data(value, loadSettings)


end

return M