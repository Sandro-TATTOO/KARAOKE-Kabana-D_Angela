#!/usr/bin/env python3
import os, json, re, unicodedata
from collections import Counter
from datetime import datetime

def normalize(s):
    if not s: return ""
    return unicodedata.normalize('NFD', s).encode('ascii', 'ignore').decode('utf-8').lower().strip()

def parse_lista_file(filepath):
    songs = []
    if not os.path.exists(filepath): return songs
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e: 
        print(f"Erro ao ler: {e}"); return songs
    current_song = {}
    for line in lines:
        line = line.strip()
        if not line: continue
        field_match = re.match(r'^(Artista|Musica|inicio|Arquivo)=(.*)', line)
        if field_match:
            fn = field_match.group(1)
            fv = field_match.group(2).strip()
            if fn == 'Artista': current_song['artista'] = normalize(fv)
            elif fn == 'Musica': current_song['musica'] = normalize(fv)
            elif fn == 'inicio': current_song['inicio'] = fv
            elif fn == 'Arquivo': 
                current_song['arquivo'] = fv
                if not current_song.get('artista'):
                    current_song['artista'] = normalize(fv)
            continue
        num_match = re.match(r'^\[(\d+)\]', line)
        if num_match and current_song.get('artista') and current_song.get('musica'):
            songs.append(current_song)
            current_song = {'numero': int(num_match.group(1)), 'artista': '', 'musica': '', 'inicio': '', 'arquivo': ''}
            continue
        elif num_match and not (current_song.get('artista') or current_song.get('musica')):
            current_song = {'numero': int(num_match.group(1)), 'artista': '', 'musica': '', 'inicio': '', 'arquivo': ''}
            continue
    if current_song.get('musica') and current_song.get('artista'): songs.append(current_song)
    return songs

def analyze_duplicates(songs):
    nums = [s.get('numero', 0) for s in songs]
    counter = Counter(nums)
    duplicates = {num: count for num, count in counter.items() if count > 1}
    unique_nums = [num for num in nums if counter[num] == 1]
    return {'total_musicas': len(songs), 'numeros_unicos': len(unique_nums), 
            'numeros_duplicados': len(duplicates), 'duplicatas': dict(sorted(duplicates.items())),
            'lista_numeros_duplicados': sorted(duplicates.keys())}

def reorganize_songs(songs):
    valid_songs, songs_without_num = [], []
    for song in songs:
        num = song.get('numero', 0)
        if num > 0: valid_songs.append(song)
        else: songs_without_num.append(song)
    valid_songs.sort(key=lambda x: x['numero'])
    result, added_nums = [], set()
    for song in valid_songs:
        num = song['numero']
        if num not in added_nums: added_nums.add(num); result.append(song)
    num_counter = 1; song_idx = 0
    for i in range(len(result)):
        if result[i].get('numero', 0) <= 0 and song_idx < len(songs_without_num):
            result[i]['numero'] = num_counter; num_counter += 1; song_idx += 1
    return result

def generate_json_output(songs, output_path):
    formatted_songs = []
    for i, song in enumerate(songs, 1):
        formatted_songs.append({
            "numero": song.get('numero', i),
            "cantor": song.get('artista', 'Artista Desconhecido'),
            "musica": song.get('musica', 'Musica Desconhecida'),
            "trecho": song.get('inicio', ''),
            "letra_completa": ""
})
    output_data = {
        "gerado_em": json.dumps(datetime.now().isoformat()),
        "versao": 1,
        "total_musicas": len(formatted_songs),
        "format": "karaoke_list_original",
        "musicas": formatted_songs,
        "info_processamento": {
            "arquivo_origem": "lista.txt", 
            "total_registros_lidos": len(songs), 
            "total_musicas_no_json": len(formatted_songs)
        }
    }
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        print("OK JSON gerado: {}".format(output_path)); print("   Total: {} musicas".format(len(formatted_songs))); return True
    except Exception as e: print("ERRO: {}".format(e)); return False

if __name__ == "__main__":
    print("=" * 60)
    print("Processador de Lista de Musicas para Karaoke")
    print("=" * 60); print()
    base_dir = r"C:\Users\YYYY\Documents\lista_karaoke_online"
    input_file = os.path.join(base_dir, "lista", "lista .txt")
    output_file = os.path.join(base_dir, "assets", "data", "lista.json")
    print("Entrada: {}".format(input_file)); print("Saida: {}".format(output_file)); print()
    print("1. Parseando arquivo lista.txt...")
    songs = parse_lista_file(input_file); print("   Registros brutos: {}".format(len(songs))); print()
    print("2. Analisando numeros duplicados...")
    analysis = analyze_duplicates(songs); print("   Total: {}".format(analysis['total_musicas']))
    print("   Unicos: {}".format(analysis['numeros_unicos'])); print("   Duplicados: {}".format(analysis['numeros_duplicados'])); print()
    if analysis['numeros_duplicados'] > 0:
        print("   Numeros duplicados (primeiros 15):")
        for num in analysis['lista_numeros_duplicados'][:15]:
            print("     - N.{}: {} vezes".format(num, analysis['duplicatas'][num]))
        if len(analysis['lista_numeros_duplicados']) > 15:
            print("     ... e mais {} numeros a mais".format(len(analysis['lista_numeros_duplicados'])-15))
    print()
    print("3. Reorganizando lista (mantendo numeracao original)...")
    songs_reorg = reorganize_songs(songs); print("   Reorganizadas: {}".format(len(songs_reorg))); print()
    print("4. Gerando JSON de saida...")
    success = generate_json_output(songs_reorg, output_file); print()
    print("=" * 60)
    print("RELATORIO FINAL")
    print("=" * 60)
    print("Entrada: lista .txt"); print("Processadas: {}".format(analysis['total_musicas']))
    print("Duplicados: {}".format(analysis['numeros_duplicados'])); print("JSON final: {}".format(analysis['numeros_unicos'] if analysis['numeros_unicos'] > 0 else len(songs_reorg)))
    print(); 
    if success: print("OK Concluido! Proximo: flutter clean && flutter run -d chrome")
    else: print("ERRO"); print("=" * 60)
