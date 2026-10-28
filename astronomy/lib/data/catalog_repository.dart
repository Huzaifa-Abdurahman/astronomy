import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../astro/models.dart';

/// Loads `assets/data/catalog.json` (CLAUDE.md §7).
///
/// Data sources: OpenNGC (Messier objects) and the HYG Database (named
/// stars), both CC BY-SA 4.0. Regenerate with `tool/build_catalog.py`.
class CatalogRepository {
  CatalogRepository(this._bundle);

  final AssetBundle _bundle;

  Future<List<SkyObject>> load() async {
    final raw = await _bundle.loadString('assets/data/catalog.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['objects'] as List).cast<Map<String, dynamic>>().map(SkyObject.fromJson).toList(growable: false);
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepository(rootBundle));

final catalogProvider = FutureProvider<List<SkyObject>>((ref) => ref.watch(catalogRepositoryProvider).load());

/// One catalog object by id, or null while loading / if unknown.
final skyObjectProvider = Provider.family<SkyObject?, String>((ref, id) {
  final list = ref.watch(catalogProvider).value;
  if (list == null) return null;
  for (final o in list) {
    if (o.id == id) return o;
  }
  return null;
});
