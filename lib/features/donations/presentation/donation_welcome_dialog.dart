import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/features/donations/presentation/donation_dialog.dart';

/// Mensaje de bienvenida que se muestra una sola vez por sesión al abrir la
/// versión web, invitando a apoyar el proyecto. No se usa en la app móvil
/// (allí basta el chip persistente, sin interrumpir al abrir).
Future<void> showDonationWelcomeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.donation.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset(
                  'assets/icons/heart-solid.svg',
                  colorFilter: const ColorFilter.mode(
                      AppColors.donation, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Apoya Rutas Cancún',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Rutas Cancún es gratis y mantenerla requiere tiempo, café '
                'y uno que otro camión perdido. Si la app te ha servido, '
                'puedes apoyarme a mí, su desarrollador, para seguir '
                'mejorando día a día este proyecto para nosotros los '
                'cancunenses.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Ahora no'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        showDonationOptionsDialog(context);
                      },
                      icon: const Icon(Icons.favorite_rounded, size: 18),
                      label: const Text('Donar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.donation,
                        minimumSize: const Size.fromHeight(46),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
