import 'package:equatable/equatable.dart';

class OverlayItem extends Equatable {
  final String originalName;
  final double originalPrice;

  final List<String> nameTokens;

  const OverlayItem({
    required this.originalName,
    required this.originalPrice,
    required this.nameTokens,
  });

  factory OverlayItem.fromTableRow(
      Map<String, dynamic> row, String nameColumn, String? priceColumn) {
    final name = row[nameColumn]?.toString() ?? 'N/A';
    final priceStr =
        priceColumn != null ? row[priceColumn]?.toString() ?? '0' : '0';
    final price = double.tryParse(priceStr.replaceAll(',', '.')) ?? 0.0;

    final tokens = name.split(' ').where((s) => s.isNotEmpty).toList();

    return OverlayItem(
      originalName: name,
      originalPrice: price,
      nameTokens: tokens,
    );
  }

  @override
  List<Object?> get props => [originalName, originalPrice];
}
