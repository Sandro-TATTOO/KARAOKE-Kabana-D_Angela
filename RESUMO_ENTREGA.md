# RESUMO DA ENTREGA — Catálogo Git-first + busca 100% local

## Problema
O Supabase está com cota de dados limitada/indisponível (HTTP 402). A lista de músicas não pode depender da rede nem travar a abertura do app.

## Solução implementada
O catálogo agora é **Git-first**: viaja versionado no repositório em `assets/data/songs.json`. O app abre com o catálogo local, busca 100% em memória e usa o Supabase apenas como atualização opcional por versão (1 request leve por abertura; se falhar, ignora e segue offline).

## Arquivos criados / alterados

### Criados
- `assets/data/songs.json` — catálogo de exemplo (10+ músicas) no formato do modelo `SongModel` (`numero, cantor, musica, trecho, letra_completa`).
- `assets/data/catalog_version.txt` — número inteiro da versão do catálogo (ex.: `1`).
- `lib/core/catalog_repository.dart` — repositório offline-first:
  - `loadFromAsset()` — lê `assets/data/songs.json`.
  - `loadFromLocal()` — lê do Hive (Android + Web/IndexedDB).
  - `saveLocal()` — persiste lista + versão + atualizado_em no Hive.
  - `fetchRemoteVersion()` — checa `catalog_meta` no Supabase (1 request).
  - `fetchAllFromSupabase()` — baixa lista completa (paginada) só se versão remota > local.
  - `search(query)` — busca 100% em memória com normalização de acentos (numero, cantor, musica).
- `catalog_meta_setup.sql` — script SQL para criar tabela `catalog_meta` com RLS pública e trigger de bump de versão em `songs`.

### Alterados
- `pubspec.yaml` — adicionou `hive`, `hive_flutter` e registrou os assets:
  ```yaml
  flutter:
    assets:
      - assets/data/songs.json
      - assets/data/catalog_version.txt
  ```
- `lib/main.dart` — `await Hive.initFlutter()` antes do `runApp`.
- `lib/pages/home_page.dart` — carrega via `CatalogRepository.instance.init()`; busca só em memória via `CatalogRepository.instance.search(...)`; exibe aviso quando catálogo vem do asset/local sem Supabase; botão "Tentar novamente" recarrega. Não quebra se Supabase falhar (rede, 401, 404, cota, timeout).
- `DIAGNOSTICO_SUPABASE.txt` — mantido como referência do problema 402.

### Removidos (código de fallback anterior, substituído pelo CatalogRepository)
- `lib/core/song_data_source.dart`
- `lib/core/supabase_song_source.dart`
- `lib/core/asset_song_source.dart`
- `lib/core/song_repository.dart`
- `assets/songs.json` (substituído por `assets/data/songs.json`)

## Fluxo de abertura (offline-first)
1. Abre o app.
2. Tenta carregar do Hive local.
3. Se vazio (primeira instalação), carrega `assets/data/songs.json` e grava no Hive com a versão de `assets/data/catalog_version.txt`.
4. Faz 1 request leve ao Supabase para checar `catalog_meta.version`.
5. Se versão remota > local, baixa lista completa do Supabase, salva no Hive e atualiza versão.
6. Se Supabase falhar (qualquer motivo), ignora e segue com o catálogo local/asset. UI nunca trava.
7. Busca do usuário roda 100% em memória, sem tocar na rede.

## Cota do Supabase
- 1 request de versão por abertura (não a cada digitação).
- Download completo só quando a versão mudar.
- Nenhuma `service_role` no app (usa anon key com RLS de leitura pública).

## Como testar

### Chrome (Web)
```bash
flutter run -d chrome --release
# ou build e servir:
flutter build web --release
```
- Abra o app: catálogo já aparece (vindo do asset/Hive), sem esperar o Supabase.
- Digite na busca: resultados aparecem instantaneamente (busca local).
- Desconecte a internet: o app continua abrindo e buscando normalmente.
- Confira o console do navegador: nenhum erro de rede obrigatório.

### APK (Android)
```bash
flutter build apk --release
```
- Instale o APK gerado em `build/app/outputs/flutter-apk/`.
- Abra sem internet: catálogo funciona (asset embarcado).
- Com internet e Supabase disponível: se houver versão nova, atualiza automaticamente.

### Verificações de código
```bash
flutter analyze    # No issues found
flutter test       # All tests passed
```

## Banco (Supabase) — opcional
Execute `catalog_meta_setup.sql` no SQL Editor do Supabase para habilitar a checagem de versão via `catalog_meta`. Se não executar, o app continua funcionando apenas com o asset local (Supabase fica completamente opcional).
