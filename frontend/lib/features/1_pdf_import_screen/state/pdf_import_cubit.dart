import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/processed_file.dart';
import '../../../core/services/pdf_parser_service.dart';
import '../../../core/services/settings_service.dart';

enum LoadingStatus { idle, loading, needsBulkConfirmation, success, error }

class PdfImportState extends Equatable {
  final List<ProcessedFile> processedFiles;
  final int activeFileIndex;
  final LoadingStatus status;
  final String message;
  final int? overlayWindowId;
  final bool hideEmptyColumns;
  final bool hideEmptyRows;
  final List<String> duplicateFilePaths;
  final bool isQuantityEnabled; 

  const PdfImportState({
    this.processedFiles = const [],
    this.activeFileIndex = -1,
    this.status = LoadingStatus.idle,
    this.message = '',
    this.overlayWindowId,
    this.hideEmptyColumns = false,
    this.hideEmptyRows = false,
    this.duplicateFilePaths = const [],
    this.isQuantityEnabled = false, 
  });

  ProcessedFile? get activeFile => (activeFileIndex != -1 &&
          activeFileIndex < processedFiles.length &&
          processedFiles.isNotEmpty)
      ? processedFiles[activeFileIndex]
      : null;

  PdfImportState copyWith({
    List<ProcessedFile>? processedFiles,
    int? activeFileIndex,
    LoadingStatus? status,
    String? message,
    int? overlayWindowId,
    bool clearOverlayId = false,
    bool? hideEmptyColumns,
    bool? hideEmptyRows,
    List<String>? duplicateFilePaths,
    bool clearDuplicates = false,
    bool? isQuantityEnabled, 
  }) {
    return PdfImportState(
      processedFiles: processedFiles ?? this.processedFiles,
      activeFileIndex: activeFileIndex ?? this.activeFileIndex,
      status: status ?? this.status,
      message: message ?? this.message,
      overlayWindowId:
          clearOverlayId ? null : (overlayWindowId ?? this.overlayWindowId),
      hideEmptyColumns: hideEmptyColumns ?? this.hideEmptyColumns,
      hideEmptyRows: hideEmptyRows ?? this.hideEmptyRows,
      duplicateFilePaths: clearDuplicates
          ? []
          : (duplicateFilePaths ?? this.duplicateFilePaths),
      isQuantityEnabled:
          isQuantityEnabled ?? this.isQuantityEnabled, 
    );
  }

  @override
  List<Object?> get props => [
        processedFiles,
        activeFileIndex,
        status,
        message,
        overlayWindowId,
        hideEmptyColumns,
        hideEmptyRows,
        duplicateFilePaths,
        isQuantityEnabled, 
      ];
}

class PdfImportCubit extends Cubit<PdfImportState> {
  final PdfParserService _parserService;
  final SettingsService _settingsService;
  List<String> _pendingFilePaths = [];
  AppSettings _currentSettings;

  PdfImportCubit(
      this._parserService, this._settingsService, AppSettings initialSettings)
      : _currentSettings = initialSettings,
        super(PdfImportState(
          hideEmptyColumns: initialSettings.hideEmptyColumns ?? false,
          hideEmptyRows: initialSettings.hideEmptyRows ?? false,
          isQuantityEnabled: initialSettings.isQuantityEnabled ?? false,
        ));

  Future<void> _saveSettings() async {
    int? nameIndex, priceIndex, quantityIndex;
    if (state.activeFile != null) {
      if (state.activeFile!.selectedNameColumn != null) {
        nameIndex = state.activeFile!.headers
            .indexOf(state.activeFile!.selectedNameColumn!);
      }
      if (state.activeFile!.selectedPriceColumn != null) {
        priceIndex = state.activeFile!.headers
            .indexOf(state.activeFile!.selectedPriceColumn!);
      }
      if (state.activeFile!.selectedQuantityColumn != null) {
        quantityIndex = state.activeFile!.headers
            .indexOf(state.activeFile!.selectedQuantityColumn!);
      }
    }

    _currentSettings = _currentSettings.copyWith(
      hideEmptyColumns: state.hideEmptyColumns,
      hideEmptyRows: state.hideEmptyRows,
      isQuantityEnabled: state.isQuantityEnabled,
      nameColumnIndex: nameIndex != -1 ? nameIndex : null,
      priceColumnIndex: priceIndex != -1 ? priceIndex : null,
      quantityColumnIndex: quantityIndex != -1 ? quantityIndex : null,
    );
    await _settingsService.saveSettings(_currentSettings);
  }

  void setOverlayId(int windowId) {
    emit(state.copyWith(overlayWindowId: windowId));
  }

  void clearOverlayId() {
    emit(state.copyWith(clearOverlayId: true));
  }

  void toggleIsQuantityEnabled(bool isEnabled) {
    emit(state.copyWith(isQuantityEnabled: isEnabled));
    if (!isEnabled && state.activeFile != null) {
      selectColumnsForActiveFile(quantityColumn: null);
    } else {
      _saveSettings();
    }
  }

  void toggleHideEmptyColumns() {
    emit(state.copyWith(hideEmptyColumns: !state.hideEmptyColumns));
    _saveSettings();
  }

  void toggleHideEmptyRows() {
    emit(state.copyWith(hideEmptyRows: !state.hideEmptyRows));
    _saveSettings();
  }

  void resetStatus() {
    emit(state.copyWith(
      status: state.processedFiles.isEmpty
          ? LoadingStatus.idle
          : LoadingStatus.success,
      message: '',
    ));
  }

  void queueFilesForProcessing(List<String> filePaths) {
    if (state.status == LoadingStatus.loading) return;

    final existingPaths = state.processedFiles.map((f) => f.filePath).toSet();
    final duplicates =
        filePaths.where((p) => existingPaths.contains(p)).toList();

    if (duplicates.isNotEmpty) {
      _pendingFilePaths = filePaths;
      emit(state.copyWith(
        status: LoadingStatus.needsBulkConfirmation,
        duplicateFilePaths: duplicates,
      ));
    } else {
      _pendingFilePaths.addAll(filePaths);
      _processNextFile();
    }
  }

  Future<void> resolveBulkDuplicates(bool shouldUpdate) async {
    final duplicates = state.duplicateFilePaths;
    if (duplicates.isEmpty) return;

    List<String> filesToProcess;
    if (shouldUpdate) {
      filesToProcess = List.from(_pendingFilePaths);
    } else {
      final existingPaths = state.processedFiles.map((f) => f.filePath).toSet();
      filesToProcess =
          _pendingFilePaths.where((p) => !existingPaths.contains(p)).toList();
    }

    _pendingFilePaths = filesToProcess;
    emit(state.copyWith(clearDuplicates: true, status: LoadingStatus.idle));

    if (_pendingFilePaths.isNotEmpty) {
      _processNextFile();
    }
  }

  Future<void> _processNextFile() async {
    if (_pendingFilePaths.isEmpty) {
      if (state.status == LoadingStatus.loading) {
        emit(state.copyWith(
            status: LoadingStatus.success,
            message: 'Все файлы успешно обработаны!'));
      }
      return;
    }

    final path = _pendingFilePaths.first;
    final fileName = p.basename(path);

    emit(state.copyWith(
        status: LoadingStatus.loading, message: 'Обработка: $fileName'));

    try {
      final newFile = await _parseAndCreateFile(path);
      final newFileWithSelections = _applySelections(newFile);
      _pendingFilePaths.removeAt(0);

      final updatedList = List<ProcessedFile>.from(state.processedFiles);
      final existingIndex = updatedList.indexWhere((f) => f.filePath == path);

      int newActiveIndex;
      if (existingIndex != -1) {
        updatedList[existingIndex] = newFileWithSelections;
        newActiveIndex = existingIndex;
      } else {
        updatedList.add(newFileWithSelections);
        newActiveIndex = updatedList.length - 1;
      }

      emit(state.copyWith(
        processedFiles: updatedList,
        activeFileIndex: newActiveIndex,
      ));
      _processNextFile();
    } catch (e) {
      _pendingFilePaths.clear();
      emit(state.copyWith(
          status: LoadingStatus.error,
          message: 'Ошибка при обработке $fileName: $e'));
    }
  }

  Future<ProcessedFile> _parseAndCreateFile(String path) async {
    final result = await _parserService.parse(path);
    final rawHeaders = List<String>.from(result['columnNames'] ?? []);

    final uniqueHeaders = <String>[];
    final counts = <String, int>{};

    for (final header in rawHeaders) {
      if (counts.containsKey(header)) {
        counts[header] = counts[header]! + 1;
        uniqueHeaders.add('$header (${counts[header]})');
      } else {
        counts[header] = 1;
        uniqueHeaders.add(header);
      }
    }

    return ProcessedFile(
      filePath: path,
      fileName: p.basename(path),
      patternRow: List<String>.from(result['patternRow'] ?? []),
      headers: uniqueHeaders,
      dataRows: List<Map<String, dynamic>>.from(result['dataRows'] ?? []),
    );
  }

  ProcessedFile _applySelections(ProcessedFile file) {
    final headers = file.headers;
    if (headers.isEmpty) return file;

    String? nameColumn, priceColumn, quantityColumn;

    final nameIndex = _currentSettings.nameColumnIndex;
    if (nameIndex != null && nameIndex >= 0 && nameIndex < headers.length) {
      nameColumn = headers[nameIndex];
    }
    final priceIndex = _currentSettings.priceColumnIndex;
    if (priceIndex != null && priceIndex >= 0 && priceIndex < headers.length) {
      priceColumn = headers[priceIndex];
    }
    final quantityIndex = _currentSettings.quantityColumnIndex;
    if (quantityIndex != null &&
        quantityIndex >= 0 &&
        quantityIndex < headers.length) {
      quantityColumn = headers[quantityIndex];
    }

    final availableHeaders = List<String>.from(headers)
      ..remove(nameColumn)
      ..remove(priceColumn)
      ..remove(quantityColumn);

    if (nameColumn == null) {
      const nameKeywords = [
        'наименование',
        'номенклатура',
        'название',
        'товар'
      ];
      nameColumn = _findBestMatch(availableHeaders, nameKeywords);
      if (nameColumn != null) availableHeaders.remove(nameColumn);
    }
    if (priceColumn == null) {
      const priceKeywords = ['цена', 'стоимость', 'сумма'];
      priceColumn = _findBestMatch(availableHeaders, priceKeywords);
      if (priceColumn != null) availableHeaders.remove(priceColumn);
    }
    if (quantityColumn == null && state.isQuantityEnabled) {
      const quantityKeywords = ['количество', 'кол-во', 'кол', 'шт', 'qty'];
      quantityColumn = _findBestMatch(availableHeaders, quantityKeywords);
      if (quantityColumn != null) availableHeaders.remove(quantityColumn);
    }

    if (nameColumn == null && headers.isNotEmpty) nameColumn = headers[0];
    if (priceColumn == null && headers.length > 1) {
      priceColumn =
          headers.firstWhere((h) => h != nameColumn, orElse: () => headers[1]);
    }

    print(
        'Выбор колонок: Наименование -> "$nameColumn", Цена -> "$priceColumn", Количество -> "$quantityColumn"');

    return file.copyWith(
      selectedNameColumn: nameColumn,
      selectedPriceColumn: priceColumn,
      selectedQuantityColumn: state.isQuantityEnabled ? quantityColumn : null,
    );
  }

  String? _findBestMatch(List<String> headers, List<String> orderedKeywords) {
    String normalize(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[\s\-,]'), '');

    for (final keyword in orderedKeywords) {
      String? bestMatchForThisKeyword;
      int bestScore = -1;

      for (final header in headers) {
        final normalizedHeader = normalize(header);
        if (normalizedHeader.contains(keyword)) {
          final score = (keyword.length * 100) ~/ (normalizedHeader.length + 1);
          if (score > bestScore) {
            bestScore = score;
            bestMatchForThisKeyword = header;
          }
        }
      }
      if (bestMatchForThisKeyword != null) {
        return bestMatchForThisKeyword;
      }
    }
    return null;
  }

  void selectColumnsForActiveFile({
    String? nameColumn,
    String? priceColumn,
    Object? quantityColumn = #_undefined,
  }) {
    if (state.activeFile == null) return;

    final currentFile = state.activeFile!;
    final updatedFile = currentFile.copyWith(
      selectedNameColumn: nameColumn ?? currentFile.selectedNameColumn,
      selectedPriceColumn: priceColumn ?? currentFile.selectedPriceColumn,
      selectedQuantityColumn: quantityColumn == #_undefined
          ? currentFile.selectedQuantityColumn
          : quantityColumn,
    );

    final updatedList = List<ProcessedFile>.from(state.processedFiles);
    updatedList[state.activeFileIndex] = updatedFile;

    emit(state.copyWith(processedFiles: updatedList));
    _saveSettings();
  }

  void setActiveFile(String filePath) {
    final index =
        state.processedFiles.indexWhere((f) => f.filePath == filePath);
    if (index != -1) {
      emit(state.copyWith(activeFileIndex: index));
    }
  }

  void clearAll() {
    _pendingFilePaths.clear();
    emit(PdfImportState(
      hideEmptyColumns: _currentSettings.hideEmptyColumns ?? false,
      hideEmptyRows: _currentSettings.hideEmptyRows ?? false,
      isQuantityEnabled: _currentSettings.isQuantityEnabled ?? false,
    ));
  }
}
