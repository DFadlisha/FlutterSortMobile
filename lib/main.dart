import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:myapp/features/home/home_page.dart';
import 'package:myapp/theme/theme_provider.dart';
import 'package:myapp/theme/app_colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const SortMasterApp(),
    ),
  );
}

class SortMasterApp extends StatelessWidget {
  const SortMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.openSans(fontSize: 14),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Quality Control System Report (QCSR)',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryPurple,
              primary: AppColors.primaryPurple,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.lightBackground,
            textTheme: appTextTheme,
            appBarTheme: AppBarTheme(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              titleTextStyle: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryPurple,
              primary: AppColors.primaryPurple,
              surface: AppColors.darkSurface,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: AppColors.darkBackground,
            textTheme: appTextTheme,
            appBarTheme: AppBarTheme(
              backgroundColor: AppColors.darkSurface,
              foregroundColor: Colors.white,
              titleTextStyle: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            cardTheme: CardTheme(
              color: AppColors.darkCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.2)),
              ),
            ),
          ),
          themeMode: themeProvider.themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
