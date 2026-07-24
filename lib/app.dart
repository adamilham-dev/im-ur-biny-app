import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/debug/debug_menu_overlay.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/biny_flight_overlay.dart';
import 'features/idle/presentation/idle_screen.dart';
import 'features/welcome/presentation/welcome_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/mode_select/presentation/mode_select_screen.dart';
import 'features/category_select/presentation/category_select_screen.dart';
import 'features/camera_guide/presentation/camera_guide_screen.dart';
import 'features/countdown/presentation/countdown_screen.dart';
import 'features/scanning/presentation/scanning_screen.dart';
import 'features/result/presentation/result_screen.dart';
import 'features/multi_result/presentation/multi_result_screen.dart';
import 'features/unknown_detected/presentation/unknown_detected_screen.dart';
import 'features/analyzing/presentation/analyzing_screen.dart';
import 'features/conclusion_new/presentation/conclusion_new_screen.dart';
import 'features/conclusion_existing/presentation/conclusion_existing_screen.dart';
import 'features/dataset_saved/presentation/dataset_saved_screen.dart';
import 'features/continue_session/presentation/continue_session_screen.dart';
import 'features/thank_you/presentation/thank_you_screen.dart';
import 'features/manual_correction/presentation/manual_correction_screen.dart';
import 'features/out_of_frame/presentation/out_of_frame_screen.dart';
import 'features/too_large/presentation/too_large_screen.dart';
import 'features/low_confidence/presentation/low_confidence_screen.dart';
import 'features/mixed_attached/presentation/mixed_attached_screen.dart';
import 'features/mixed_partial/presentation/mixed_partial_screen.dart';
import 'features/mixed_too_many/presentation/mixed_too_many_screen.dart';
import 'features/mixed_check/presentation/mixed_check_screen.dart';
import 'features/feedback/presentation/feedback_screen.dart';
import 'core/providers/bluetooth_provider.dart';
import 'core/providers/scan_provider.dart';


// ── Page transition tuning ──────────────────────────────────────────────
// Smooth fade + directional slide. Direction is derived from the
// animation status, so push and pop are handled by a single builder.
const Duration _kPageTransitionDuration = Duration(milliseconds: 380);
const Curve _kPageTransitionCurve = Curves.easeOutCubic;
const double _kSlideFractionX = 0.05;

Widget _appPageTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Direction is implicit: on push `animation` runs 0→1 and the entering
  // page slides in from +5%; on pop it runs 1→0 and the same Tween naturally
  // slides the page back out to +5%. `secondaryAnimation` works the same way
  // for the underlying page drifting to -5%. No manual status tracking is
  // needed — this mirrors the CupertinoPageRoute pattern.
  final primarySlide = Tween<Offset>(
    begin: const Offset(_kSlideFractionX, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: _kPageTransitionCurve));
  final primaryOpacity = Tween<double>(begin: 0.0, end: 1.0)
      .chain(CurveTween(curve: _kPageTransitionCurve));

  final secondarySlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-_kSlideFractionX, 0),
  ).chain(CurveTween(curve: _kPageTransitionCurve));
  final secondaryOpacity = Tween<double>(begin: 1.0, end: 0.0)
      .chain(CurveTween(curve: _kPageTransitionCurve));

  return SlideTransition(
    position: animation.drive(primarySlide),
    child: FadeTransition(
      opacity: animation.drive(primaryOpacity),
      child: SlideTransition(
        position: secondaryAnimation.drive(secondarySlide),
        child: FadeTransition(
          opacity: secondaryAnimation.drive(secondaryOpacity),
          child: child,
        ),
      ),
    ),
  );
}

Page<void> _appPage(Widget screen) => CustomTransitionPage<void>(
      child: screen,
      transitionDuration: _kPageTransitionDuration,
      reverseTransitionDuration: _kPageTransitionDuration,
      transitionsBuilder: _appPageTransitionBuilder,
    );

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 01 - Idle / Screensaver
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _appPage(const IdleScreen()),
      ),
      // 02 - Welcome / Start Session
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => _appPage(const WelcomeScreen()),
      ),
      // 03 - Onboarding (1/4 → 4/4)
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _appPage(const OnboardingScreen()),
      ),
      // 04 - Pilih Mode Sampah
      GoRoute(
        path: '/mode-select',
        pageBuilder: (context, state) => _appPage(const ModeSelectScreen()),
      ),
      // 05 - Pilih Kategori Awal
      GoRoute(
        path: '/category-select',
        pageBuilder: (context, state) => _appPage(const CategorySelectScreen()),
      ),
      // 06 - Camera Placement Guide
      GoRoute(
        path: '/camera-guide',
        pageBuilder: (context, state) => _appPage(const CameraGuideScreen()),
      ),
      // 06b - Countdown Before Scan
      GoRoute(
        path: '/countdown',
        pageBuilder: (context, state) => _appPage(const CountdownScreen()),
      ),
      // 07 - Scanning / AI Loading
      GoRoute(
        path: '/scanning',
        pageBuilder: (context, state) => _appPage(const ScanningScreen()),
      ),
      // 08 - Result Detection
      GoRoute(
        path: '/result',
        pageBuilder: (context, state) => _appPage(const ResultScreen()),
      ),
      // 09 - Multi-Result (Mixed Waste)
      GoRoute(
        path: '/multi-result',
        pageBuilder: (context, state) => _appPage(const MultiResultScreen()),
      ),
      // 10 - Detail Item (Popup) — shown via DetailItemScreen.show() as
      // a transparent dialog overlay on top of result / multi-result screens.
      // 11 - Unknown Detected
      GoRoute(
        path: '/unknown-detected',
        pageBuilder: (context, state) => _appPage(const UnknownDetectedScreen()),
      ),
      // 12 - Analyzing (AI Agent)
      GoRoute(
        path: '/analyzing',
        pageBuilder: (context, state) => _appPage(const AnalyzingScreen()),
      ),
      // 13 - Conclusion - Kategori Baru
      GoRoute(
        path: '/conclusion-new',
        pageBuilder: (context, state) => _appPage(const ConclusionNewScreen()),
      ),
      // 14 - Conclusion - Kategori Existing
      GoRoute(
        path: '/conclusion-existing',
        pageBuilder: (context, state) => _appPage(const ConclusionExistingScreen()),
      ),
      // 15 - Dataset Saved
      GoRoute(
        path: '/dataset-saved',
        pageBuilder: (context, state) => _appPage(const DatasetSavedScreen()),
      ),
      // 16 - Continue / End Session
      GoRoute(
        path: '/continue-session',
        pageBuilder: (context, state) => _appPage(const ContinueSessionScreen()),
      ),
      // 17 - Thank You
      GoRoute(
        path: '/thank-you',
        pageBuilder: (context, state) => _appPage(const ThankYouScreen()),
      ),
      // 18 - Manual Correction
      GoRoute(
        path: '/manual-correction',
        pageBuilder: (context, state) => _appPage(const ManualCorrectionScreen()),
      ),
      // 19 - Out of Frame
      GoRoute(
        path: '/out-of-frame',
        pageBuilder: (context, state) => _appPage(const OutOfFrameScreen()),
      ),
      // 20 - Too Large
      GoRoute(
        path: '/too-large',
        pageBuilder: (context, state) => _appPage(const TooLargeScreen()),
      ),
      // 21 - Low Confidence
      GoRoute(
        path: '/low-confidence',
        pageBuilder: (context, state) => _appPage(const LowConfidenceScreen()),
      ),
      // 23 - Mixed - Objek Menempel
      GoRoute(
        path: '/mixed-attached',
        pageBuilder: (context, state) => _appPage(const MixedAttachedScreen()),
      ),
      // 24 - Mixed - Sebagian di Luar Area
      GoRoute(
        path: '/mixed-partial',
        pageBuilder: (context, state) => _appPage(const MixedPartialScreen()),
      ),
      // 25 - Mixed - Terlalu Banyak Objek
      GoRoute(
        path: '/mixed-too-many',
        pageBuilder: (context, state) => _appPage(const MixedTooManyScreen()),
      ),
      // 26 - Mixed - Sebagian Perlu Dicek
      GoRoute(
        path: '/mixed-check',
        pageBuilder: (context, state) => _appPage(const MixedCheckScreen()),
      ),
      // Feedback
      GoRoute(
        path: '/feedback',
        pageBuilder: (context, state) => _appPage(const FeedbackScreen()),
      ),
    ],
  );
});

class ImUrBinyApp extends ConsumerWidget {
  const ImUrBinyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    ref.watch(bluetoothProvider);

    return MaterialApp.router(
      title: "I'm ur Biny",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => DebugMenuOverlay(
        router: router,
        child: BinyFlightOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
