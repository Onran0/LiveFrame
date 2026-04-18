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

local function contains(str, char)
    for i = 1, #str do
        if str[i] == char then
            return true
        end
    end

    return false
end

local function parseAttributeValue(value)
    local firstChar = value[1]

    if contains(numberChars, firstChar) then
        local num = tonumber(value)

        if not num then error('invalid number: ' .. value) end

        return num
    elseif firstChar == '"' then
        return value:sub(2, #value - 1)
    elseif firstChar == '(' then
        local values = { }

        local buffer = ""
        local inQuote = false

        for i = 2, #value do
            local char = value[i]

            if char == '"' then
                inQuote = not inQuote
            end

            if (char == ',' or char == ')') and not inQuote then
                table.insert(values, parseAttributeValue(buffer:trim()))

                buffer = ""
            else
                buffer = buffer .. char
            end
        end

        return values
    elseif value == "true" then
        return true
    elseif value == "false" then
        return false
    else
        error('invalid value: ' .. value)
    end
end

function M.parse(text, offset, hasParent)
    local result = { }

    local parsingElement = false
    local parsingAttributeName = false
    local parsingAttributeValue = false

    local buffer = ""

    local attributeName

    local elementType
    local elementAttributes = { }

    local inQuote = false
    local inBrackets = false

    local length = #text
    local i = offset or 1

    while i <= length do
        local char = text[i]

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
                if inQuote or inBrackets then
                    error(i .. ": unexpected new line")
                else
                    endOfVal = true
                end
            end

            if contains(delimiters, char) then
                if not inQuote and not inBrackets and #buffer > 0 then
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
                        if inBrackets then
                            error(i .. ": unexpected opening bracket")
                        end

                        inBrackets = true
                    elseif char == ')' then
                        if not inBrackets then
                            error(i .. ": unexpected closing bracket")
                        end

                        inBrackets = false
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