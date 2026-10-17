---
name: stretchu-program
description: Writes a Stretchu program file (a short list of gentle mobility and stretching exercises) from the user's needs. Use when someone wants a personal Stretchu program, asks which exercises to put in Stretchu, or wants to adapt their breaks to a sore area, a goal, or the length of their breaks.
---

# Stretchu program

Stretchu is a macOS menu bar app that reminds you to take short movement breaks. A program is the
list of exercises it draws from. Your job: ask a few questions, pick exercises that already exist
in the catalog, write one JSON file.

## Hard rules

- **Only use ids that exist** in `Resources/Exercises/catalog.json` (field `exercises[].id`). Read
  the file first. Never invent an exercise, never rename one, never edit the catalog.
- **No diagnosis, no treatment.** You do not say what the user has. If they describe pain, numbness,
  an injury, a recent surgery or a medical condition, say once, plainly, that a physiotherapist or
  a doctor should decide what suits them, and build the program only from the gentlest options
  (breathing, circles, easy stretches). Never promise that an exercise will cure or relieve
  anything.
- **At least 10 exercises need no equipment** (`equipment` is `null` or `body only` in the catalog),
  in every program. The app filters each draw by the equipment the player owns at the place they
  are, so this keeps it from ever emptying the program. Don't ask about equipment and don't filter
  by it: pick the best exercises, then check this count.
- Stretchu is not a medical device. Every program you write stays gentle: no loaded or ballistic
  exercise.

## Steps

1. **Ask**, in the user's language, in one short message (skip what they already said):
   - Where does it feel tight or tired during the workday (neck, shoulders, back, hips, wrists,
     legs)? Any pain or injury? (If yes: see the rule above.)
   - What do they want from the breaks (loosen up, posture, calm down, a bit of strength)?
   - How long are their breaks? It sets the rhythm: `step1Seconds` (warm-up, 10 to 120) and
     `step2Seconds` (the exercise, 15 to 180). Default 30 and 30. Optionally `workMinutes` (5 to
     90, default 25).
2. **Read the catalog.** Each entry has `id`, `name`, `steps`, `equipment` (`null` or `body only`
   means nothing needed), `primaryMuscles` and `category`.
3. **Select 12 to 30 ids** that match the areas and goals. Mix the areas so that two breaks in a
   row do not work the same spot. Prefer a spread: a few for the main area, a few for the
   neighbors, a couple of breathing or full-body ones. Equipment is not a criterion.
4. **Check** every id against the catalog once more, drop duplicates, drop anything missing, and
   count the exercises that need no equipment: add some if there are fewer than 10.
5. **Output the JSON** in one code block, and nothing else to save. Don't write a file anywhere:
   the user chooses where to keep it (a download, copy and paste, or a save from their assistant's
   interface). Format (also in `docs/PROGRAM.md`):

```json
{
  "schemaVersion": 1,
  "name": "Desk mobility, tight neck",
  "settings": { "workMinutes": 25, "step1Seconds": 30, "step2Seconds": 30 },
  "exercises": [
    "Chin_Tucks", "Side_Neck_Stretch", "Shoulder_Circles", "Wall_Slides", "Upward_Stretch",
    "Cat_Stretch", "Childs_Pose", "Wrist_Circles", "Chair_Lower_Back_Stretch", "Torso_Rotation",
    "Arm_Circles", "Band_Pull_Apart"
  ],
  "equipment": ["bands", "exercise ball"]
}
```

   `name` is 1 to 80 characters. `settings` is optional. `equipment` is computed, not asked: the
   distinct equipment values (other than `null` and `body only`) of the chosen exercises, as an
   indication. Leave it out or empty when none needs equipment.
6. **Tell the user** in two lines how to use it: save the block as a `.json` file wherever they
   like, then in Stretchu choose Settings, Program, Choose a file. Add the one-line reminder that
   Stretchu is not medical advice and that they should stop if anything hurts.

## Style

Short, plain, no promises. One question message, then the JSON.
