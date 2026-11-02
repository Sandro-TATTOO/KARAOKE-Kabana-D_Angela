import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/song_model.dart';
import '../core/supabase_client.dart';

class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  static const String boxName = 'karaoke_catalog';
  static const String _songsKey = 'songs';
  static const String _versionKey = 'version';
  static const String _updatedAtKey = 'updated_at';
  static const String assetPath = 'assets/data/songs.json';
  static const String catalogVersionAssetPath =
      'assets/data/catalog_version.txt';

  Box<dynamic>? _box;
  List<SongModel> _songs = <SongModel>[];
  int? _version;
  DateTime? _updatedAt;

  List<SongModel> get songs => _songs;
  int? get version => _version;
  DateTime? get updatedAt => _updatedAt;

  Future<int> _loadAssetVersion() async {
    try {
      final raw = await rootBundle.loadString(catalogVersionAssetPath);
      final v = int.tryParse(raw.trim()) ?? 0;
      return v;
    } catch (_) {
      return 0;
    }
  }

  Future<Box<dynamic>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<dynamic>(boxName);
    return _box!;
  }

  Future<void> init() async {
    await loadFromLocal();
    if (_songs.isEmpty) {
      final asset = await loadFromAsset();
      if (asset.isNotEmpty) {
        final assetVersion = await _loadAssetVersion();
        await saveLocal(asset, version: assetVersion);
      }
    }

    try {
      final remote = await fetchRemoteVersion();
      if (remote != null && (version == null || remote > (version ?? 0))) {
        final fresh = await fetchAllFromSupabase();
        if (fresh.isNotEmpty) {
          await saveLocal(fresh, version: remote, updatedAt: DateTime.now());
        }
      }
    } catch (e) {
      debugPrint('CatalogRepository: Supabase indisponivel: $e');
    }
  }

  Future<List<SongModel>> loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      if (raw.trim().isEmpty) return const <SongModel>[];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => SongModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('CatalogRepository.loadFromAsset: $e');
      return const <SongModel>[];
    }
  }

  Future<List<SongModel>> loadFromLocal() async {
    try {
      final box = await _openBox();
      final raw = box.get(_songsKey);
      if (raw == null) return const <SongModel>[];
      final List<dynamic> decoded;
      if (raw is String) {
        decoded = jsonDecode(raw) as List<dynamic>;
      } else if (raw is List) {
        decoded = raw;
      } else {
        return const <SongModel>[];
      }
      _songs = decoded
          .map((e) => SongModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      final v = box.get(_versionKey);
      if (v is num) _version = v.toInt();
      final upd = box.get(_updatedAtKey);
      if (upd is String) _updatedAt = DateTime.tryParse(upd);
      return _songs;
    } catch (e) {
      debugPrint('CatalogRepository.loadFromLocal: $e');
      return const <SongModel>[];
    }
  }
  Future<void> saveLocal(
    List<SongModel> songs, {
    int? version,
    DateTime? updatedAt,
  }) async {
    final box = await _openBox();
    await box.put(_songsKey, songs.map((s) => s.toMap()).toList());
    if (version != null) await box.put(_versionKey, version);
    final ts = updatedAt ?? DateTime.now();
    await box.put(_updatedAtKey, ts.toIso8601String());
    _songs = songs;
    if (version != null) _version = version;
    _updatedAt = ts;
  }

  Future<int?> fetchRemoteVersion() async {
    try {
      final client = SupabaseClientFactory.instance;
      final res = await client
          .from('catalog_meta')
          .select('version')
          .order('version', ascending: false)
          .limit(1);
      final list = (res as List?) ?? const <dynamic>[];
      if (list.isNotEmpty) {
        final v = list.first['version'];
        if (v is num) return v.toInt();
      }
    } catch (e) {
      debugPrint('CatalogRepository.fetchRemoteVersion: $e');
    }
    return null;
  }

  Future<List<SongModel>> fetchAllFromSupabase() async {
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
      final list = (response as List?) ?? const <dynamic>[];
      if (list.isEmpty) break;
      all.addAll(
        list.map((e) => SongModel.fromMap(e as Map<String, dynamic>)),
      );
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  List<SongModel> search(String query) {
    final q = _normalize(query).trim();
    if (q.isEmpty) return _songs;
    return _songs.where((song) {
      return _normalize(song.cantor).contains(q) ||
          _normalize(song.musica).contains(q) ||
          song.numero.toString().contains(q);
    }).toList();
  }

  String _normalize(String input) {
    const withAccents =
        'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const withoutAccents =
        'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    final buffer = StringBuffer();
    for (final rune in input.split('')) {
      final idx = withAccents.indexOf(rune);
      buffer.write(idx >= 0 ? withoutAccents[idx] : rune);
    }
    return buffer.toString().toLowerCase();
  }
}