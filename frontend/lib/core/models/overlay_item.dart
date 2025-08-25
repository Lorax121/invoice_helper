import 'package:equatable/equatable.dart';

class OverlayItem extends Equatable {
  final String originalName;
  final String rawPrice; 
  final double parsedPrice; 
  final double? originalQuantity;
  final List<String> nameTokens;

  const OverlayItem({
    required this.originalName,
    required this.rawPrice,
    required this.parsedPrice,
    this.originalQuantity,
    required this.nameTokens,
  });

  factory OverlayItem.fromTableRow(
    Map<String, dynamic> row,
    String nameCol,
    String? priceCol,
    String? quantityCol,
  ) {
    final name = row[nameCol]?.toString() ?? '';
    final tokens = name.split(' ').where((s) => s.isNotEmpty).toList();

    final rawPriceString =
        priceCol != null ? row[priceCol]?.toString() ?? '' : '';
    double parsedPriceValue = 0.0;
    if (rawPriceString.isNotEmpty) {
      final cleanPriceString =
          rawPriceString.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
      parsedPriceValue = double.tryParse(cleanPriceString) ?? 0.0;
    }

    double? quantity;
    if (quantityCol != null) {
      final rawQuantity = row[quantityCol]?.toString() ?? '';
      if (rawQuantity.isNotEmpty) {
        final cleanQuantity =
            rawQuantity.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
        quantity = double.tryParse(cleanQuantity);
      }
    }

    return OverlayItem(
      originalName: name,
      nameTokens: tokens,
      rawPrice: rawPriceString,
      parsedPrice: parsedPriceValue,
      originalQuantity: quantity,
    );
  }

  @override
  List<Object?> get props =>
      [originalName, rawPrice, parsedPrice, originalQuantity, nameTokens];
}
