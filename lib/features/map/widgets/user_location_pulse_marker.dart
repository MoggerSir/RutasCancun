import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

/// Punto GPS del usuario — centro verde con ondas de pulso suaves.
class UserLocationPulseMarker extends StatefulWidget {
  const UserLocationPulseMarker({super.key});

  static const size = 96.0;
  static const dotSize = 13.0;

  @override
  State<UserLocationPulseMarker> createState() =>
      _UserLocationPulseMarkerState();
}

class _UserLocationPulseMarkerState extends State<UserLocationPulseMarker>
    with SingleTickerProviderStateMixin {
  static const _ringCount = 3;
  static const _duration = Duration(milliseconds: 3000);

  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _pulse = AnimationController(vsync: this, duration: _duration)..repeat();
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox(
        width: UserLocationPulseMarker.size,
        height: UserLocationPulseMarker.size,
        child: Center(child: _CenterDot(breathe: 1)),
      );
    }
    final pulse = _pulse!;
    return SizedBox(
      width: UserLocationPulseMarker.size,
      height: UserLocationPulseMarker.size,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < _ringCount; i++)
                _PulseRing(phase: (pulse.value + i / _ringCount) % 1.0),
              child!,
            ],
          );
        },
        child: _CenterDot(
            breathe: 0.5 +
                0.08 *
                    Curves.easeInOutSine.transform(
                      (pulse.value * 2) % 1.0,
                    )),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(phase);
    final scale = 0.35 + eased * 2.4;
    final opacity = (1.0 - phase) * 0.42;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.locationLive.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: AppColors.locationLive.withValues(alpha: opacity * 0.35),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterDot extends StatelessWidget {
  const _CenterDot({required this.breathe});

  final double breathe;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: breathe,
      child: Container(
        width: UserLocationPulseMarker.dotSize,
        height: UserLocationPulseMarker.dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.locationLive,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.locationLive.withValues(alpha: 0.55),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
