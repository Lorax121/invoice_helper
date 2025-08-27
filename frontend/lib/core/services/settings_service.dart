import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

enum ParsingCore {
  camelot,
  dedoc;

  String get cliArgument => name;
}

class AppSettings {
  final bool? isQuantityEnabled;
  final bool? hideEmptyColumns;
  final bool? hideEmptyRows;
  final int? nameColumnIndex;
  final int? priceColumnIndex;
  final int? quantityColumnIndex;
  final double? overlayFontSize;
  final double? overlayOpacity;
  final ParsingCore? selectedCore;
  final bool? useDedocPreprocessing; 

  AppSettings({
    this.isQuantityEnabled,
    this.hideEmptyColumns,
    this.hideEmptyRows,
    this.nameColumnIndex,
    this.priceColumnIndex,
    this.quantityColumnIndex,
    this.overlayFontSize,
    this.overlayOpacity,
    this.selectedCore,
    this.useDedocPreprocessing, 
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isQuantityEnabled: json['isQuantityEnabled'],
      hideEmptyColumns: json['hideEmptyColumns'],
      hideEmptyRows: json['hideEmptyRows'],
      nameColumnIndex: json['nameColumnIndex'],
      priceColumnIndex: json['priceColumnIndex'],
      quantityColumnIndex: json['quantityColumnIndex'],
      overlayFontSize: json['overlayFontSize'],
      overlayOpacity: json['overlayOpacity'],
      selectedCore: json['selectedCore'] != null
          ? ParsingCore.values.firstWhere(
              (e) => e.name == json['selectedCore'],
              orElse: () => ParsingCore.camelot, 
            )
          : null,
      useDedocPreprocessing: json['useDedocPreprocessing'] ?? false, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isQuantityEnabled': isQuantityEnabled,
      'hideEmptyColumns': hideEmptyColumns,
      'hideEmptyRows': hideEmptyRows,
      'nameColumnIndex': nameColumnIndex,
      'priceColumnIndex': priceColumnIndex,
      'quantityColumnIndex': quantityColumnIndex,
      'overlayFontSize': overlayFontSize,
      'overlayOpacity': overlayOpacity,
      'selectedCore': selectedCore?.name,
      'useDedocPreprocessing': useDedocPreprocessing, 
    };
  }

  AppSettings copyWith({
    bool? isQuantityEnabled,
    bool? hideEmptyColumns,
    bool? hideEmptyRows,
    int? nameColumnIndex,
    int? priceColumnIndex,
    int? quantityColumnIndex,
    double? overlayFontSize,
    double? overlayOpacity,
    ParsingCore? selectedCore,
    bool? useDedocPreprocessing, 
  }) {
    return AppSettings(
      isQuantityEnabled: isQuantityEnabled ?? this.isQuantityEnabled,
      hideEmptyColumns: hideEmptyColumns ?? this.hideEmptyColumns,
      hideEmptyRows: hideEmptyRows ?? this.hideEmptyRows,
      nameColumnIndex: nameColumnIndex ?? this.nameColumnIndex,
      priceColumnIndex: priceColumnIndex ?? this.priceColumnIndex,
      quantityColumnIndex: quantityColumnIndex ?? this.quantityColumnIndex,
      overlayFontSize: overlayFontSize ?? this.overlayFontSize,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      selectedCore: selectedCore ?? this.selectedCore,
      useDedocPreprocessing: useDedocPreprocessing ?? this.useDedocPreprocessing, 
    );
  }
}

class SettingsService {
  late final String _filePath;

  SettingsService() {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    _filePath = p.join(executableDir, 'app_settings.json');
  }

  Future<AppSettings> loadSettings() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          return AppSettings.fromJson(json);
        }
      }
    } catch (e) {
      print('Ошибка загрузки настроек: $e');
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final file = File(_filePath);
      final json = jsonEncode(settings.toJson());
      await file.writeAsString(json);
    } catch (e) {
      print('Ошибка сохранения настроек: $e');
    }
  }
}
