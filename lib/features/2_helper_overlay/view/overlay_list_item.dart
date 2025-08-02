import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../model/overlay_item.dart';
import '../state/helper_overlay_cubit.dart';
import 'token_chip.dart';

class OverlayListItem extends StatelessWidget {
  final OverlayItem item;
  final int index;
  final bool isActive;
  final double calculatedPrice;
  final List<String> selectedTokens;

  const OverlayListItem({
    super.key,
    required this.item,
    required this.index,
    required this.isActive,
    required this.calculatedPrice,
    required this.selectedTokens,
  });

  static const double twoLinesTextHeight = 34.0;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameSection(context, cubit),
            const SizedBox(height: 6),
            _buildPriceSection(context, cubit),
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
            constraints: const BoxConstraints(minHeight: twoLinesTextHeight),
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
                      );
                    }).toList(),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.originalName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
        ),
      ],
    );
  }

  Widget _buildPriceSection(BuildContext context, HelperOverlayCubit cubit) {
    final priceString = calculatedPrice.toStringAsFixed(2);
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () => cubit.copyPrice(),
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: 'Нажмите, чтобы скопировать цену',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${priceString} ₽',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
