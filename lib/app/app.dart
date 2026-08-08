import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/app/router.dart';
import 'package:rutas_cancun/core/theme/app_theme.dart';
import 'package:rutas_cancun/features/onboarding/presentation/onboarding_gate.dart';

class RutasCancunApp extends ConsumerWidget {
  const RutasCancunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Rutas Cancún',
      theme: buildPremiumTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => OnboardingGate(child: child ?? const SizedBox()),
      debugShowCheckedModeBanner: false,
    );
  }
}
