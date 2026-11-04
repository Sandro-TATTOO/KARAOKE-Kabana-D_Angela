#!/usr/bin/env python3
"""Script simples de limpeza de lista de músicas para Karaokê."""

import os
import json
import re
import unicodedata
from datetime import datetime


def normalize_accent(input_str):
    """Remove acentos e normaliza string."""
    if not input_str:
        return ""
    nfkd_form = unicodedata.normalize('NFD', input_str)
    only_ascii = nfkd_form.encode('ascii', 'ignore').decode('utf-8')
    return only_ascii.lower().strip()


def format_number(num_str):
    """Formata número de música."""
    if not num_str:
        return 0
    try:
        return int(str(num_str).strip().replace(' ', '').replace('.', ''))
    except (ValueError, TypeError):
        return 0


def clean_music_name(name):
    """Limpa nome de música."""
    if not name:
        return "Musica Desconhecida"
    name = re.sub(r'\s+', ' ', name.strip())
    name = re.sub(r'[^\w\sáéíóúâêôãõÁÉÍÓÚÂÊÔÃÕ]', '', name)
    return name.title()


def process_song_data(input_file, output_file):
    """Processa e limpa dados de músicas."""
    
    songs = []
    
    if not os.path.exists(input_file):
        print(f"Arquivo não encontrado: {input_file}")
        return False
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Erro ao ler: {e}")
        return False
    
    ext = os.path.splitext(input_file)[1].lower()
    
    if ext == '.csv':
        lines = content.strip().split('\n')
        for line in lines:
            if not line.strip():
                continue
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 2:
                numero = format_number(parts[0])
                cantor = parts[1] if len(parts) > 1 else ""
                musica = parts[2] if len(parts) > 2 else ""
                if numero > 0 and (cantor or musica):
                    songs.append({
                        "numero": numero,
                        "cantor": normalize_accent(cantor),
                        "musica": normalize_accent(musica),
                        "trecho": "",
                        "letra_completa": ""
                    })
    
    elif ext == '.txt':
        lines = content.strip().split('\n')
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Padrão: numero - cantor - musica
            num_match = re.match(r'^(\d+)\s*[-:]\s*(.*)', line)
            if num_match:
                numero = int(num_match.group(1))
                resto = num_match.group(2)
                
                if ' - ' in resto:
                    parts = resto.split(' - ', 1)
                    cantor = parts[0].strip()
                    musica = parts[1].strip()
                elif ': ' in resto:
                    parts = resto.split(': ', 1)
                    cantor = parts[0].strip()
                    musica = parts[1].strip()
                else:
                    cantor = ""
                    musica = resto.strip()
                
                if numero > 0 and (cantor or musica):
                    songs.append({
                        "numero": numero,
                        "cantor": normalize_accent(cantor) if cantor else "",
                        "musica": normalize_accent(musica) if musica else "",
                        "trecho": "",
                        "letra_completa": ""
                    })
    
    # Remover duplicatas por número
    seen_numbers = set()
    unique_songs = []
    for song in songs:
        num = song['numero']
        if num not in seen_numbers:
            seen_numbers.add(num)
            unique_songs.append(song)
        else:
            print(f"  Removida duplicata de número {num}: {song['musica'][:20]}")
    
    # Ordenar por número
    unique_songs.sort(key=lambda x: x['numero'])
    
    # Gerar output
    output_data = {
        "gerado_em": datetime.now().isoformat(),
        "versao": 1,
        "total_musicas": len(unique_songs),
        "musicas": unique_songs
    }
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        print(f"\n✅ Sucesso! {len(unique_songs)} músicas salvas em {output_file}")
        return True
    except Exception as e:
        print(f"❌ Erro ao salvar: {e}")
        return False


if __name__ == "__main__":
    print("Script de Limpeza de Lista de Músicas")
    print("-" * 40)
    
    # Caminhos
    base = r"C:\Users\YYYY\Documents\lista_karaoke_online"
    input_path = os.path.join(base, "lista", "musicas.txt")
    output_path = os.path.join(base, "assets", "data", "songs.json")
    
    print(f"Entrada: {input_path}")
    print(f"Saída: {output_path}")
    print()
    
    success = process_song_data(input_path, output_path)
    
    if success:
        print("\nArquivo gerado com sucesso!")
        print("Execute: flutter clean && flutter run -d chrome")