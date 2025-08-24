import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager_plus_v2/window_manager_plus_v2.dart';
import '../../../core/models/overlay_item.dart';
import '../state/helper_overlay_cubit.dart';
import 'overlay_list_item.dart';

class HelperOverlayWindow extends StatelessWidget {
  final List<OverlayItem> items;
  const HelperOverlayWindow({super.key, required this.items});

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

class __HelperOverlayViewState extends State<_HelperOverlayView>
    with WindowListener {
  final _multiplierController = TextEditingController(text: '1');
  final ScrollController _scrollController = ScrollController();
  Timer? _clipboardTimer;
  String _clipboardText = '';
  final GlobalKey _listItemKey = GlobalKey();
  late List<GlobalKey> _itemKeys;
  final FocusNode _focusNode = FocusNode();

  @override
  void onWindowClose([int? windowId]) async {
    // Получаем ID главного окна (он всегда 0)
    const int mainWindowId = 0;
    try {
      // Отправляем сообщение главному окну, что оверлей закрыт
      await WindowManagerPlus.current.invokeMethodToWindow(
        mainWindowId,
        'overlay_closed', // Имя события, которое мы слушаем в PdfImportScreen
      );
    } catch (e) {
      print('Не удалось отправить сообщение о закрытии главному окну: $e');
    }
    // Вызываем super.onWindowClose в конце
    super.onWindowClose(windowId);
  }

  @override
  void initState() {
    super.initState();
    WindowManagerPlus.current.addListener(this);
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
    WindowManagerPlus.current.removeListener(this);
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
    const double headerHeight = 84.0;
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
        return DragToResizeArea(
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
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
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
    final cubit = context.read<HelperOverlayCubit>();
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 4),
        child: Column(
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
                  child: TextField(
                    controller: _multiplierController,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white, fontSize: baseFontSize),
                    decoration: InputDecoration(
                      labelText: 'Множитель/%',
                      labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: baseFontSize - 2),
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.3))),
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => WindowManagerPlus.current.destroy(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Закрыть помощник',
                  splashRadius: 20,
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.format_size,
                    color: Colors.white70, size: baseFontSize + 4),
                Expanded(
                  child: Slider(
                    value:
                        context.watch<HelperOverlayCubit>().state.baseFontSize,
                    min: 10.0,
                    max: 20.0,
                    divisions: 10,
                    activeColor: Colors.blue.shade300,
                    inactiveColor: Colors.white30,
                    label: context
                        .watch<HelperOverlayCubit>()
                        .state
                        .baseFontSize
                        .toStringAsFixed(1),
                    onChanged: (value) {
                      cubit.updateFontSize(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                        originalPrice: 0,
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
                        item.originalPrice * state.calculatedMultiplier,
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
