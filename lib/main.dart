import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'src/data/database.dart';
import 'src/data/diary_repository.dart';
import 'src/data/kassal_api.dart';
import 'src/data/settings_repository.dart';
import 'src/state/diary_controller.dart';
import 'src/ui/home_shell.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.initPlatform();
  // Norwegian date formatting is used throughout, so the locale data has to be
  // loaded before the first frame.
  await initializeDateFormatting('nb_NO');

  final settings = SettingsRepository();
  final diary = DiaryRepository();
  final api = KassalApi(tokenProvider: settings.readToken);

  runApp(FoodLensApp(settings: settings, diary: diary, api: api));
}

class FoodLensApp extends StatelessWidget {
  const FoodLensApp({
    super.key,
    required this.settings,
    required this.diary,
    required this.api,
  });

  final SettingsRepository settings;
  final DiaryRepository diary;
  final KassalApi api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: settings),
        Provider.value(value: diary),
        Provider.value(value: api),
        ChangeNotifierProvider(
          create: (_) => DiaryController(diary, settings)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Food Lens',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // The UI is written in Norwegian, and so are the built-in Material
        // strings in pickers and dialogs.
        locale: const Locale('nb', 'NO'),
        supportedLocales: const [Locale('nb', 'NO'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    );
  }
}
