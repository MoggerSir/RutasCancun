import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

const presetPoints = <Map<String, dynamic>>[
  {'label': 'Terminal ADO', 'lat': 21.16542, 'lng': -86.85121},
  {'label': 'Plaza Las Américas', 'lat': 21.15277, 'lng': -86.82458},
  {'label': 'Mercado 28', 'lat': 21.17423, 'lng': -86.80745},
  {'label': 'Playa Delfines', 'lat': 21.06118, 'lng': -86.77913},
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Map<String, dynamic>? _origin;
  Map<String, dynamic>? _destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿A dónde vas?')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Busca una calle, colonia, comercio o punto de interés en Cancún.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 14),
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _PlaceSearchField(
                  title: 'Punto de partida',
                  hint: 'Ej. Gran Plaza, Av. Kabah…',
                  icon: Icons.trip_origin_rounded,
                  iconColor: const Color(0xFF13A66A),
                  selected: _origin,
                  onSelected: (point) => setState(() => _origin = point),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _PlaceSearchField(
                  title: 'Destino',
                  hint: 'Ej. Playa Delfines, Mercado 28…',
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFE94F55),
                  selected: _destination,
                  onSelected: (point) => setState(() => _destination = point),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Lugares frecuentes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetPoints.map((point) {
              return ActionChip(
                avatar: const Icon(Icons.place_outlined, size: 17),
                label: Text(point['label'] as String),
                onPressed: () {
                  if (_origin == null) {
                    setState(() => _origin = point);
                  } else {
                    setState(() => _destination = point);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _origin != null && _destination != null
                ? () => context.push('/search/results', extra: {
                      'origin': _origin,
                      'destination': _destination,
                    })
                : null,
            icon: const Icon(Icons.route_rounded),
            label: const Text('Calcular mi recorrido'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchField extends ConsumerStatefulWidget {
  const _PlaceSearchField({
    required this.title,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>?> onSelected;

  @override
  ConsumerState<_PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<_PlaceSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selected?['label'] as String? ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _PlaceSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = widget.selected?['label'] as String? ?? '';
    if (label != _controller.text && label.isNotEmpty) {
      _controller.text = label;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (widget.selected?['label'] != value) widget.onSelected(null);
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () => _search(value));
  }

  Future<void> _search(String value) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results =
          await ref.read(routesRepositoryProvider).searchPlaces(value);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _suggestions = results;
        _loading = false;
        if (results.isEmpty) {
          _error = 'No encontramos ese lugar dentro de Cancún';
        }
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
        _error = 'No fue posible buscar ahora. Intenta de nuevo.';
      });
    }
  }

  void _select(PlaceSuggestion suggestion) {
    _debounce?.cancel();
    _controller.text = suggestion.label;
    widget.onSelected(suggestion.toPoint());
    setState(() {
      _suggestions = const [];
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, color: widget.iconColor),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 7, left: 4),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: _suggestions.map((suggestion) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(suggestion.label),
                  subtitle: suggestion.secondaryLabel.isEmpty
                      ? null
                      : Text(
                          suggestion.secondaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => _select(suggestion),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
