import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

enum MapTileTheme { day, night }

/// Carto Voyager (día) o Dark Matter (modo nocturno).
class InstitutionalMapTileLayer extends TileLayer {
  InstitutionalMapTileLayer({super.key, this.theme = MapTileTheme.day})
      : super(
          urlTemplate: theme == MapTileTheme.night
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.rutascancun.app',
        );

  final MapTileTheme theme;
}

/// Basemap con saturación realzada — Voyager de fábrica se ve pálido/lavado
/// a zoom de ciudad completa (parques, agua y vialidades casi del mismo tono
/// que el fondo), lo que hacía difícil ubicarse rápido. Este filtro sube la
/// saturación ~30% preservando la luminancia (no oscurece ni aclara), solo
/// para el tema de día — el tema nocturno (Dark Matter) ya es de por sí
/// contrastado y deliberadamente desaturado, boostearlo se vería artificial.
class VividMapTiles extends StatelessWidget {
  const VividMapTiles({super.key, this.theme = MapTileTheme.day});

  final MapTileTheme theme;

  static const _saturationBoost = ColorFilter.matrix(<double>[
    1.275, -0.250, -0.025, 0, 0,
    -0.075, 1.100, -0.025, 0, 0,
    -0.075, -0.250, 1.325, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final tiles = InstitutionalMapTileLayer(theme: theme);
    if (theme == MapTileTheme.night) return tiles;
    // RepaintBoundary fuerza que las teselas (cada una con su propio fade-in
    // al cargar) se aplanen a una sola textura ANTES del filtro de color —
    // sin esto, Skia filtra cada tesela animada por separado y el resultado
    // es una interferencia visual tipo estática/ruido en vez de un tinte
    // parejo (visto y confirmado en pantalla, no es solo teórico).
    return RepaintBoundary(
      child: ColorFiltered(colorFilter: _saturationBoost, child: tiles),
    );
  }
}
