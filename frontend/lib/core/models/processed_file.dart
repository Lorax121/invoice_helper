
import 'package:equatable/equatable.dart';

class ProcessedFile extends Equatable {
  final String filePath;
  final String fileName;
  final List<String> headers;
  final List<String> patternRow;
  final List<Map<String, dynamic>> dataRows;
  final String? selectedNameColumn;
  final String? selectedPriceColumn;
  final String? selectedQuantityColumn; 

  const ProcessedFile({
    required this.filePath,
    required this.fileName,
    required this.headers,
    required this.patternRow,
    required this.dataRows,
    this.selectedNameColumn,
    this.selectedPriceColumn,
    this.selectedQuantityColumn, 
  });

  ProcessedFile copyWith({
    String? filePath,
    String? fileName,
    List<String>? headers,
    List<String>? patternRow,
    List<Map<String, dynamic>>? dataRows,
    Object? selectedNameColumn,
    Object? selectedPriceColumn,
    Object? selectedQuantityColumn, 
  }) {
    return ProcessedFile(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      headers: headers ?? this.headers,
      patternRow: patternRow ?? this.patternRow,
      dataRows: dataRows ?? this.dataRows,
      selectedNameColumn: selectedNameColumn == null
          ? this.selectedNameColumn
          : selectedNameColumn as String?,
      selectedPriceColumn: selectedPriceColumn == null
          ? this.selectedPriceColumn
          : selectedPriceColumn as String?,
      selectedQuantityColumn: selectedQuantityColumn == null 
          ? this.selectedQuantityColumn
          : selectedQuantityColumn as String?,
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
        selectedQuantityColumn, 
      ];
}
