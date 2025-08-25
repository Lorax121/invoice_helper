import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager_plus_v2/window_manager_plus_v2.dart';
import 'core/services/pdf_parser_service.dart';
import 'core/services/settings_service.dart';
import 'features/1_pdf_import_screen/state/pdf_import_cubit.dart';
import 'features/1_pdf_import_screen/view/pdf_import_screen.dart';
import 'features/2_helper_overlay/state/helper_overlay_cubit.dart';
import 'features/2_helper_overlay/view/helper_overlay_window.dart';
import 'core/models/overlay_item.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowManagerPlus.ensureInitialized(0);

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(720, 520),
    center: true,
    title: 'Помощник обработки накладных',
  );
  WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
    await WindowManagerPlus.current.show();
    await WindowManagerPlus.current.focus();
  });

  final settingsService = SettingsService();
  final initialSettings = await settingsService.loadSettings();

  runApp(MainApp(
    settingsService: settingsService,
    initialSettings: initialSettings,
  ));
}

class MainApp extends StatelessWidget {
  final SettingsService settingsService;
  final AppSettings initialSettings;
  const MainApp(
      {super.key,
      required this.settingsService,
      required this.initialSettings});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PdfParserService>(
          create: (_) => CliPdfParserService(),
        ),
        RepositoryProvider<SettingsService>.value(
          value: settingsService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<PdfImportCubit>(
            create: (context) => PdfImportCubit(
              context.read<PdfParserService>(),
              context.read<SettingsService>(),
              initialSettings,
            ),
          ),
          BlocProvider<HelperOverlayCubit>(
            create: (context) {
              return HelperOverlayCubit(
                [],
                context.read<SettingsService>(),
                initialSettings,
              );
            },
          ),
        ],
        child: MaterialApp(
          title: 'Invoice Helper',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
          home: const ModeRouter(),
        ),
      ),
    );
  }
}

class ModeRouter extends StatelessWidget {
  const ModeRouter({super.key});

  Future<void> _configureMainWindow(BuildContext context) async {
    await WindowManagerPlus.current.setTitleBarStyle(TitleBarStyle.normal);
    await WindowManagerPlus.current.setAlwaysOnTop(false);
    await WindowManagerPlus.current.setHasShadow(true);
    await WindowManagerPlus.current
        .setBackgroundColor(Colors.transparent); 
    await WindowManagerPlus.current.setResizable(true);
    await WindowManagerPlus.current.setSize(const Size(800, 600));
    await WindowManagerPlus.current.setMinimumSize(const Size(720, 520));
    await WindowManagerPlus.current.center();
    await WindowManagerPlus.current.setTitle('Помощник обработки накладных');
  }

  Future<void> _configureOverlayWindow(BuildContext context) async {
    await WindowManagerPlus.current.setAsFrameless();
    await WindowManagerPlus.current.setBackgroundColor(Colors.transparent);
    await WindowManagerPlus.current.setHasShadow(true);
    await WindowManagerPlus.current.setAlwaysOnTop(true);
    await WindowManagerPlus.current.setResizable(true);
    await WindowManagerPlus.current.setSize(const Size(400, 600));
    await WindowManagerPlus.current.setMinimumSize(const Size(360, 250));
    await WindowManagerPlus.current.center();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PdfImportCubit, PdfImportState>(
      listenWhen: (previous, current) => previous.appMode != current.appMode,
      listener: (context, state) {
        if (state.appMode == AppMode.main) {
          _configureMainWindow(context);
        } else {
          _configureOverlayWindow(context);
        }
      },
      buildWhen: (previous, current) => previous.appMode != current.appMode,
      builder: (context, state) {
        return Container(
          color: Colors.transparent,
          child: Builder(
            builder: (context) {
              if (state.appMode == AppMode.main) {
                return const PdfImportScreen();
              } else {
                final overlayItems =
                    context.read<PdfImportCubit>().state.overlayItems;
                context.read<HelperOverlayCubit>().updateItems(overlayItems);
                return const HelperOverlayWindow();
              }
            },
          ),
        );
      },
    );
  }
}
