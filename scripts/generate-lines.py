#!/usr/bin/env python3
"""Generates Resources/lines.json: the Pokémon lines the app can use.

A maintainer tool, not needed to build the app (lines.json is committed). It reads PokeAPI
(https://pokeapi.co) for the Gen 1 species, keeps the evolution links between Gen 1 species
only, and assigns the evolution levels:

    2 evolutions -> levels 33 and 66,  1 evolution -> level 50,  none -> the same species to 100.

A line that branches (only Eevee in Gen 1) gets a `branch`: at level 50 the player chooses
one of the stones. Usage:  python3 scripts/generate-lines.py
"""
import json, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

API = "https://pokeapi.co/api/v2"
GEN1 = range(1, 152)
# Pinned versions of the sprite repositories (see scripts/fetch-sprites.sh).
SPRITE_COLLAB_COMMIT = "aae7a436af894efab3ff24915f0b645bb4907750"
POKEAPI_SPRITES_COMMIT = "289e842364648ec0495ae4ba12f48d5cbfbf670b"
STONES = ["water-stone", "thunder-stone", "fire-stone"]
LANGUAGES = ["en", "fr"]


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "stretchu-generate-lines/1.0"})
    with urllib.request.urlopen(request, timeout=30) as r:
        return json.load(r)


def names(entry):
    out = {}
    for n in entry["names"]:
        if n["language"]["name"] in LANGUAGES:
            out[n["language"]["name"]] = n["name"]
    return out


def dex_of(url):
    return int(url.rstrip("/").split("/")[-1])


species = dict(zip(GEN1, ThreadPoolExecutor(4).map(lambda n: get(f"{API}/pokemon-species/{n}"), GEN1)))
chains = {}
for sp in species.values():
    chains[sp["evolution_chain"]["url"]] = None
chains = dict(zip(chains, ThreadPoolExecutor(4).map(get, chains)))

children = {n: [] for n in GEN1}


def walk(node):
    parent = dex_of(node["species"]["url"])
    for child in node["evolves_to"]:
        c = dex_of(child["species"]["url"])
        if parent in children and c in children:
            children[parent].append(c)
        walk(child)


for chain in chains.values():
    walk(chain["chain"])

has_parent = {c for kids in children.values() for c in kids}
bases = [n for n in GEN1 if n not in has_parent]


def depth(n):
    return 0 if not children[n] else 1 + max(depth(c) for c in children[n])


lines = []
for base in bases:
    total = depth(base)
    levels = {0: [1], 1: [1, 50], 2: [1, 33, 66]}[total]
    path, node = [base], base
    while children[node]:
        kids = children[node]
        if len(kids) > 1:
            break
        node = kids[0]
        path.append(node)
    line = {
        "id": species[base]["name"],
        "species": [
            {"dex": n, "slug": species[n]["name"], "names": names(species[n]), "level": levels[i]}
            for i, n in enumerate(path)
        ],
    }
    if len(children[path[-1]]) > 1:
        options = []
        for kid, stone in zip(children[path[-1]], STONES):
            item = get(f"{API}/item/{stone}")
            options.append({
                "stone": stone, "stoneNames": names(item),
                "dex": kid, "slug": species[kid]["name"], "names": names(species[kid]),
            })
        line["branch"] = {"level": 50, "options": options}
    lines.append(line)

doc = {
    "schemaVersion": 1,
    "spriteCollabCommit": SPRITE_COLLAB_COMMIT,
    "pokeApiSpritesCommit": POKEAPI_SPRITES_COMMIT,
    "lines": lines,
}
with open("Resources/lines.json", "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
count = sum(len(l["species"]) + (len(l["branch"]["options"]) if "branch" in l else 0) for l in lines)
print(f"{len(lines)} lines, {count} species", file=sys.stderr)
