import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/recording_setup_screen.dart';

final rootNavigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());

class OpenScreenStudio extends ConsumerWidget {
  const OpenScreenStudio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootNavigatorKey = ref.watch(rootNavigatorKeyProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'OpenScreen Studio',
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: const RecordingSetupScreen(),
    );
  }
} 