// lib/core/models/processed_file.dart

import 'package:equatable/equatable.dart';

class ProcessedFile extends Equatable {
  final String filePath;
  final String fileName;
  final List<String> headers;
  final List<String> patternRow;
  final List<Map<String, dynamic>> dataRows;
  final String? selectedNameColumn;
  final String? selectedPriceColumn;

  const ProcessedFile({
    required this.filePath,
    required this.fileName,
    required this.headers,
    required this.patternRow,
    required this.dataRows,
    this.selectedNameColumn,
    this.selectedPriceColumn,
  });

  // ИЗМЕНЕНИЕ: Добавьте этот метод, если его у вас нет.
  // Он необходим для создания копии объекта с измененными полями.
  ProcessedFile copyWith({
    String? filePath,
    String? fileName,
    List<String>? headers,
    List<String>? patternRow,
    List<Map<String, dynamic>>? dataRows,
    // Используем 'Object?' как трюк, чтобы можно было передать null
    Object? selectedNameColumn,
    Object? selectedPriceColumn,
  }) {
    return ProcessedFile(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      headers: headers ?? this.headers,
      patternRow: patternRow ?? this.patternRow,
      dataRows: dataRows ?? this.dataRows,
      // Проверяем, был ли аргумент передан, чтобы можно было установить null
      selectedNameColumn: selectedNameColumn == null
          ? this.selectedNameColumn
          : selectedNameColumn as String?,
      selectedPriceColumn: selectedPriceColumn == null
          ? this.selectedPriceColumn
          : selectedPriceColumn as String?,
    );
  }

  @override
  List<Object?> get props => [
        filePath,
        fileName,
        headers,
        patternRow,
        dataRows,
        selectedNameColumn,
        selectedPriceColumn,
      ];
}
