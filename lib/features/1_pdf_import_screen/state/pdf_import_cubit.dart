import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/processed_file.dart';
import '../../../core/services/pdf_parser_service.dart';

enum LoadingStatus { idle, loading, needsConfirmation, success, error }

class PdfImportState extends Equatable {
  final List<ProcessedFile> processedFiles;
  final int activeFileIndex;
  final LoadingStatus status;
  final String message;
  final String? duplicateFilePath;
  final String? duplicateFileName;
  final int? overlayWindowId;

  const PdfImportState({
    this.processedFiles = const [],
    this.activeFileIndex = -1,
    this.status = LoadingStatus.idle,
    this.message = '',
    this.overlayWindowId,
    this.duplicateFilePath,
    this.duplicateFileName,
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
    dynamic duplicateFilePath = #_undefined,
    dynamic duplicateFileName = #_undefined,
    int? overlayWindowId,
    bool clearOverlayId = false,
  }) {
    return PdfImportState(
      processedFiles: processedFiles ?? this.processedFiles,
      activeFileIndex: activeFileIndex ?? this.activeFileIndex,
      status: status ?? this.status,
      message: message ?? this.message,
      duplicateFilePath: duplicateFilePath == #_undefined
          ? this.duplicateFilePath
          : duplicateFilePath as String?,
      duplicateFileName: duplicateFileName == #_undefined
          ? this.duplicateFileName
          : duplicateFileName as String?,
      overlayWindowId:
          clearOverlayId ? null : (overlayWindowId ?? this.overlayWindowId),
    );
  }

  @override
  List<Object?> get props => [
        processedFiles,
        activeFileIndex,
        status,
        message,
        duplicateFilePath,
        duplicateFileName,
        overlayWindowId,
      ];
}

class PdfImportCubit extends Cubit<PdfImportState> {
  final PdfParserService _parserService;
  List<String> _pendingFilePaths = [];

  PdfImportCubit(this._parserService) : super(const PdfImportState());

  void setOverlayId(int windowId) {
    emit(state.copyWith(overlayWindowId: windowId));
  }

  void clearOverlayId() {
    emit(state.copyWith(clearOverlayId: true));
  }

  void queueFilesForProcessing(List<String> filePaths) {
    if (state.status == LoadingStatus.loading) return;
    _pendingFilePaths.addAll(filePaths);
    _processNextFile();
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

    if (state.processedFiles.any((file) => file.filePath == path)) {
      emit(state.copyWith(
        status: LoadingStatus.needsConfirmation,
        duplicateFilePath: path,
        duplicateFileName: fileName,
      ));
      return;
    }

    emit(state.copyWith(
        status: LoadingStatus.loading, message: 'Обработка: $fileName'));

    try {
      final newFile = await _parseAndCreateFile(path);

      final newFileWithAutoSelect = _autoSelectColumns(newFile);

      _pendingFilePaths.removeAt(0);
      final updatedList = List<ProcessedFile>.from(state.processedFiles)
        ..add(newFileWithAutoSelect);

      emit(state.copyWith(
        processedFiles: updatedList,
        activeFileIndex: updatedList.length - 1,
      ));
      _processNextFile();
    } catch (e) {
      _pendingFilePaths.clear();
      emit(state.copyWith(
          status: LoadingStatus.error,
          message: 'Ошибка при обработке $fileName: $e'));
    }
  }

  Future<void> resolveDuplicate(bool shouldUpdate) async {
    final path = state.duplicateFilePath;
    if (path == null) return;

    _pendingFilePaths.removeAt(0);

    if (shouldUpdate) {
      emit(state.copyWith(
        status: LoadingStatus.loading,
        message: 'Обновление: ${state.duplicateFileName}',
        duplicateFilePath: null,
        duplicateFileName: null,
      ));
      try {
        final updatedFileRaw = await _parseAndCreateFile(path);
        final updatedFile = _autoSelectColumns(updatedFileRaw);

        final list = List<ProcessedFile>.from(state.processedFiles);
        final index = list.indexWhere((f) => f.filePath == path);
        if (index != -1) {
          list[index] = updatedFile;
        }
        emit(state.copyWith(processedFiles: list, activeFileIndex: index));
      } catch (e) {
        _pendingFilePaths.clear();
        emit(state.copyWith(
            status: LoadingStatus.error, message: 'Ошибка при обновлении: $e'));
        return;
      }
    } else {
      emit(state.copyWith(
          status: LoadingStatus.idle,
          duplicateFilePath: null,
          duplicateFileName: null));
    }

    _processNextFile();
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

  ProcessedFile _autoSelectColumns(ProcessedFile file) {
    final headers = file.headers;
    if (headers.isEmpty) return file;

    const nameKeywords = [
      'наименование',
      'номенклатура',
      'название',
      'товар',
      'продукция'
    ];
    const priceKeywords = ['цена', 'стоимость', 'сумма'];

    String? nameColumn = _findBestMatch(headers, nameKeywords);

    final remainingHeaders = nameColumn != null
        ? headers.where((h) => h != nameColumn).toList()
        : headers;
    String? priceColumn = _findBestMatch(remainingHeaders, priceKeywords);

    if (nameColumn == null && headers.isNotEmpty) {
      nameColumn = headers[0];
    }

    if (priceColumn == null && headers.length > 1) {
      priceColumn = headers[1] != nameColumn ? headers[1] : null;
    } else if (priceColumn == null && headers.length <= 1) {
      priceColumn = null;
    }

    print('Авто-выбор: Наименование -> "$nameColumn", Цена -> "$priceColumn"');

    return file.copyWith(
      selectedNameColumn: nameColumn,
      selectedPriceColumn: priceColumn,
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

  void selectColumnsForActiveFile({String? nameColumn, String? priceColumn}) {
    if (state.activeFile == null) return;

    final currentFile = state.activeFile!;

    late final ProcessedFile updatedFile;

    if (nameColumn != null) {
      updatedFile = currentFile.copyWith(selectedNameColumn: nameColumn);
    } else {
      updatedFile = currentFile.copyWith(selectedPriceColumn: priceColumn);
    }

    final updatedList = List<ProcessedFile>.from(state.processedFiles);
    updatedList[state.activeFileIndex] = updatedFile;

    emit(state.copyWith(processedFiles: updatedList));
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
    emit(const PdfImportState());
  }
}
