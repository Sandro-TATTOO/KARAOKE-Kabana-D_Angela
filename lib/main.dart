import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/supabase_client.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  SupabaseClientFactory.init();
  runApp(const KaraokeApp());
}

class KaraokeApp extends StatelessWidget {
  const KaraokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.deepPurple;
    const darkBrightness = Brightness.dark;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: darkBrightness,
        ).copyWith(
          surface: Colors.black,
          surfaceContainerHighest: const Color(0xFF1E1E1E),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karaokê Cabana Dona Angela',
      theme: ThemeData(
        useMaterial3: true,
        brightness: darkBrightness,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.robotoTextTheme(
          ThemeData(brightness: darkBrightness).textTheme,
        ),
      ),
      home: const HomePage(),
    );
  }
}
