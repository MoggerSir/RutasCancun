import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/features/map/widgets/user_location_pulse_marker.dart';

/// Ubicación GPS sobre todas las capas del mapa (z-index visual alto).
class UserLocationOverlay extends StatefulWidget {
  const UserLocationOverlay({
    super.key,
    required this.controller,
    required this.position,
  });

  final MapController controller;
  final LatLng position;

  @override
  State<UserLocationOverlay> createState() => _UserLocationOverlayState();
}

class _UserLocationOverlayState extends State<UserLocationOverlay> {
  StreamSubscription<MapEvent>? _mapSub;

  @override
  void initState() {
    super.initState();
    _mapSub = widget.controller.mapEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.controller.camera;
    final projected = camera.project(widget.position) - camera.pixelOrigin;
    const size = UserLocationPulseMarker.size;

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: projected.x - size / 2,
            top: projected.y - size / 2,
            width: size,
            height: size,
            child: const UserLocationPulseMarker(),
          ),
        ],
      ),
    );
  }
}
