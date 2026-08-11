import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/features/auth/data/auth_repository.dart';
import 'package:rutas_cancun/features/onboarding/presentation/onboarding_screen.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authInitProvider);
    final onboarding = ref.watch(onboardingDoneProvider);

    if (auth.isLoading) {
      return const ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (auth.hasError) {
      return ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(authInitProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar conexión segura'),
          ),
        ),
      );
    }

    return onboarding.when(
      loading: () => const ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
      ),
      error: (_, __) => child,
      data: (done) {
        if (done) return child;
        return OnboardingScreen(onComplete: () => completeOnboarding(ref));
      },
    );
  }
}
