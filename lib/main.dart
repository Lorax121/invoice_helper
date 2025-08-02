import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager_plus_v2/window_manager_plus_v2.dart';
import 'core/services/pdf_parser_service.dart';
import 'features/1_pdf_import_screen/state/pdf_import_cubit.dart';
import 'features/1_pdf_import_screen/view/pdf_import_screen.dart';
import 'features/2_helper_overlay/model/overlay_item.dart';
import 'features/2_helper_overlay/view/helper_overlay_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowManagerPlus.ensureInitialized(
    args.isEmpty ? 0 : int.tryParse(args[0]) ?? 0,
  );

  if (args.isNotEmpty) {
    final itemsJson = args.length > 1 ? args[1] : '[]';
    final List<dynamic> itemsList = jsonDecode(itemsJson);
    final List<OverlayItem> overlayItems = itemsList
        .map((e) => OverlayItem.fromTableRow(
              e as Map<String, dynamic>,
              e['__name_col'] as String,
              e['__price_col'] as String?,
            ))
        .toList();

    _setupAndShowOverlayWindow();
    runApp(OverlayApp(items: overlayItems));
  } else {
    _setupAndShowMainWindow();
    runApp(const MainApp());
  }
}

void _setupAndShowMainWindow() {
  WindowOptions windowOptions = const WindowOptions(
    size: Size(680, 480),
    minimumSize: Size(680, 480),
    center: true,
    title: 'Помощник обработки накладных',
  );
  WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
    await WindowManagerPlus.current.show();
    await WindowManagerPlus.current.focus();
  });
}

void _setupAndShowOverlayWindow() {
  WindowManagerPlus.current.setAsFrameless().then((_) {
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 600),
      alwaysOnTop: true,
      skipTaskbar: false,
      backgroundColor: Colors.transparent,
    );
    WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
      await WindowManagerPlus.current.setResizable(true);
      await WindowManagerPlus.current.center();
      await WindowManagerPlus.current.show();
      await WindowManagerPlus.current.focus();
    });
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<PdfParserService>(
      create: (_) => CliPdfParserService(),
      child: BlocProvider<PdfImportCubit>(
        create: (context) => PdfImportCubit(context.read<PdfParserService>()),
        child: MaterialApp(
          title: 'Invoice Helper',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
          home: const PdfImportScreen(),
        ),
      ),
    );
  }
}

class OverlayApp extends StatelessWidget {
  final List<OverlayItem> items;
  const OverlayApp({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.dark),
          useMaterial3: true),
      home: HelperOverlayWindow(items: items),
    );
  }
}
