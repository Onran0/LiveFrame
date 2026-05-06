# Компонент liveframe:player

Этот компонент используется для простой интеграции проигрывателя анимаций в вашу сущность.

> [!NOTE]
> Поскольку вам, скорее всего, придётся использовать данный компонент уже в инициализации
> вашего собственного, в массиве компонентов в определении сущности, компонент проигрывателя
> должен быть определён раньше, чем ваш, чтобы на момент загрузки вашего он уже был
> инициализирован.

## Аргументы компонента

### Одиночный режим

Аргументы те же, что и в [clips_file_data](../objects/clips_file_data.md).

Пример:
```json
{
    "name": "liveframe:player",
    "args": {
        "path": "packid:animations/some_clips.lfa"
    }
}
```

### Мульти-режим

- `files` - массив, где каждый элемент либо строка с путём к файлу, либо
[clips_file_data](../objects/clips_file_data.md).

Пример:
```json
{
    "name": "liveframe:player",
    "args": {
        "files": [
            "packid:animations/some_clips_1.lfa",
            {
                "path": "packid:animations/some_clips_2.lfa",
                "overrides": {
                    "walk": "walk_2"
                }
            }
        ]
    }
}
```

## Функции

```lua
-- Возвращает объект самого проигрывателя анимаций
component.get() -> player
```

Пример:
```lua
local player = entity:require_component("liveframe:player").get()

player:play("walk")
```

> [!WARNING]
> Вызывать `player:step(delta)` не нужно! Это делается компонентом автоматически.