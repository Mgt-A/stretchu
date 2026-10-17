#!/usr/bin/env bash
# Downloads the Pokémon sprites at build time. No Pokémon pixel lives in the repository.
#
#   scripts/fetch-sprites.sh         (also: make sprites; make install calls it when sprites are missing)
#
# For every species of Resources/lines.json it downloads, from PMDCollab/SpriteCollab at the commit
# pinned in lines.json, AnimData.xml and the animations the app uses: Hop, Sleep and a still pose (Idle, or Walk for hovering species) are required
# (a line without them is dropped, with a message), Eat, DeepBreath and LookUp are taken when SpriteCollab
# has them. The shiny variant is kept when SpriteCollab has a complete one. It also downloads the
# artists' credits and the evolution stones (PokeAPI/sprites, pinned too). The network is only used here, never by the app.
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift scripts/fetch-sprites.swift "$@"
