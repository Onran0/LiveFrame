# Класс player

**Описание**

Используется для простого проигрывания анимаций.

**Используемые классы & объекты:**
- [sampler](../objects/sampler.md);
- [transform](../objects/transform.md).

```lua
-- Начинает проигрывание клипа по имени
player:play(clipName: string)

-- Начинает проигрывание клипа по его индексу (индекс также можно получить через класс sampler)
player:play_by_index(clipIndex: int)

-- Задаёт обработчик для конкретного ивента (см. modules/api.md)
player:set_event_handler(eventName: string, eventHandler: function)

-- Задаёт функцию пост-обработки для конкретной кости.
player:set_post_processor(
    -- Имя кости в скелете
    rigName: string,

    -- Функция принимает позу кости от проигрывателя и возвращает итоговую, что будет записана в скелет
    postProcessor: function(pose: transform) -> transform
)

-- Задаёт глобальную функцию пост-обработки.
player:set_global_post_processor(
    -- Функция принимает индекс кости и её позу от проигрывателя и возвращает итоговую, что будет записана в скелет.
    -- Если для этой кости также есть локальный пост-обработчик, то он получит результат от глобального пост-обработчика.
    postProcessor: function(rigIndex: int, pose: transform) -> transform
)

-- Возвращает имя текущего клипа
player:get_playing_clip_name() -> string

-- Возвращает индекс текущего клипа
player:get_playing_clip_index() -> int

-- Возвращает длительность текущего клипа
player:get_clip_duration() -> number

-- Возвращает время проигрывания текущего клипа в секундах
player:get_time() -> number

-- Задаёт время проигрывания текущего клипа в секундах
player:set_time(time: number)

-- Сбрасывает время проигрывания текущего клипа
player:reset()

-- Возвращает нормализованное время проигрывания текущего клипа
player:get_normalized_time() -> number

-- Задаёт нормализованное время проигрывания текущего клипа
player:set_normalized_time(normTime: number)

-- Возвращает true, если сейчас проигрыватель зациклен
player:is_looped() -> boolean

-- Задаёт зацикленность проигрывателя
player:set_loop(loop: boolean)

-- Возвращает текущую скорость проигрывателя
player:get_speed() -> number

-- Задаёт текущую скорость проигрывателя
player:set_speed(speed: number)

-- Возвращает true, если проигрывание клипа завершилось
player:is_end() -> boolean

-- Ставит на паузу проигрыватель
player:pause()

-- Возвращает true, если сейчас проигрыватель на паузе
player:is_paused() -> boolean

-- Снимает проигрыватель с паузы
player:resume()

-- Останавливает проигрывание текущего клипа
player:stop()

-- Выполняет следующий шаг проигрывателя, принимая время в секундах, прошедшее с предыдущего
-- вызова. Функция должна вызываться каждый кадр
player:step(delta: number)

-- Возвращает сэмплер, используемый проигрывателем (см. classes/sampler.md)
player:get_sampler() -> sampler

-- Переназначает сэмплер проигрывателю
player:set_sampler(newSampler: sampler)

-- Задаёт новый скелет для применения трансформаций
player:set_skeleton(skeleton: table)
```