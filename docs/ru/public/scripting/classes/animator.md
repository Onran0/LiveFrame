# Класс animator

```lua
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