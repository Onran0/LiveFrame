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
        -- массив, с помощью которого можно определить, какие каналы были релятивизированы
        relativizedKeys: table = {
            "position", "rotation", "scale"
        },
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
            [индекс-интерполируемого-типа] = { -- для трехмерных векторов (позиция, масштаб) индекс 1, для кватернионов (вращение) - 2
                "имя-поля-1",
                ...   
            }
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