# Модуль liveframe:api

Данный модуль используется для взаимодействия сторонних контент-паков с **LiveFrame**
и его функционалом.

## Настройки загрузки

При создании проигрывателя или объявлении аниматора можно дополнительно
определить некоторые настройки загрузки файла. Они описаны [здесь](../../load_settings.md).

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
        entity.skeleton,
        "packid:animators/some_entity.json"
)

animator:set_event_handler("attack", function()
    print("ATTACK!")
end)

animator:set_speed(1.0)

animator:set_boolean("playWalk", true)
```

## Создание простого проигрывателя

Возвращает [player](../classes/player.md).

```lua
api.create_player(
        -- целевой скелет сущности, на который будут применяться трансформации
        skeleton: table,

        --[[
        массив с данными о файлах с клипами, где каждый элемент это путь к файлу
        в виде строки, либо clips_file_data
        ]]--
        filesData: ...
) -> player
```

Примеры:

**Один файл**

```lua
local liveframe = require "liveframe:api"

local player = liveframe.create_player(
        entity.skeleton,
        "packid:animations/some_clips.lfa"
)

player:set_event_handler("attack", function()
    print("ATTACK!")
end)

player:set_speed(1.0)
```

**Несколько файлов**

```lua
local liveframe = require "liveframe:api"

local player = liveframe.create_player(
        entity.skeleton,
        "packid:animations/some_clips_1.lfa",
        {
            filePath = "packid:animations/some_clips_2.lfa",
            overrides = {
                walk = "walk_2"
            },
            loadSettings = {
                relativizeTransforms = true
            }
        }
)

player:set_event_handler("attack", function()
    print("ATTACK!")
end)

player:play("walk_2")
```

> [!WARNING]
> Обратите внимание на то, что вам придется вручную каждый кадр вызывать `player:step(delta)`
> или `animator:step(delta)`, так как созданный проигрыватель/загрузчик не привязан к компоненту.