import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/features/donations/domain/donation_option.dart';

Future<void> _openDonationLink(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir el link de pago. Intenta de nuevo.'),
      ),
    );
  }
}

/// Diálogo con las distintas formas de apoyar el proyecto (links de pago de
/// Mercado Pago). Se puede abrir desde el chip de donaciones o desde
/// [showDonationWelcomeDialog].
Future<void> showDonationOptionsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const _DonationOptionsDialog(),
  );
}

class _DonationOptionsDialog extends StatefulWidget {
  const _DonationOptionsDialog();

  @override
  State<_DonationOptionsDialog> createState() => _DonationOptionsDialogState();
}

class _DonationOptionsDialogState extends State<_DonationOptionsDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Cascada: cada tile aparece un poco después que el anterior — se ve
    // deliberada y cuidada en vez de "todo aparece de golpe".
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 360 + donationOptions.length * 90,
      ),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.donation.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.all(9),
                    child: SvgPicture.asset(
                      'assets/icons/heart-solid.svg',
                      colorFilter: const ColorFilter.mode(
                          AppColors.donation, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Apoya Rutas Cancún',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Text(
                'Elige cómo apoyar. Todos los links abren Mercado Pago.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: donationOptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final option = donationOptions[index];
                  // Cada tile ocupa una fracción propia y solapada del
                  // recorrido total (solapar da fluidez; no solapar se ve
                  // entrecortado). easeOutCubic frena suave al llegar.
                  final start = (index * 0.55) / donationOptions.length;
                  final end = (start + 0.6).clamp(0.0, 1.0);
                  final curved = CurvedAnimation(
                    parent: _ctrl,
                    curve: Interval(start, end, curve: Curves.easeOutCubic),
                  );
                  return AnimatedBuilder(
                    animation: curved,
                    builder: (context, child) => Opacity(
                      opacity: curved.value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - curved.value) * 18),
                        child: child,
                      ),
                    ),
                    child: _DonationOptionTile(
                      option: option,
                      onTap: () => _openDonationLink(context, option.url),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationOptionTile extends StatefulWidget {
  const _DonationOptionTile({required this.option, required this.onTap});

  final DonationOption option;
  final VoidCallback onTap;

  @override
  State<_DonationOptionTile> createState() => _DonationOptionTileState();
}

class _DonationOptionTileState extends State<_DonationOptionTile> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final elevated = _hovering || _pressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: elevated
                  ? AppColors.donation.withValues(alpha: 0.07)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: elevated
                    ? AppColors.donation.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.donation.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.all(9),
                    child: SvgPicture.asset(
                      option.iconAsset,
                      colorFilter: const ColorFilter.mode(
                          AppColors.donation, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.donation.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                option.amountLabel,
                                style: const TextStyle(
                                  color: AppColors.donation,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.description,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
