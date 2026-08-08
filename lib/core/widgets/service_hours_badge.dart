import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/features/routes/domain/route_service_hours.dart';

/// Etiqueta compacta de horario / servicio nocturno.
class ServiceHoursBadge extends StatelessWidget {
  const ServiceHoursBadge({
    super.key,
    required this.routeCode,
    this.metadata,
    this.compact = false,
  });

  final String routeCode;
  final Map<String, dynamic>? metadata;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = RouteServiceHours.forCode(routeCode, metadata: metadata);
    if (info == null || !info.hasNightService) return const SizedBox.shrink();

    final color = info.level == RouteServiceLevel.allDay24h
        ? AppColors.accent
        : AppColors.secondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        info.badgeLabel,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
