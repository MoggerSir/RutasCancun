import 'package:flutter_riverpod/flutter_riverpod.dart';

const deviceIdKey = 'device_id';
const tokenKey = 'auth_token';
const onboardingKey = 'onboarding_done';

final authTokenProvider = StateProvider<String?>((ref) => null);
