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

--[[
result format:
{
    {
        type = "scope",
        attributes = {
            interp = "lerp",
            ["rotation-interp"] = "squad"
        },
        children = {
            {
                type = "bone",
                attributes = {
                    name = "body"
                },
                parent = <table_ref>,
                children = {
                    {
                        {
                            type = "position",
                            attributes = {
                                value = { 0, 1, 2 }
                            },
                            parent = <table_ref>
                        },
                        {
                            type = "rotation",
                            attributes = {
                                value = { 90, 2, 0 },
                                ["rotation-interp"] = "slerp"
                            },
                            parent = <table_ref>
                        }
                    }
                }
            }
        }
    }
}
]]--

local delimiters = " \t"
local newLineChars = "\r\n"
local elementEndChars = "@{\n"
local numberChars = '-0123456789.'

local M = { }

local function find(str, char)
    for i = 1, utf8.length(str) do
        if utf8.sub(str, i, i) == char then
            return i
        end
    end
end

local function contains(str, char)
    return find(str, char) ~= nil
end

local function parseAttributeValue(value)
    local firstChar = utf8.sub(value, 1, 1)

    if contains(numberChars, firstChar) then
        local num = tonumber(value)

        if not num then error('invalid number: ' .. value) end

        return num
    elseif firstChar == '"' then
        local i = utf8.length(value)

        if utf8.sub(value, i, i) ~= '"' then
            error('string literal must be end with quote char: ' .. value)
        end

        return utf8.sub(value, 2, utf8.length(value) - 1)
    elseif firstChar == '(' then
        local values = { }

        local buffer = ""
        local inQuote = false
        local bracketsCount = 0

        for i = 2, utf8.length(value) do
            local char = utf8.sub(value, i, i)

            if char == '"' then
                inQuote = not inQuote
            end

            if (bracketsCount == 0 and char == ',' or i == utf8.length(value)) and not inQuote then
                table.insert(values, parseAttributeValue(buffer:trim()))

                buffer = ""
            else
                buffer = buffer .. char
            end

            if char == '(' then
                bracketsCount = bracketsCount + 1
            elseif char == ')' then
                bracketsCount = bracketsCount - 1
            end
        end

        return values
    elseif value == "true" then
        return true
    elseif value == "false" then
        return false
    else
        local separatorIndex = find(value, ":")

        if separatorIndex and utf8.length(value) > separatorIndex then
            return {
                key = utf8.sub(value, 1, separatorIndex - 1),
                value = parseAttributeValue(utf8.sub(value, separatorIndex + 1, utf8.length(value)):trim())
            }
        else
            error('invalid value: "' .. value .. '"')
        end
    end
end

function M.parse(text, offset, hasParent)
    text = text
            :replace("\r\n", "\n") -- CRLF to LF
            :replace("\r", "\n") -- CR to LF

    local result = { }

    local parsingElement = false
    local parsingAttributeName = false
    local parsingAttributeValue = false

    local buffer = ""

    local attributeName

    local elementType
    local elementAttributes = { }

    local inQuote = false
    local bracketsCount = 0

    local length = utf8.length(text)
    local i = offset or 1

    while i <= length do
        local char = utf8.sub(text, i, i)

        if parsingAttributeName then
            if contains(newLineChars, char) then
                error(i .. ": unexpected new line")
            end

            if contains(delimiters, char) then
                attributeName = buffer
                buffer = ""

                parsingAttributeName = false
                parsingAttributeValue = true
            else
                buffer = buffer .. char
            end
        elseif parsingAttributeValue then
            local endOfVal = false

            if contains(newLineChars, char) then
                if inQuote or bracketsCount > 0 then
                    error(i .. ": unexpected new line")
                else
                    endOfVal = true
                end
            end

            if contains(delimiters, char) then
                if not inQuote and bracketsCount == 0 and #buffer > 0 then
                    endOfVal = true
                end
            end

            if endOfVal then
                elementAttributes[attributeName] = parseAttributeValue(buffer:trim())

                attributeName = nil
                buffer = ""

                parsingAttributeValue = false
                i = i - 1
            else
                if char == '"' then
                    inQuote = not inQuote
                elseif not inQuote then
                    if char == '(' then
                        bracketsCount = bracketsCount + 1
                    elseif char == ')' then
                        bracketsCount = bracketsCount - 1
                    end
                end

                buffer = buffer .. char
            end
        elseif parsingElement then
            if not elementType then
                if contains(newLineChars, char) then
                    error(i .. ": unexpected new line")
                end

                if contains(delimiters, char) then
                    if #buffer == 0 then
                        error(i .. ": element type can't be empty")
                    end

                    elementType = buffer
                    buffer = ""
                else
                    buffer = buffer .. char
                end
            elseif not contains(delimiters, char) then
                if contains(elementEndChars, char) then
                    local elementTable = {
                        type = elementType,
                        attributes = elementAttributes
                    }

                    if char == '{' then
                        local elementChildren, newOffset = M.parse(text, i + 1, true)

                        i = newOffset

                        for j = 1, #elementChildren do
                            elementChildren[j].parent = elementTable
                        end

                        elementTable.children = elementChildren
                    end

                    table.insert(result, elementTable)

                    elementType = nil
                    elementAttributes = { }

                    parsingElement = false
                    i = i - 1
                else
                    parsingAttributeName = true
                    i = i - 1
                end
            end
        else
            if char == '@' then
                parsingElement = true
            elseif not contains(delimiters, char) and not contains(newLineChars, char) then
                if char == '}' and hasParent then
                    return result, i + 1
                else
                    error(i .. ": unexpected character '" .. char .. "`")
                end
            end
        end

        i = i + 1
    end

    return result
end

return M