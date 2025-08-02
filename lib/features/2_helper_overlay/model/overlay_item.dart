import 'package:equatable/equatable.dart';

class OverlayItem extends Equatable {
  // Исходные данные
  final String originalName;
  final double originalPrice;

  // Токены для "умного" копирования
  final List<String> nameTokens;

  const OverlayItem({
    required this.originalName,
    required this.originalPrice,
    required this.nameTokens,
  });

  // Создаем элемент из строки в таблице
  factory OverlayItem.fromTableRow(
      Map<String, dynamic> row, String nameColumn, String? priceColumn) {
    final name = row[nameColumn]?.toString() ?? 'N/A';
    final priceStr =
        priceColumn != null ? row[priceColumn]?.toString() ?? '0' : '0';
    // Пытаемся распарсить цену, заменяя запятые на точки
    final price = double.tryParse(priceStr.replaceAll(',', '.')) ?? 0.0;

    // Разбиваем название на токены по пробелам, убирая пустые
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
