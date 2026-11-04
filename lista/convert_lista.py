#!/usr/bin/env python3
"""Converte lista/lista .txt (blocos INI) em assets/data/songs.json."""

import json
import re
import os
import unicodedata

BASE = os.path.dirname(os.path.abspath(__file__))
# pasta raiz do projeto (pai de lista/)
PROJECT = os.path.dirname(BASE)
INPUTS = [
    os.path.join(BASE, "lista .txt"),
    os.path.join(BASE, "lista 86.txt"),
]
OUTPUT = os.path.join(PROJECT, "assets", "data", "songs.json")


def norm_key(k):
    return k.strip().lower()


def clean(v):
    if v is None:
        return ""
    return " ".join(str(v).split())


def parse_file(path, seen):
    songs = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    blocks = re.split(r"(?m)^\[(\d+)\]\s*$", content)
    for i in range(1, len(blocks), 2):
        num_str = blocks[i].strip()
        body = blocks[i + 1] if i + 1 < len(blocks) else ""
        fields = {}
        for line in body.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                fields[norm_key(k)] = v.strip()
        try:
            numero = int(num_str)
        except ValueError:
            continue
        # artist can be in 'artista' or 'arquivo'
        cantor_raw = fields.get("artista", "") or fields.get("arquivo", "")
        cantor = clean(cantor_raw)
        # remove leading dashes
        cantor = cantor.strip(" -")
        musica = clean(fields.get("musica", ""))
        trecho = clean(fields.get("inicio", ""))
        if not (cantor or musica):
            continue
        if numero in seen:
            continue
        seen.add(numero)
        songs.append({
            "id": str(numero),
            "numero": numero,
            "cantor": cantor,
            "musica": musica,
            "trecho": trecho,
            "letra_completa": None,
        })
    return songs


def main():
    seen = set()
    all_songs = []
    for path in INPUTS:
        all_songs.extend(parse_file(path, seen))
    all_songs.sort(key=lambda s: s["numero"])
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(all_songs, f, ensure_ascii=False, indent=2)
    print(f"Geradas {len(all_songs)} musicas em {OUTPUT}")


if __name__ == "__main__":
    main()
