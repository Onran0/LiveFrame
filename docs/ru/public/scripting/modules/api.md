# Модуль liveframe:api

Данный модуль используется для взаимодействия сторонних контент-паков с **LiveFrame**
и его функционалом.

## Обработчики ивентов

**LiveFrame** поддерживает события клипов, которые можно перехватывать с помощью
некоторых инструментов **API**.\

Функция обработчика принимает следующие аргументы в контексте аниматора:
```lua
function(eventValue: any, stateName: string, layerIndex: int, stateObject: table, clipObject: table)
    ...
end
```

И следующие в контексте простого проигрывателя:
```lua
function(eventValue: any, clipName: string, clipObject: table)
    ...
end
```

## Создание аниматора

Возвращает [animator](../classes/animator.md).

```lua
api.create_animator(
        -- путь к файлу с описанием аниматора
        filePath: string,
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table
) -> animator
```

Пример:
```lua
local liveframe = require "liveframe:api"

local animator = liveframe.create_animator(
        "packid:animators/some_entity.json",
        entity.skeleton
)

animator:set_event_handler("attack", function()
    print("ATTACK!")
end)

animator:set_speed(1.0)

animator:set_boolean("playWalk", true)
```

## Создание простого проигрывателя

Возвращают [player](../classes/player.md).

```lua
api.create_player(
        -- путь к файлу с анимационными клипами
        filePath: string,
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table
) -> player
```

```lua
api.create_player_multi(
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table,
        
        --[[
        массив с данными о файлов с клипами, где каждый элемент это путь к файлу
        в виде строки, либо таблица с дополнительными данными в следующем формате:
        {
            path = "путь к файлу с клипами",
        
            -- таблица, позволяющая переопределить названия некоторых клипов из файла
            [опционально] overrides = {
                старое_имя_клипа = "новое_имя_клипа",
                ...
            }
        }
        ]]--
        filesData: ...
) -> player
```

Примеры:

```lua
local liveframe = require "liveframe:api"

local player = liveframe.create_player(
        "packid:animations/some_clips.lfa",
        entity.skeleton
)

player:set_event_handler("attack", function()
    print("ATTACK!")
end)

player:set_speed(1.0)
```

```lua
local liveframe = require "liveframe:api"

local player = liveframe.create_player_multi(
        entity.skeleton,
        "packid:animations/some_clips_1.lfa",
        {
            filePath = "packid:animations/some_clips_2.lfa",
            overrides = {
                walk = "walk_2"
            }
        }
)

player:set_event_handler("attack", function()
    print("ATTACK!")
end)

player:play("walk_2")
```