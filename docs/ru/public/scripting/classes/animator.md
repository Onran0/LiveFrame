# Класс animator

**Описание**

Используется для более сложного проигрывания анимаций с использованием переходов, смешиванием и слоёв
(см. подробнее в [animators](../../animators.md)).

**Используемые классы & объекты:**
- [sampler](../objects/sampler.md);
- [transform](../objects/transform.md).

```lua
-- Задаёт обработчик для конкретного ивента (см. modules/api.md)
animator:set_event_handler(eventName: string, eventHandler: function)

-- Задаёт функцию пост-обработки для конкретной кости.
player:set_post_processor(
    -- Имя кости в скелете
    rigName: string,
    
    -- Функция принимает позу кости от аниматора и возвращает итоговую, что будет записана в скелет
    postProcessor: function(pose: transform) -> transform
)

-- Задаёт глобальную функцию пост-обработки.
player:set_global_post_processor(
    -- Функция принимает индекс кости и её позу от аниматора и возвращает итоговую, что будет записана в скелет.
    -- Если для этой кости также есть локальный пост-обработчик, то он получит результат от глобального пост-обработчика.
    postProcessor: function(rigIndex: int, pose: transform) -> transform
)

-- Задаёт значение булевому параметру аниматора
animator:set_boolean(name: string, value: boolean)

-- Задаёт значение булевому параметру аниматора
animator:set_number(name: string, value: number)

-- Активирует триггер аниматора
animator:set_trigger(name: string)

-- Возвращает текущую скорость течения времени в аниматоре
animator:get_speed() -> number

-- Задаёт текущую скорость течения времени в аниматоре
animator:set_speed(speed: number)

-- Возвращает true, если аниматор стоит на паузе
animator:is_paused() -> boolean

-- Ставит аниматор на паузу
animator:pause()

-- Снимает аниматор с паузы
animator:resume()

-- Или ставит аниматор на паузу, или снимает с неё, в зависимости от аргумента
animator:set_paused(paused: boolean)

-- Выполняет следующий шаг аниматора, принимая время в секундах, прошедшее с предыдущего
-- вызова. Функция должна вызываться каждый кадр
animator:step(delta: number)

-- Возвращает сэмплер, используемый аниматором (см. classes/sampler.md)
animator:get_sampler() -> sampler

-- Задаёт новый скелет для применения трансформаций
animator:set_skeleton(skeleton: table)
```