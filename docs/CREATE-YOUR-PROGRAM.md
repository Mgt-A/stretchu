# Create your program

A program is the list of exercises Stretchu draws from at each break. The app ships one, `general`:
desk mobility for the neck, shoulders, back, hips and wrists, no equipment needed. If you want
breaks shaped around you (a stiff neck, long days of sitting, calmer breaks), an AI assistant can
pick the exercises for you in two minutes.

The assistant only **selects** exercises from Stretchu's catalog of 90. It never invents one, and the
app ignores any id it doesn't know. You don't need to think about equipment either: tell Stretchu
what you own at home and at the office in Settings, it filters at every break.

> Stretchu is not medical advice. If you have pain, an injury or a condition, ask a physiotherapist
> or a doctor what suits you. The assistant will say so too and keep to the gentlest exercises.

## 1. Get the program written

### With Claude Code

1. Copy the skill once:

   ```bash
   cp -R skill/stretchu-program ~/.claude/skills/
   ```

2. Start Claude Code **from the Stretchu folder**, so it can read the catalog:

   ```bash
   cd stretchu && claude
   ```

3. Ask for it in your own words. For example:

   ```text
   Make me a Stretchu program: I sit all day, my hips and lower back get stiff,
   and I'd like calmer breaks. Breaks of 30 seconds.
   ```

   The skill asks at most one round of questions (tight spots, goals, break length), then replies
   with a JSON block.

### With any other assistant

Paste this prompt, then the whole content of
[`Resources/Exercises/catalog.json`](../Resources/Exercises/catalog.json):

```text
Write a Stretchu program as a JSON file. Ask me first where I feel tight during the workday, what I
want from the breaks and how long my breaks are. Then pick 12 to 30 exercises using only ids that
exist in the catalog I pasted: never invent one. At least 10 of them must need no equipment
("equipment" is null or "body only" in the catalog). Don't ask me about equipment. Reply with a
single JSON object: {"schemaVersion":1,"name":"...","settings":{"workMinutes":25,
"step1Seconds":30,"step2Seconds":30},"exercises":["<id>", ...],"equipment":[...]} where
"equipment" lists the distinct equipment (other than null and "body only") that the chosen
exercises need. No diagnosis: if I mention pain or an injury, tell me
to ask a physiotherapist or a doctor and keep to the gentlest exercises.
```

## 2. Save it

Save the JSON block as a file ending in `.json`, anywhere, for example
`~/Downloads/my-stretchu-program.json`. It looks like this:

```json
{
  "schemaVersion": 1,
  "name": "Long days of sitting, calm breaks",
  "settings": { "workMinutes": 25, "step1Seconds": 30, "step2Seconds": 30 },
  "exercises": ["Chin_Tucks", "Shoulder_Circles", "Childs_Pose", "Wrist_Circles"],
  "equipment": []
}
```

## 3. Import it

In Stretchu: **Settings › Program › Choose a file**, or the "Custom" option in the setup window.

- The program becomes the one breaks are drawn from. Its `settings`, if any, set the rhythm.
- **Unknown ids are skipped**, and the app tells you how many. A file with no known id is refused.
- Values outside the allowed ranges are brought back to the nearest one (for example 90 minutes at
  most between two breaks).
- The file is copied to `~/Library/Application Support/Stretchu/programs/`. To go back, choose
  `general` in Settings, Program.

## Write it by hand

You can also write the file yourself: pick ids in the catalog and follow the
[program format](PROGRAM.md).
