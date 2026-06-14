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

local M = { }

local operators = {
    "!",
    "==",
    "!=",
    ">",
    "<",
    ">=",
    "<="
}

local operatorChars = ""
local digits = "0123456789"
local numChars = "-.," .. digits

local delimiters = "\t "

for _, operator in ipairs(operators) do
    for i = 1, #operator do
        local char = operator[i]

        if not operatorChars:find(char, 1, true) then
            operatorChars = operatorChars .. char
        end
    end
end

function M.parse(condition)
    -- crutch for insert end token
    condition = condition .. " "

    local tokens = { }

    local parsingWord, parsingOperator, parsingNumber

    local buffer = ""

    local i = 1

    while i <= utf8.length(condition) do
        local char = utf8.sub(condition, i, i)

        if parsingWord then
            if delimiters:find(char, 1, true) or operatorChars:find(char, 1, true) then
                if buffer == "true" or buffer == "false" then
                    table.insert(tokens, {
                        type = "boolean",
                        value = buffer == "true"
                    })
                else
                    table.insert(tokens, {
                        type = "parameter",
                        value = buffer
                    })
                end

                i = i - 1
                buffer = ""
                parsingWord = false
            elseif numChars:find(char, 1, true) and not digits:find(char, 1, true) then
                error("unexpected special symbol in parameter name at column " .. i)
            else
                buffer = buffer .. char
            end
        elseif parsingOperator then
            if not operatorChars:find(char, 1, true) then
                table.insert(tokens, {
                    type = "operator",
                    value = buffer
                })

                i = i - 1
                buffer = ""
                parsingOperator = false
            else
                buffer = buffer .. char
            end
        elseif parsingNumber then
            if not numChars:find(char, 1, true) then
                local num = tonumber(buffer)

                if not num then
                    error("invalid number at column " .. i .. ": " .. buffer)
                end

                table.insert(tokens, {
                    type = "number",
                    value = num
                })

                i = i - 1
                buffer = ""
                parsingNumber = false
            else
                buffer = buffer .. char
            end
        elseif not delimiters:find(char, 1, true) then
            if operatorChars:find(char, 1, true) then
                parsingOperator = true
            elseif numChars:find(char, 1, true) then
                parsingNumber = true
            else
                parsingWord = true
            end

            i = i - 1
        end

        i = i + 1
    end

    return tokens
end

function M.validate(params, tokens)
    if #tokens > 3 or #tokens == 0 then
        error("tokens count must be 3 (operand + operator + operand), or 2 (logic not + boolean operand), or 1 (boolean operand)")
    end

    local function getOperandType(token)
        if token.type == "parameter" then
            local type

            for i = 1, #params do
                if params[i].name == token.value then
                    type = params[i].type
                    break
                end
            end

            if not type then
                error("undefined animator parameter: '" .. token.value .. "'")
            end

            if type == "trigger" then
                type = "boolean"
            end

            return type
        else
            return token.type
        end
    end

    if #tokens == 3 then
        if tokens[1].type == "operator" then
            error("first token must be operand")
        end

        if tokens[2].type ~= "operator" then
            error("second token must be operator")
        end

        if tokens[3].type == "operator" then
            error("third token must be operand")
        end

        local paramNames = { }

        for _, param in ipairs(params) do
            table.insert(paramNames, param.name)
        end

        for i = 1, 3 do
            local token = tokens[i]

            if token.type == "operator" then
                if not table.has(operators, token.value) then
                    error("invalid operator: " .. token.value)
                elseif token.value == "!" then
                    error("operator '!' is unary")
                end
            elseif token.type == "parameter" then
                if not table.has(paramNames, token.value) then
                    error("invalid parameter: " .. token.value)
                end
            end
        end

        local leftType = getOperandType(tokens[1])
        local rightType = getOperandType(tokens[3])

        if leftType ~= rightType then
            error("operand types is different ('" .. leftType .. "' and '" .. rightType .. "')")
        end
    else
        local operandIndex = 1

        if #tokens == 2 then
            if tokens[1].type ~= "operator" or tokens[1].value ~= "!" then
                error("in single operand expression first token must be logic-not operator")
            end

            operandIndex = 2
        end

        if tokens[operandIndex].type == "operator" then
            error("in single operand expression second token must be operand")
        end

        if getOperandType(tokens[operandIndex]) ~= "boolean" then
            error("in single operand expression operand must have boolean type")
        end
    end
end

function M.load(params, conditions)
    if type(conditions) == "string" then
        conditions = { conditions }
    end

    local luaExpressions = { }

    for i = 1, #conditions do
        local tokens = M.parse(conditions[i])

        M.validate(params, tokens)

        local expr = ""

        if #tokens == 3 then
            local operator = tokens[2].value

            expr = expr .. tostring(tokens[1].value) .. " "
            expr = expr .. (operator == "!=" and "~=" or operator) .. " "
            expr = expr .. tostring(tokens[3].value)
        else
            local operandIndex = 1

            if #tokens == 2 then
                expr = expr .. "not "

                operandIndex = 2
            end

            expr = expr .. tostring(tokens[operandIndex].value)
        end

        table.insert(luaExpressions, expr)
    end

    local finalExpr = "local "

    for _, param in ipairs(params) do
        finalExpr = finalExpr .. param.name .. ", "
    end

    finalExpr = finalExpr:sub(1, #finalExpr - 2) .. " = ...; return "

    if #luaExpressions < 2 then
        finalExpr = finalExpr .. luaExpressions[1]
    else
        for i = 1, #luaExpressions do
            local expr = luaExpressions[i]

            finalExpr = finalExpr .. "(" .. expr .. ") and "
        end

        finalExpr = finalExpr:sub(1, #finalExpr - 5)
    end

    return finalExpr, load(finalExpr)
end

return M