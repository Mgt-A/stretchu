#!/usr/bin/env bash
# Exports the public tree of the repository to a new folder, by allow list, and starts a git
# repository in it with one commit. Nothing is pushed and no remote is created.
#
#   scripts/export-public.sh <folder> [--test]
#
# Only what is listed below is copied. Anything added to the repository later (a design note, a
# prompt, a private doc) stays out until it is added here on purpose. Before committing, the script
# checks the result and stops if it finds a private doc, a private word or a Pokémon-based icon.
# `--test` then runs `swift test` in the exported folder (sprites are copied from this checkout,
# or downloaded when it has none: they are never committed).
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { echo "usage: scripts/export-public.sh <folder> [--test]" >&2; exit 2; }
[ $# -ge 1 ] || usage
DEST="$1"; shift
RUN_TESTS=0
for arg in "$@"; do [ "$arg" = "--test" ] && RUN_TESTS=1 || usage; done

if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  echo "error: $DEST exists and is not empty" >&2; exit 1
fi
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

# --- the allow list ---------------------------------------------------------------------------
DIRS=(Sources Tests Resources scripts skill)
FILES=(Makefile Package.swift Info.plist README.md LICENSE CREDITS.md CONTRIBUTING.md .gitignore)
DOCS=(docs/PROGRAM.md docs/CREATE-YOUR-PROGRAM.md)
# README pictures: the icon and the screenshots, nothing else from docs/images.
IMAGES=(docs/images/icon.png docs/images/menu.png docs/images/break.png docs/images/hall-of-fame.png)

for dir in "${DIRS[@]}"; do
  [ -d "$dir" ] || continue
  # Pokémon sprites are downloaded at build time, never copied.
  rsync -a --exclude '.DS_Store' --exclude 'Resources/Sprites/' "$dir" "$DEST/"
done
for file in "${FILES[@]}"; do
  [ -f "$file" ] && cp "$file" "$DEST/$file"
done
mkdir -p "$DEST/docs"
for doc in "${DOCS[@]}"; do
  [ -f "$doc" ] && cp "$doc" "$DEST/$doc"
done
mkdir -p "$DEST/docs/images"
for image in "${IMAGES[@]}"; do
  [ -f "$image" ] && cp "$image" "$DEST/$image"
done

# --- checks -------------------------------------------------------------------------------------
fail=0
problem() { echo "export check failed: $1" >&2; fail=1; }

# 1. docs/ holds the program guide and format, and the README pictures, nothing else.
allowed_docs=" ${DOCS[*]} ${IMAGES[*]} "
while IFS= read -r path; do
  [[ "$allowed_docs" == *" $path "* ]] || problem "$path must not be exported"
done < <(cd "$DEST" && find docs -type f | sort)

# 2. No private word in any text file. The words are assembled so that this file doesn't contain them.
words=("SP""EC" "PLAN"".md" "ma""quette" "Tie""tze" "Live""box" "Maison""-5G" "Bureau""-Corp")
for word in "${words[@]}"; do
  hits="$(cd "$DEST" && grep -rIl --exclude-dir=.git -- "$word" . || true)"
  [ -z "$hits" ] || problem "\"$word\" appears in: $(echo "$hits" | tr '\n' ' ')"
done

# 3. No Pokémon pixel: no sprites folder, and an icon that is not drawn from one.
[ ! -d "$DEST/Resources/Sprites" ] || problem "Resources/Sprites was exported"
if grep -q "Resources/Sprites" "$DEST/scripts/make-icon.swift" 2>/dev/null; then
  problem "scripts/make-icon.swift draws the app icon from a Pokémon sprite: replace the icon first"
fi

# 4. The files the build needs are there.
for needed in Package.swift Makefile LICENSE README.md Sources Resources/lines.json Resources/Exercises/catalog.json; do
  [ -e "$DEST/$needed" ] || problem "$needed is missing"
done

if [ "$fail" -ne 0 ]; then
  echo "export stopped, nothing committed ($DEST)." >&2
  exit 1
fi

# --- repository ---------------------------------------------------------------------------------
cd "$DEST"
git init -q -b main
git add -A
git commit -q -m "Initial commit"
echo "exported to $DEST ($(git ls-files | wc -l | tr -d ' ') files, $(du -sh .git | cut -f1) of history)"

# --- optional test run --------------------------------------------------------------------------
if [ "$RUN_TESTS" -eq 1 ]; then
  SRC="$(cd "$OLDPWD" && pwd)"
  if [ -d "$SRC/Resources/Sprites" ]; then
    cp -R "$SRC/Resources/Sprites" Resources/Sprites
  else
    scripts/fetch-sprites.sh
  fi
  swift test
  [ -z "$(git status --porcelain)" ] || { echo "the test run changed tracked files" >&2; exit 1; }
fi
