import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../astro/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/location_service.dart';
import '../../data/place_service.dart';

/// Opens the "Enter a city instead" sheet. Resolves to true when a location was set.
Future<bool> showManualLocationSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _ManualLocationSheet(),
  );
  return result ?? false;
}

class _ManualLocationSheet extends ConsumerStatefulWidget {
  const _ManualLocationSheet();

  @override
  ConsumerState<_ManualLocationSheet> createState() => _ManualLocationSheetState();
}

class _ManualLocationSheetState extends ConsumerState<_ManualLocationSheet> {
  final _query = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _searching = false;
  String? _error;
  bool _coordsMode = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await ref.read(placeServiceProvider).search(q);
      if (!mounted) return;
      setState(() => _results = r);
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'City search needs internet. You can type coordinates instead.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(Place p) async {
    await ref
        .read(locationProvider.notifier)
        .setManual(Observer(latDeg: p.lat, lonDeg: p.lon, altitudeM: p.elevationM ?? 0), label: p.name);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _saveCoords() async {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      setState(() => _error = 'Latitude must be −90…90 and longitude −180…180 (east positive).');
      return;
    }
    await ref.read(locationProvider.notifier).setManual(Observer(latDeg: lat, lonDeg: lon));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.surfaceBorderStrong, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Choose your location', style: AppText.section),
        const SizedBox(height: 4),
        Text('Search for a city, or type latitude and longitude.', style: AppText.body(14, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('City'), icon: Icon(AppIcons.search, size: 18)),
            ButtonSegment(value: true, label: Text('Coordinates'), icon: Icon(AppIcons.crosshair, size: 18)),
          ],
          selected: {_coordsMode},
          onSelectionChanged: (s) => setState(() {
            _coordsMode = s.first;
            _error = null;
          }),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.bg : AppColors.textSoft,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.cyan : Colors.transparent,
            ),
            side: const WidgetStatePropertyAll(BorderSide(color: AppColors.surfaceBorderStrong)),
          ),
        ),
        const SizedBox(height: 14),
        if (!_coordsMode) ..._cityMode() else ..._coordsFields(),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.body(13, color: AppColors.red)),
        ],
      ]),
    );
  }

  List<Widget> _cityMode() => [
        _Field(
          controller: _query,
          hint: 'Search a city',
          icon: AppIcons.search,
          autofocus: true,
          onChanged: _onQuery,
          trailing: _searching
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan))
              : null,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(shrinkWrap: true, children: [
            for (final p in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.mapPin, color: AppColors.cyan),
                title: Text(p.name, style: AppText.body(15, weight: FontWeight.w600)),
                subtitle: Text(
                  '${p.subtitle}${p.subtitle.isEmpty ? '' : ' · '}${formatCoords(p.lat, p.lon)}',
                  style: AppText.body(12, color: AppColors.textMuted),
                ),
                onTap: () => _pick(p),
              ),
          ]),
        ),
      ];

  List<Widget> _coordsFields() => [
        Row(children: [
          Expanded(child: _Field(controller: _lat, hint: 'Latitude, e.g. 33.6844', numeric: true)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: _lon, hint: 'Longitude, e.g. 73.0479', numeric: true)),
        ]),
        const SizedBox(height: 16),
        GradientButton(label: 'Use these coordinates', onPressed: _saveCoords),
      ];
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.icon,
    this.onChanged,
    this.trailing,
    this.numeric = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final bool numeric;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, color: AppColors.textMuted, size: 20), const SizedBox(width: 10)],
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            keyboardType: numeric ? const TextInputType.numberWithOptions(signed: true, decimal: true) : TextInputType.text,
            style: numeric ? AppText.mono(15) : AppText.body(15),
            decoration: InputDecoration(hintText: hint, isCollapsed: true),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}
