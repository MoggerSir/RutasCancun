import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

enum MapTileTheme { day, night }

/// Carto Voyager (día) o Dark Matter (modo nocturno).
class InstitutionalMapTileLayer extends TileLayer {
  InstitutionalMapTileLayer({super.key, this.theme = MapTileTheme.day})
      : super(
          urlTemplate: theme == MapTileTheme.night
              ? (kIsWeb
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                  : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png')
              : (kIsWeb
                  ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png'),
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.rutascancun.app',
          // Evita animar y conservar decenas de teselas fuera de pantalla en
          // CanvasKit. El mapa web prioriza respuesta inmediata durante pan;
          // las apps nativas conservan el buffer y fade predeterminados.
          tileDisplay: kIsWeb
              ? const TileDisplay.instantaneous()
              : const TileDisplay.fadeIn(),
          panBuffer: kIsWeb ? 0 : 1,
          keepBuffer: kIsWeb ? 1 : 2,
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
    1.275,
    -0.250,
    -0.025,
    0,
    0,
    -0.075,
    1.100,
    -0.025,
    0,
    0,
    -0.075,
    -0.250,
    1.325,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    final tiles = InstitutionalMapTileLayer(theme: theme);
    // ColorFiltered sobre todas las teselas obliga a CanvasKit a crear una
    // capa de pantalla completa. En web usamos Voyager sin filtro: mantiene
    // el mapa legible y reduce mucho el coste durante pan y zoom.
    if (theme == MapTileTheme.night || kIsWeb) return tiles;
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
