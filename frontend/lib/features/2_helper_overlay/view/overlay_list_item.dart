import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/overlay_item.dart';
import '../state/helper_overlay_cubit.dart';
import 'token_chip.dart';

class OverlayListItem extends StatelessWidget {
  final OverlayItem item;
  final int index;
  final bool isActive;
  final double calculatedPrice;
  final List<String> selectedTokens;
  final double baseFontSize;

  const OverlayListItem({
    super.key,
    required this.item,
    required this.index,
    required this.isActive,
    required this.calculatedPrice,
    required this.selectedTokens,
    required this.baseFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HelperOverlayCubit>();

    return InkWell(
      onTap: () => cubit.setActiveIndex(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: Theme.of(context).primaryColorLight, width: 2)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildNameSection(context, cubit),
            ),
            const SizedBox(width: 8),
            _buildDataSection(context, cubit),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection(BuildContext context, HelperOverlayCubit cubit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: baseFontSize * 2.4),
            child: isActive
                ? Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.start,
                    children: item.nameTokens.map((token) {
                      return TokenChip(
                        text: token,
                        isSelected: selectedTokens.contains(token),
                        onTap: () => cubit.toggleNameToken(token),
                        baseFontSize: baseFontSize,
                      );
                    }).toList(),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.originalName,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: baseFontSize,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
        ),
        IconButton(
          onPressed: () => cubit.copyFullName(),
          icon: const Icon(Icons.copy_all_outlined, color: Colors.white70),
          tooltip: 'Копировать полное наименование',
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, HelperOverlayCubit cubit) {
    final priceString = calculatedPrice.toStringAsFixed(2);

    String? quantityString;
    if (item.originalQuantity != null) {
      final quantity = item.originalQuantity!;
      quantityString = quantity.truncateToDouble() == quantity
          ? quantity.toInt().toString()
          : quantity.toString();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (quantityString != null)
          _buildDataRow(
            context: context,
            label: Text(
              'кол-во',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: baseFontSize - 1,
              ),
            ),
            value: quantityString,
            tooltip: 'Нажмите, чтобы скопировать количество',
            onTap: () => cubit.copyQuantity(),
          ),
        if (quantityString != null) const SizedBox(height: 4),
        _buildDataRow(
          context: context,
          label: Text(
            '₽',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: baseFontSize + 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          value: priceString,
          tooltip: 'Нажмите, чтобы скопировать цену',
          onTap: () => cubit.copyPrice(),
        ),
      ],
    );
  }

  Widget _buildDataRow({
    required BuildContext context,
    required Widget label,
    required String value,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        const SizedBox(width: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: baseFontSize + 1,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
