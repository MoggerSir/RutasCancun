import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/features/donations/presentation/donation_dialog.dart';

/// Chip persistente para abrir las opciones de donación. Vive en el mapa
/// (junto a la búsqueda) tanto en móvil como en la versión web.
///
/// Reacciona a hover (web/desktop, vía [MouseRegion]) y a press (todas las
/// plataformas, vía [GestureDetector]) con una pequeña escala + cambio de
/// sombra — el mismo tipo de microinteracción que hace sentir "premium" a
/// un botón sin depender de una librería de animación externa.
class DonationChip extends StatefulWidget {
  const DonationChip({super.key});

  @override
  State<DonationChip> createState() => _DonationChipState();
}

class _DonationChipState extends State<DonationChip> {
  bool _hovering = false;
  bool _pressed = false;

  double get _scale => _pressed ? 0.94 : (_hovering ? 1.05 : 1.0);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Donar, apoyar el proyecto',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () => showDonationOptionsDialog(context),
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: AppColors.donation,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.donation
                        .withValues(alpha: _hovering ? 0.45 : 0.28),
                    blurRadius: _hovering ? 16 : 8,
                    offset: Offset(0, _hovering ? 6 : 3),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: SvgPicture.asset(
                        'assets/icons/heart-solid.svg',
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Donar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
