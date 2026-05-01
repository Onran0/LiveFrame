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

```lua
api.create_animator(
        -- путь к файлу с описанием аниматора
        filePath: string,
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table,
        -- таблица, содержащая обработчики разных ивентов
        [опционально] eventHandlers: table<string=function>
) -> animator
```

Пример:
```lua
local liveframe = require "liveframe:api"

local animator = liveframe.create_animator(
        "packid:animators/some_entity.json",
        entity.skeleton,
        {
            attack = function()
                print("ATTACK!")
            end
        }
)

animator:set_speed(1.0)
animator:set_boolean("playWalk", true)
```

## Создание простого проигрывателя

```lua
api.create_player(
        -- путь к файлу с анимационными клипами
        filePath: string,
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table,
        -- таблица, содержащая обработчики разных ивентов
        [опционально] eventHandlers: table<string=function>
) -> player
```

```lua
api.create_player_multi(
        -- пути к файлам с анимационными клипами
        filePaths: table<string>,
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table,
        --[[ таблица, позволяющая переопределить имена клипов при загрузке. формат:
        {
            [индекс файла в массиве filePaths] = {
                прежнее_название_клипа = новое_название_клипа,
                ...
            }
        }
        ]]--
        [опционально] overrideClipNames: table<int=table<string=string>>
        -- таблица, содержащая обработчики разных ивентов
        [опционально] eventHandlers: table<string=function>
) -> player
```

Примеры:

```lua
local liveframe = require "liveframe:api"

local player = liveframe.create_player(
        "packid:animations/some_clips.lfa",
        entity.skeleton,
        {
            attack = function()
                print("ATTACK!")
            end
        }
)

player:set_speed(1.0)
```

```lua
local liveframe = require "liveframe:api"

local player = liveframe.create_player_multi(
        {
            "packid:animations/some_clips_1.lfa",
            "packid:animations/some_clips_2.lfa"
        },
        entity.skeleton,
        {
            {
                walk = "walk_1"
            },
            {
                walk = "walk_2"
            }
        },
        {
            attack = function()
                print("ATTACK!")
            end
        }
)

player:play("walk_2")
```