import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../astro/models.dart';
import '../../data/sky_providers.dart';

/// Filter chips on Explore (CLAUDE.md §5 #4).
enum ExploreFilter {
  visibleNow('Visible now'),
  stars('Stars'),
  planets('Planets'),
  galaxies('Galaxies'),
  nebulae('Nebulae'),
  clusters('Clusters');

  const ExploreFilter(this.label);
  final String label;

  SkyObjectType? get type => switch (this) {
        ExploreFilter.stars => SkyObjectType.star,
        ExploreFilter.planets => SkyObjectType.planet,
        ExploreFilter.galaxies => SkyObjectType.galaxy,
        ExploreFilter.nebulae => SkyObjectType.nebula,
        ExploreFilter.clusters => SkyObjectType.cluster,
        ExploreFilter.visibleNow => null,
      };

  static ExploreFilter? fromTypeName(String? name) {
    if (name == null) return null;
    for (final f in values) {
      if (f.type?.name == name) return f;
    }
    return null;
  }
}

class ExploreState {
  const ExploreState({this.query = '', this.visibleNow = false, this.type});

  final String query;
  final bool visibleNow;

  /// At most one type filter at a time; null shows every type.
  final ExploreFilter? type;

  bool isOn(ExploreFilter f) => f == ExploreFilter.visibleNow ? visibleNow : type == f;
}

class ExploreController extends Notifier<ExploreState> {
  @override
  ExploreState build() => const ExploreState();

  void setQuery(String q) => state = ExploreState(query: q, visibleNow: state.visibleNow, type: state.type);

  void toggle(ExploreFilter f) {
    if (f == ExploreFilter.visibleNow) {
      state = ExploreState(query: state.query, visibleNow: !state.visibleNow, type: state.type);
    } else {
      state = ExploreState(query: state.query, visibleNow: state.visibleNow, type: state.type == f ? null : f);
    }
  }

  void showType(ExploreFilter f) => state = ExploreState(query: state.query, visibleNow: state.visibleNow, type: f);
}

final exploreControllerProvider = NotifierProvider<ExploreController, ExploreState>(ExploreController.new);

/// Normalises "M 31", "m31", "NGC224", "ngc 224" for matching.
String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// Filtered, sorted list for Explore. Null while catalog or location load.
final exploreResultsProvider = Provider<List<SkyListItem>?>((ref) {
  final all = ref.watch(skyListProvider);
  if (all == null) return null;
  final s = ref.watch(exploreControllerProvider);
  final q = _norm(s.query);
  final out = all.where((i) {
    final o = i.object;
    if (o.id == 'sun') return false;
    if (s.type != null && o.type != s.type!.type) return false;
    if (s.visibleNow && !i.horizontal.isUp) return false;
    if (q.isEmpty) return true;
    return _norm(o.name).contains(q) ||
        _norm(o.catalog) == q ||
        (q.length > 1 && _norm(o.catalog).startsWith(q)) ||
        (o.altId != null && _norm(o.altId!) == q) ||
        (o.constellation != null && _norm(o.constellation!).startsWith(q));
  }).toList();
  // Highest first when only showing what is up now (CLAUDE.md §5 #4).
  if (s.visibleNow) out.sort((a, b) => b.horizontal.altDeg.compareTo(a.horizontal.altDeg));
  return out;
});
