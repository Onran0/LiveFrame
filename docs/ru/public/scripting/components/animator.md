# Компонент liveframe:animator

Этот компонент используется для более сложного анимирования с использованием состояний, переходов и слоёв.

> [!NOTE]
> Поскольку вам, скорее всего, придётся использовать данный компонент уже в инициализации
> вашего собственного, в массиве компонентов в определении сущности, компонент аниматора
> должен быть определён раньше, чем ваш, чтобы на момент загрузки вашего он уже был
> инициализирован.

## Аргументы компонента

- `path` - путь к файлу с описанием аниматора;

Пример:
```json
{
    "name": "liveframe:animator",
    "args": {
        "path": "packid:animators/some_animator.json"
    }
}
```

## Функции

```lua
-- Возвращает обьект самого аниматора
animator.get_player() -> animator

--Задаёт обработчик конкретного ивента
animator.set_event_handler(name: string, func: function)
```

Пример:
```lua
local animator = entity:require_component("liveframe:animator").get_animator()

animator:set_boolean("walk", true)
```

> [!WARNING]
> Вызывать `animator:step(delta)` не нужно! Это делается компонентом автоматически.