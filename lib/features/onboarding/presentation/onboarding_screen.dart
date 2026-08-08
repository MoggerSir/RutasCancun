import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';

/// Pantalla de bienvenida premium — glass + curvas orgánicas.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPageData(
      icon: 'assets/icons/bus.svg',
      title: 'Rutas Cancún',
      body:
          'Consulta combis y camiones con datos oficiales y comunitarios. '
          'Encuentra la mejor ruta por cobertura, distancia y servicio nocturno.',
      accent: AppColors.primary,
    ),
    _OnboardPageData(
      icon: 'assets/icons/group.svg',
      title: 'Tu reporte ayuda a otros',
      body:
          'Los reportes son de la comunidad — tu aporte importa. '
          'Indica si el camión va lleno, pasó recién o hubo un problema.',
      accent: AppColors.secondary,
    ),
    _OnboardPageData(
      icon: 'assets/icons/clock.svg',
      title: 'Estimaciones sin tráfico en vivo',
      body:
          'Los tiempos son aproximados. R1 y R2 operan 24 h en la Zona Hotelera; '
          'otras rutas tienen horario diurno o extendido.',
      accent: AppColors.accent,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: AppColors.curvePremium,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(color: AppColors.primary.withValues(alpha: 0.18), size: 280),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _GlowOrb(color: AppColors.secondary.withValues(alpha: 0.10), size: 220),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _PageDots(count: _pages.length, index: _page),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _OnboardPage(data: _pages[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      if (_page > 0)
                        TextButton(
                          onPressed: () => _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 420),
                            curve: AppColors.curvePremium,
                          ),
                          child: const Text('Atrás'),
                        )
                      else
                        const SizedBox(width: 72),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        child: Text(_page == _pages.length - 1 ? 'Empezar' : 'Siguiente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPageData {
  const _OnboardPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String icon;
  final String title;
  final String body;
  final Color accent;
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.data});
  final _OnboardPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassSurface(
            borderRadius: BorderRadius.circular(32),
            blur: 28,
            padding: const EdgeInsets.all(36),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        data.accent.withValues(alpha: 0.28),
                        data.accent.withValues(alpha: 0.04),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: data.accent.withValues(alpha: 0.35), blurRadius: 24),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    data.icon,
                    width: 40,
                    height: 40,
                    colorFilter: ColorFilter.mode(data.accent, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  data.body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: AppColors.curveSpring,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? AppColors.primary : AppColors.glassBorder,
          ),
        );
      }),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
