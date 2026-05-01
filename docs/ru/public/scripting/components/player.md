# Компонент liveframe:player

Этот компонент используется для простой интеграции проигрывателя анимаций в вашу сущность.

> [!NOTE]
> Поскольку вам, скорее всего, придётся использовать данный компонент уже в инициализации
> вашего собственного, в массиве компонентов в определении сущности, компонент проигрывателя
> должен быть определён раньше, чем ваш, чтобы на момент загрузки вашего он уже был
> инициализирован.

## Аргументы компонента

### Одиночный режим
- `path` - путь к файлу с анимационными клипами;

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
- `paths` - пути к файлам с анимационными клипами;
- `override-clip-names` - таблица с переопределниями имён некоторых клипов (см. [liveframe:api](../modules/api.md)).

Пример:
```json
{
    "name": "liveframe:player",
    "args": {
        "paths": [
            "packid:animations/some_clips_1.lfa",
            "packid:animations/some_clips_2.lfa"
        ],
        "override-clip-names": [
            {
                "walk": "walk_1"
            },
            {
                "walk": "walk_2"
            }
        ]
    }
}
```

## Функции

```lua
-- Возвращает объект самого проигрывателя анимаций
player.get_player() -> player

--Задаёт обработчик конкретного ивента
player.set_event_handler(name: string, func: function)
```

Пример:
```lua
local player = entity:require_component("liveframe:player").get_player()

player:play("walk_1")
```

> [!WARNING]
> Вызывать `player:step(delta)` не нужно! Это делается компонентом автоматически.