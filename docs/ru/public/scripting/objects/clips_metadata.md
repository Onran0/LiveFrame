# Объект clips_metadata

**Описание**

Используется для хранения необходимых и оптимизированных данных для проигрывания клипов.

**Структура**

> [!NOTE]
> Дочерние объекты: [clip](clip.md)

```lua
clips_metadata = {
    -- дополнительные общие данные
    metadata: table = {
        -- были ли релятивизированы все трансформации клипов
        relativizedTransforms: boolean,
        -- общий скелет для всех клипов
        skeleton: table = {
            ["имя кости"]: table = {
                position: vec3 = { x: number, y: number, z: number },
                rotation: quat = { w: number, x: number, y: number, z: number },
                scale: vec3 = { x: number, y: number, z: number }
            },
            ...
        }
    },

    -- общие индексы клипов для типов интерполяций в клипах (например, lerp)
    interpTypesIndices: table<string> = {
        ["имя-типа-интерполяции"],
        ...
    },

    -- общие индексы для конкретных полей типов интерполяций (например, in/out-tangent в cubic-spline)
    interpFieldsIndices: table<string=table<string>> = {
        ["имя-типа-интерполяции"] = {
            "имя-поля-1",
            ...
        }
    },

    -- общие индексы костей
    bonesIndices: table<string> = {
        "имя-кости",
        ...
    },

    -- массив с описанием клипов
    clips: table<clip>
}
```