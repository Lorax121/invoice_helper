import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/overlay_item.dart';
import '../../../core/services/settings_service.dart';

class HelperOverlayState extends Equatable {
  final List<OverlayItem> items;
  final int activeIndex;
  final String multiplierText;
  final double calculatedMultiplier;
  final List<String> selectedTokens;
  final double baseFontSize;
  final double overlayOpacity;

  const HelperOverlayState({
    this.items = const [],
    this.activeIndex = -1,
    this.multiplierText = '1',
    this.calculatedMultiplier = 1.0,
    this.selectedTokens = const [],
    this.baseFontSize = 14.0,
    this.overlayOpacity = 0.8,
  });

  OverlayItem? get activeItem => activeIndex != -1 ? items[activeIndex] : null;

  HelperOverlayState copyWith({
    List<OverlayItem>? items,
    int? activeIndex,
    String? multiplierText,
    double? calculatedMultiplier,
    List<String>? selectedTokens,
    bool? resetTokens,
    double? baseFontSize,
    double? overlayOpacity,
  }) {
    return HelperOverlayState(
      items: items ?? this.items,
      activeIndex: activeIndex ?? this.activeIndex,
      multiplierText: multiplierText ?? this.multiplierText,
      calculatedMultiplier: calculatedMultiplier ?? this.calculatedMultiplier,
      selectedTokens:
          resetTokens == true ? [] : (selectedTokens ?? this.selectedTokens),
      baseFontSize: baseFontSize ?? this.baseFontSize,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
    );
  }

  @override
  List<Object?> get props => [
        items,
        activeIndex,
        multiplierText,
        calculatedMultiplier,
        selectedTokens,
        baseFontSize,
        overlayOpacity,
      ];
}

class HelperOverlayCubit extends Cubit<HelperOverlayState> {
  final SettingsService _settingsService;
  AppSettings _currentSettings;

  HelperOverlayCubit(
    List<OverlayItem> initialItems,
    this._settingsService,
    AppSettings initialSettings,
  )   : _currentSettings = initialSettings,
        super(HelperOverlayState(
          items: initialItems,
          activeIndex: initialItems.isNotEmpty ? 0 : -1,
          baseFontSize: initialSettings.overlayFontSize ?? 14.0,
          overlayOpacity:
              initialSettings.overlayOpacity ?? 0.8, 
        ));

  Future<void> _saveSettings() async {
    _currentSettings = _currentSettings.copyWith(
      overlayFontSize: state.baseFontSize,
      overlayOpacity: state.overlayOpacity, 
    );
    await _settingsService.saveSettings(_currentSettings);
  }

  void updateOverlayOpacity(double newOpacity) {
    final clampedOpacity = newOpacity.clamp(0.2, 1.0); 
    emit(state.copyWith(overlayOpacity: clampedOpacity));
    _saveSettings();
  }

  void setActiveIndex(int index) {
    if (index != state.activeIndex) {
      emit(state.copyWith(activeIndex: index, resetTokens: true));
    }
  }

  void updateItems(List<OverlayItem> newItems) {
    emit(state.copyWith(
      items: newItems,
      activeIndex: newItems.isNotEmpty ? 0 : -1,
      resetTokens: true,
    ));
  }

  void copyRawPrice() {
    if (state.activeItem != null) {
      Clipboard.setData(ClipboardData(text: state.activeItem!.rawPrice));
      emit(state.copyWith(selectedTokens: []));
    }
  }

  void updateMultiplier(String text) {
    double multiplier = 1.0;
    final cleanText = text.trim().replaceAll(',', '.');
    if (cleanText.endsWith('%')) {
      final value = double.tryParse(cleanText.replaceAll('%', ''));
      if (value != null) {
        multiplier = 1.0 + (value / 100.0);
      }
    } else {
      multiplier = double.tryParse(cleanText) ?? 1.0;
    }
    emit(
        state.copyWith(multiplierText: text, calculatedMultiplier: multiplier));
  }

  void toggleNameToken(String token) {
    final currentTokens = List<String>.from(state.selectedTokens);
    if (currentTokens.contains(token)) {
      currentTokens.remove(token);
    } else {
      currentTokens.add(token);
    }
    final clipboardText = currentTokens.join(' ');
    Clipboard.setData(ClipboardData(text: clipboardText));
    emit(state.copyWith(selectedTokens: currentTokens));
  }

  void copyFullName() {
    if (state.activeItem != null) {
      Clipboard.setData(ClipboardData(text: state.activeItem!.originalName));
      emit(state.copyWith(selectedTokens: []));
    }
  }

  void copyQuantity() {
    if (state.activeItem?.originalQuantity != null) {
      final quantity = state.activeItem!.originalQuantity!;
      final quantityString = quantity.truncateToDouble() == quantity
          ? quantity.toInt().toString()
          : quantity.toString();
      Clipboard.setData(ClipboardData(text: quantityString));
      emit(state.copyWith(selectedTokens: []));
    }
  }

  void copyPrice() {
    if (state.activeItem != null) {
      final finalPrice =
          state.activeItem!.parsedPrice * state.calculatedMultiplier;
      final priceString = finalPrice.toStringAsFixed(2);
      Clipboard.setData(ClipboardData(text: priceString));
      emit(state.copyWith(selectedTokens: []));
    }
  }

  void updateFontSize(double newSize) {
    final clampedSize = newSize.clamp(10.0, 30.0);
    emit(state.copyWith(baseFontSize: clampedSize));
    _saveSettings();
  }

  void selectNextItem() {
    if (state.items.isEmpty || state.activeIndex >= state.items.length - 1) {
      return;
    }
    setActiveIndex(state.activeIndex + 1);
  }

  void selectPreviousItem() {
    if (state.items.isEmpty || state.activeIndex <= 0) {
      return;
    }
    setActiveIndex(state.activeIndex - 1);
  }
}
