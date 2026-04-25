# Аниматоры

Аниматоры предназначены для высокоуровневого управления анимациями: Слои, Состояния, Смешивания.

Аниматоры декларируются в **JSON** файлах в следующем формате:

## Свойства

- `clips` - массив, с помощью которого определяются файлы с клипами и откуда их импортировать;
- - `id` - идентификатор файла в аниматоре;
- - `file` - путь к файлу с клипами в формате `packid:folder/file.format`.

- `parameters` - массив с определениями параметров аниматора, которые могут использоваться
в условиях или `blend-tree`;
- - `name` - название параметра;
- - `type` - тип параметра. допустимые значения: `boolean`, `number`, `trigger`.
`trigger` - это `boolean`, который автоматически сбрасывается аниматором на `false` в
следующем кадре;

- `layers` - массив со слоями аниматора;
- - `name` - имя слоя;
- - `*blend-mode` - режим смешивания слоя со следующим. на данный момент доступен и используется
только `override` (перезапись всего по маске);
- - `*weight` - вес слоя, использующийся при смешивании. по-умолчанию равен `1.0`;
- - `default-state` - имя состояния слоя по-умолчанию;
- - `states` - массив с состояниями слоя;
- - - `name` - название состояния;
- - - `*type` - тип состояния. доступные значения: `clip`. по-умолчанию: `clip`;
- - - `*clip` - идентификатор клипа для состояния в формате `file_id:clip_id`. используется при
`type=clip`;
- - - `*loop` - свойство, определяющее будет ли состояние циклично проигрываться. значение по-умолчанию:
`false`;
- - `transitions` - массив с переходами слоя.
- - - `from` - имя состояния или массив с именами состояния, от которых будет переход;
- - - `to` - имя состояния, к которому будет переход;
- - - `*priority` - приоритет перехода. значение по-умолчанию: `0`;
- - - `*can-interrupt` - свойство, определяющее какой переход может прерывать текущий.
доступные значения: `none` (никакой переход не может прервать текущий),
`any` (любой переход может прервать текущий), `higher-priority` (текущий переход может быть прерван переходом
с более высоким приоритетом). значение по-умолчанию: `none`;
- - - `duration` - длительность перехода в секундах;
- - - `*exit-time` - нормализованное время проигрывания клипа "от" (`from`), в которое может начаться переход;
- - - `*blend-curve` - тип интерполяции перехода. доступные значения: `linear`, по-умолчанию: `linear`;
- - - `*condition` - `Lua` выражение, представляющее условие, при котором переход может начаться. внутри выражения
можно использовать параметры аниматора и переменные среды. по-умолчанию, если условие не указано, то переход
будет происходить безусловно.

Пример:
```json
{
    "clips": [
        {
            "id": "base",
            "file": "packid:animations/base.lfa"
        },
        {
            "id": "jump",
            "file": "packid:animations/jump.lfa"
        }
    ],

    "parameters": [
        { "name": "speed", "type": "number" },
        { "name": "is_jumping", "type": "trigger" }
    ],
  
    "layers": [
        {
            "name": "base_layer",
            "blend-mode": "override",
            "weight": 1.0,
            "default-state": "idle",
            "states": [
                {
                    "name": "idle",
                    "clip": "base:idle",
                    "loop": true
                },
                {
                    "name": "walk",
                    "clip": "base:walk",
                    "loop": true
                },
                {
                    "name": "run",
                    "clip": "base:run",
                    "loop": true
                },
                {
                    "name": "jump",
                    "type": "clip",
                    "clip": "jump:jump",
                    "loop": false
                }
            ],
            "transitions": [
                {
                    "from": [ "idle", "walk" ],
                    "to": "run",
                    "can-interrupt": "higher-priority",
                    "duration": 0.25,
                    "condition": "speed >= 2"
                },
                {
                    "from": [ "idle", "run" ],
                    "to": "walk",
                    "can-interrupt": "higher-priority",
                    "duration": 0.25,
                    "condition": "speed > 0 and speed < 2"
                },
                {
                    "from": "jump",
                    "to": "run",
                    "priority": 1,
                    "can-interrupt": "higher-priority",
                    "duration": 0.25,
                    "exit-time": 1.0,
                    "condition": "speed >= 2"
                },
                {
                    "from": "jump",
                    "to": "walk",
                    "priority": 1,
                    "can-interrupt": "higher-priority",
                    "duration": 0.25,
                    "exit-time": 1.0,
                    "condition": "speed > 0 and speed < 2"
                },
                {
                    "from": "run",
                    "to": "idle",
                    "duration": 0.3,
                    "condition": "speed == 0"
                },
                {
                    "from": "jump",
                    "to": "idle",
                    "priority": 0,
                    "duration": 0.3,
                    "exit-time": 1.0
                },
                {
                    "from": [ "idle", "run" ],
                    "to": "jump",
                    "priority": 2,
                    "duration": 0.1,
                    "condition": "is_jumping"
                }
            ]
        }
    ]
}
```