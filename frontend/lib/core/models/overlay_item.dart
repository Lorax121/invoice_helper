import 'package:equatable/equatable.dart';

class OverlayItem extends Equatable {
  final String originalName;
  final double originalPrice;
  final double? originalQuantity; 

  final List<String> nameTokens;

  const OverlayItem({
    required this.originalName,
    required this.originalPrice,
    required this.nameTokens,
    this.originalQuantity, 
  });

  factory OverlayItem.fromTableRow(
    Map<String, dynamic> row,
    String nameColumn,
    String? priceColumn,
    String? quantityColumn, 
  ) {
    final name = row[nameColumn]?.toString() ?? 'N/A';
    final tokens = name.split(' ').where((s) => s.isNotEmpty).toList();

    final priceStr =
        priceColumn != null ? row[priceColumn]?.toString() ?? '0' : '0';
    final price =
        double.tryParse(priceStr.replaceAll(',', '.').replaceAll(' ', '')) ??
            0.0;

    double? quantity;
    if (quantityColumn != null) {
      final quantityStr = row[quantityColumn]?.toString();
      if (quantityStr != null && quantityStr.trim().isNotEmpty) {
        quantity = double.tryParse(
            quantityStr.replaceAll(',', '.').replaceAll(' ', ''));
      }
    }

    return OverlayItem(
      originalName: name,
      originalPrice: price,
      nameTokens: tokens,
      originalQuantity: quantity, 
    );
  }

  @override
  List<Object?> get props => [
        originalName,
        originalPrice,
        originalQuantity, 
      ];
}
