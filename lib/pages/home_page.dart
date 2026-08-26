import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../core/access_log.dart';
import '../core/favorites_store.dart';
import '../core/song_cache.dart';
import '../core/supabase_client.dart';
import '../models/mensagem_model.dart';
import '../models/song_model.dart';
import '../widgets/song_card.dart';
import 'admin_login_page.dart';
import 'favorites_page.dart';
import 'song_detail_page.dart';

/// Página inicial: catálogo de músicas com busca.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Future<List<SongModel>>? _future;

  // Mensagens (carrossel)
  List<MensagemModel> _mensagens = [];
  PageController? _mensagemPageController;
  Timer? _mensagemAutoplay;
  int _mensagemPageIndex = 0;
  bool _mensagemUserInteracting = false;

  Set<int> _favorites = <int>{};

  @override
  void initState() {
    super.initState();
    _loadSongsWithCache();
    _fetchMensagem();
    _loadFavorites();
    AccessLog.registrarAcesso();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesStore.load();

    if (!mounted) return;

    setState(() => _favorites = favs);
  }

  Future<void> _toggleFavorite(int numero) async {
    await FavoritesStore.toggle(numero);

    if (!mounted) return;

    setState(() {
      _favorites = FavoritesStore.current;
    });
  }

  void _openFavorites() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
  }

  Future<void> _loadSongsWithCache() async {
    final cached = await SongCache.load();

    if (!mounted) return;

    setState(() {
      if (cached != null && cached.isNotEmpty) {
        _future = Future.value(cached);
      } else {
        _future = _fetchSongs('');
      }
    });

    try {
      final fresh = await _fetchSongs('');

      if (!mounted) return;

      await SongCache.save(fresh);

      if (_searchController.text.trim().isEmpty) {
        setState(() {
          _future = Future.value(fresh);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mensagemAutoplay?.cancel();
    _mensagemPageController?.dispose();
    _debounce?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _fetchMensagem() async {
    try {
      final client = SupabaseClientFactory.instance;

      final response = await client
          .from('mensagens')
          .select('id, conteudo, ativa, criada_em')
          .eq('ativa', true)
          .order('criada_em', ascending: false);

      final list = (response as List?) ?? const [];

      if (!mounted) return;

      final mensagens = list
          .map((e) => MensagemModel.fromMap(e as Map<String, dynamic>))
          .toList();

      _mensagemAutoplay?.cancel();
      _mensagemPageController?.dispose();

      setState(() {
        _mensagens = mensagens;
        _mensagemPageIndex = 0;
        _mensagemPageController = mensagens.length > 1
            ? PageController()
            : null;
      });

      if (mensagens.length > 1) {
        _startMensagemAutoplay();
      }
    } catch (_) {}
  }

  void _startMensagemAutoplay() {
    _mensagemAutoplay?.cancel();

    _mensagemAutoplay = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _mensagemUserInteracting) return;

      if (_mensagens.length <= 1 || _mensagemPageController == null) {
        return;
      }

      if (!_mensagemPageController!.hasClients) return;

      final next = (_mensagemPageIndex + 1) % _mensagens.length;

      _mensagemPageController!.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _showMensagemDetalhe(MensagemModel mensagem) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.campaign, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Mensagem do Admin',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mensagem.conteudo,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Enviada em: '
                '${mensagem.criadaEm.day.toString().padLeft(2, '0')}/'
                '${mensagem.criadaEm.month.toString().padLeft(2, '0')}/'
                '${mensagem.criadaEm.year} '
                '${mensagem.criadaEm.hour.toString().padLeft(2, '0')}:'
                '${mensagem.criadaEm.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _future = _fetchSongs(value.trim());
      });
    });
  }

  String _normalize(String input) {
    const withAccents = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';

    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

    final buffer = StringBuffer();

    for (final rune in input.split('')) {
      final idx = withAccents.indexOf(rune);

      buffer.write(idx >= 0 ? withoutAccents[idx] : rune);
    }

    return buffer.toString().toLowerCase();
  }

  Future<List<SongModel>> _fetchSongs(String query) async {
    final client = SupabaseClientFactory.instance;

    const fields = 'numero, cantor, musica, trecho, letra_completa';

    const pageSize = 1000;

    var from = 0;

    final all = <SongModel>[];

    while (true) {
      final to = from + pageSize - 1;

      final response = await client
          .from('songs')
          .select(fields)
          .order('numero', ascending: true)
          .range(from, to);

      final list = (response as List?) ?? const [];

      if (list.isEmpty) break;

      all.addAll(list.map((e) => SongModel.fromMap(e as Map<String, dynamic>)));

      if (list.length < pageSize) break;

      from += pageSize;
    }

    final normalizedQuery = _normalize(query).trim();

    if (normalizedQuery.isEmpty) {
      return all;
    }

    return all.where((song) {
      return _normalize(song.cantor).contains(normalizedQuery) ||
          _normalize(song.musica).contains(normalizedQuery) ||
          song.numero.toString().contains(normalizedQuery);
    }).toList();
  }

  Future<void> _reload() async {
    setState(() {
      _future = null;
    });

    await _loadSongsWithCache();
    await _fetchMensagem();
  }

  void _openDetail(BuildContext context, SongModel song) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SongDetailPage(song: song)));
  }

  Widget _buildMensagemCarousel() {
    if (_mensagens.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 64,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _mensagemUserInteracting = true;
              } else if (notification is ScrollEndNotification) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    _mensagemUserInteracting = false;
                  }
                });
              }

              return false;
            },
            child: PageView.builder(
              controller: _mensagemPageController,
              itemCount: _mensagens.length,
              onPageChanged: (index) {
                setState(() {
                  _mensagemPageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final mensagem = _mensagens[index];

                return Tooltip(
                  message: 'Toque para ver a mensagem completa',
                  child: GestureDetector(
                    onTap: () => _showMensagemDetalhe(mensagem),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.only(
                        left: 14,
                        right: 10,
                        top: 8,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),

                      // =====================================================
                      // TRECHO CORRIGIDO CONFORME SOLICITADO
                      // =====================================================
                      child: Row(
                        children: [
                          Icon(
                            Icons.campaign,
                            color: scheme.onPrimary,
                            size: 26, // era ~24 (padrão)
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              mensagem.conteudo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.touch_app,
                            color: scheme.onPrimary.withValues(alpha: 0.95),
                            size: 42, // era 22
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_mensagens.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_mensagens.length, (index) {
              final selected = index == _mensagemPageIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 16 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KARAOKE CABANA DONA ANGELA',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Favoritos',
            icon: Badge(
              isLabelVisible: _favorites.isNotEmpty,
              label: Text('${_favorites.length}'),
              child: const Icon(Icons.favorite),
            ),
            onPressed: _openFavorites,
          ),
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          IconButton(
            tooltip: 'Área do Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AdminLoginPage()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Buscar por número, cantor ou música...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
              if (_mensagens.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMensagemCarousel(),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<SongModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SpinKitFadingCircle(
                          color: Colors.pinkAccent,
                          size: 48,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Erro ao carregar músicas.\n'
                            'Verifique a conexão com o Supabase e as '
                            'permissões (RLS).\n\n'
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final songs = snapshot.data ?? const <SongModel>[];

                    if (songs.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma música encontrada.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: songs.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final song = songs[index];

                        return SongCard(
                          song: song,
                          isFavorite: _favorites.contains(song.numero),
                          onFavoriteToggle: () => _toggleFavorite(song.numero),
                          onTap: () => _openDetail(context, song),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
