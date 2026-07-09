import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/constants/app_constants.dart';
import 'firebase/firebase_init.dart';
import 'providers/auth_providers.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load locale data so DateFormat works for en_GB (dd/MM/yyyy etc.).
  await initializeDateFormatting();
  Intl.defaultLocale = AppConstants.defaultLocale;

  // Initialise Firebase and enable Firestore offline persistence.
  await FirebaseInit.ensureInitialized();

  runApp(const ProviderScope(child: BuilderCrmApp()));
}

/// Root widget. Shows a splash until the first auth state is known, then hands
/// off to the go_router-driven navigation.
class BuilderCrmApp extends ConsumerWidget {
  const BuilderCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authStateProvider);

    // While Firebase resolves the initial auth state, show a branded splash so
    // no protected screen builds before we know who (if anyone) is signed in.
    if (auth.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const _Splash(),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.handyman_rounded,
                  size: 46, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(AppConstants.appName,
                style:
                    theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
