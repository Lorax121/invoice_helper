import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager_plus_v2/window_manager_plus_v2.dart';
import '../../../core/models/overlay_item.dart';
import '../state/helper_overlay_cubit.dart';
import 'overlay_list_item.dart';
import '../../1_pdf_import_screen/state/pdf_import_cubit.dart';

enum SliderType { none, fontSize, opacity }

class HelperOverlayWindow extends StatelessWidget {
  const HelperOverlayWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HelperOverlayView();
  }
}

class _HelperOverlayView extends StatefulWidget {
  const _HelperOverlayView();
  @override
  State<_HelperOverlayView> createState() => __HelperOverlayViewState();
}

class __HelperOverlayViewState extends State<_HelperOverlayView> {
  final _multiplierController = TextEditingController(text: '1');
  final ScrollController _scrollController = ScrollController();
  Timer? _clipboardTimer;
  String _clipboardText = '';
  final GlobalKey _listItemKey = GlobalKey();
  late List<GlobalKey> _itemKeys;
  final FocusNode _focusNode = FocusNode();

  SliderType _activeSlider = SliderType.none;

  @override
  void initState() {
    super.initState();
    final itemCount = context.read<HelperOverlayCubit>().state.items.length;
    _itemKeys = List.generate(itemCount, (index) => GlobalKey());
    _startClipboardListener();
    _multiplierController.addListener(() {
      context
          .read<HelperOverlayCubit>()
          .updateMultiplier(_multiplierController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
      _setMinimumSize();
    });
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _multiplierController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setMinimumSize() {
    const double minWidth = 360.0;
    final itemBox =
        _listItemKey.currentContext?.findRenderObject() as RenderBox?;
    if (itemBox == null) {
      WindowManagerPlus.current.setMinimumSize(const Size(minWidth, 250));
      return;
    }
    const double baseHeaderHeight = 45.0; 
    const double sliderHeight = 30.0; 
    final double headerHeight = _activeSlider == SliderType.none
        ? baseHeaderHeight
        : baseHeaderHeight + sliderHeight;

    const double footerHeight = 29.0;
    final double itemHeight = itemBox.size.height;
    const double dividerHeight = 1.0;
    const double listPadding = 16.0;
    final double minHeight =
        headerHeight + itemHeight + footerHeight + dividerHeight + listPadding;
    final minSize = Size(minWidth, minHeight.ceilToDouble());
    WindowManagerPlus.current.setMinimumSize(minSize);
  }

  void _startClipboardListener() {
    _clipboardTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text != _clipboardText) {
        if (mounted) setState(() => _clipboardText = data.text!);
      }
    });
  }

  void _scrollToActive(int index) {
    if (index < 0 || index >= _itemKeys.length) return;
    if (index == 0) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    final context = _itemKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final cubit = context.read<HelperOverlayCubit>();
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        cubit.selectNextItem();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        cubit.selectPreviousItem();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HelperOverlayCubit, HelperOverlayState>(
      builder: (context, state) {
        final baseFontSize = state.baseFontSize;
        final overlayOpacity = state.overlayOpacity;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: DragToResizeArea(
              enableResizeEdges: const [
                ResizeEdge.topLeft,
                ResizeEdge.top,
                ResizeEdge.topRight,
                ResizeEdge.left,
                ResizeEdge.right,
                ResizeEdge.bottomLeft,
                ResizeEdge.bottom,
                ResizeEdge.bottomRight,
              ],
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    color: Colors.black.withOpacity(overlayOpacity),
                    child: Column(
                      children: [
                        _buildHeader(context, baseFontSize),
                        const Divider(height: 1, color: Colors.white24),
                        _buildContentList(context, baseFontSize),
                        _buildFooter(context, baseFontSize),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, double baseFontSize) {
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text('Помощник',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: baseFontSize + 2,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                SizedBox(
                  width: 120,
                  height: 35,
                  child: TextField(
                    controller: _multiplierController,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white, fontSize: baseFontSize),
                    decoration: InputDecoration(
                      labelText: 'Множитель/%',
                      labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: baseFontSize - 3),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      context.read<PdfImportCubit>().switchToMainMode(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Вернуться в главное окно',
                  splashRadius: 20,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSliderToggleButton(
                  icon: Icons.format_size,
                  type: SliderType.fontSize,
                ),
                _buildSliderToggleButton(
                  icon: Icons.opacity,
                  type: SliderType.opacity,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: _buildActiveSlider(context),
              crossFadeState: _activeSlider == SliderType.none
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderToggleButton(
      {required IconData icon, required SliderType type}) {
    final bool isActive = _activeSlider == type;
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      color: isActive ? Theme.of(context).primaryColorLight : Colors.white70,
      tooltip:
          type == SliderType.fontSize ? 'Размер шрифта' : 'Прозрачность фона',
      onPressed: () {
        setState(() {
          _activeSlider = isActive ? SliderType.none : type;
        });
      },
    );
  }

  Widget _buildActiveSlider(BuildContext context) {
    final cubit = context.read<HelperOverlayCubit>();
    switch (_activeSlider) {
      case SliderType.fontSize:
        return Slider(
          value: cubit.state.baseFontSize,
          min: 10.0,
          max: 30.0,
          divisions: 10,
          activeColor: Colors.blue.shade300,
          inactiveColor: Colors.white30,
          label: cubit.state.baseFontSize.toStringAsFixed(1),
          onChanged: (value) {
            cubit.updateFontSize(value);
          },
        );
      case SliderType.opacity:
        return Slider(
          value: cubit.state.overlayOpacity,
          min: 0.2,
          max: 1.0,
          divisions: 8,
          activeColor: Colors.blue.shade300,
          inactiveColor: Colors.white30,
          label: '${(cubit.state.overlayOpacity * 100).toInt()}%',
          onChanged: (value) {
            cubit.updateOverlayOpacity(value);
          },
        );
      case SliderType.none:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContentList(BuildContext context, double baseFontSize) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: BlocConsumer<HelperOverlayCubit, HelperOverlayState>(
          listenWhen: (p, c) => p.activeIndex != c.activeIndex,
          listener: (context, state) {
            _scrollToActive(state.activeIndex);
          },
          builder: (context, state) {
            if (state.items.isEmpty) {
              return Opacity(
                  opacity: 0,
                  child: OverlayListItem(
                    key: _listItemKey,
                    item: const OverlayItem(
                        originalName: 'dummy',
                        rawPrice: '',
                        parsedPrice: 0.0,
                        nameTokens: []),
                    index: 0,
                    isActive: false,
                    calculatedPrice: 0,
                    selectedTokens: const [],
                    baseFontSize: baseFontSize,
                  ));
            }
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 8.0,
              radius: const Radius.circular(4.0),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                    left: 8.0, top: 8.0, bottom: 8.0, right: 8.0),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return OverlayListItem(
                    key: index == 0 ? _listItemKey : _itemKeys[index],
                    item: item,
                    index: index,
                    isActive: state.activeIndex == index,
                    calculatedPrice:
                        item.parsedPrice * state.calculatedMultiplier,
                    selectedTokens:
                        state.activeIndex == index ? state.selectedTokens : [],
                    baseFontSize: baseFontSize,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, double baseFontSize) {
    return Container(
      width: double.infinity,
      color: Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'Скопировано: ${_clipboardText.replaceAll('\n', ' ')}',
        style: TextStyle(
            color: Colors.white.withOpacity(0.7), fontSize: baseFontSize - 2),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
