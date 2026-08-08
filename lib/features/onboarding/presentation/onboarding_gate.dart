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
    ref.watch(authInitProvider);
    final onboarding = ref.watch(onboardingDoneProvider);

    return onboarding.when(
      loading: () => const ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
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
