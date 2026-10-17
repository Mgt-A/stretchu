# Stretchu program format

A program is the list of exercises Stretchu draws from at each break. Stretchu ships one, `general`
(desk mobility: neck, shoulders, back, hips, wrists, no equipment). You can write your own by hand,
or have an AI assistant write it from your needs (see the skill in `skill/stretchu-program`).

A program is a small JSON file:

```json
{
  "schemaVersion": 1,
  "name": "Desk mobility, sore neck",
  "settings": { "workMinutes": 25, "step1Seconds": 30, "step2Seconds": 30 },
  "exercises": [
    "Chin_Tucks", "Side_Neck_Stretch", "Shoulder_Circles", "Wall_Slides", "Upward_Stretch",
    "Cat_Stretch", "Childs_Pose", "Wrist_Circles", "Chair_Lower_Back_Stretch", "Torso_Rotation",
    "Arm_Circles", "Band_Pull_Apart"
  ],
  "equipment": ["bands", "exercise ball"]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `schemaVersion` | yes | Always `1`. |
| `name` | yes | Shown in the app. 1 to 80 characters. |
| `exercises` | yes | Ids from the catalog, at least one. Order does not matter, duplicates are ignored. |
| `settings` | no | The rhythm the program asks for. Each value is optional. |
| `settings.workMinutes` | no | Minutes of work between two breaks, 5 to 90. |
| `settings.step1Seconds` | no | Length of the warm-up, 10 to 120 seconds. |
| `settings.step2Seconds` | no | Length of the exercise, 15 to 180 seconds. |
| `equipment` | no | Indicative: the equipment the chosen exercises need, among `bands`, `foam roll`, `exercise ball`, `medicine ball`, `kettlebells`, `dumbbell`. Computed from the exercises, never asked; the app does not read it. |

A [JSON Schema](../Resources/Programs/program.schema.json) describes the format.

## The catalog

Exercise ids come from `Resources/Exercises/catalog.json`. Each entry has an `id`, an English
`name`, three gentle `steps`, the `equipment` it needs (the value of
[free-exercise-db](https://github.com/yuhonas/free-exercise-db), as is; `null` or `body only` means
nothing), the muscles it works and its pictures. French texts are in `catalog.fr.json`.

## What the app does with a file

- **Unknown ids are ignored**, and counted: the app tells you how many were skipped. A file where
  no id is known is refused.
- **Settings outside the ranges are clamped** to the nearest allowed value.
- **Keep at least 10 exercises that need no equipment** (`null` or `body only`), so that the filter below never empties the program.
- **Equipment filters the draw.** In Settings you tell the app which equipment you own at home and
  at the office. An exercise that needs equipment you don't own at that place is not drawn.
  Exercises that need nothing are always available. If nothing is left, the app falls back to the
  program's exercises that need nothing, then to any exercise that needs nothing.
- **Where files live.** Programs you import are copied to
  `~/Library/Application Support/Stretchu/programs/`. You can also drop a `.json` file there
  yourself. The file name (without `.json`) is the program's id.
- A program never contains medical advice: Stretchu is not a medical device, stop if anything hurts.
