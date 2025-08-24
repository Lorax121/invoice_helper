import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_table_view/material_table_view.dart';
import 'package:window_manager_plus_v2/window_manager_plus_v2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/models/processed_file.dart';
import '../state/pdf_import_cubit.dart';
import '../widgets/drag_and_drop_area.dart';
import 'column_selector_widget.dart';
import '../../../core/services/settings_service.dart';

class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> with WindowListener {
  @override
  void initState() {
    super.initState();
    WindowManagerPlus.current.addListener(this);
  }

  @override
  void dispose() {
    WindowManagerPlus.current.removeListener(this);
    super.dispose();
  }

  @override
  Future onEventFromWindow(
      String eventName, int fromWindowId, dynamic arguments) async {
    if (!mounted) return;
    final cubit = context.read<PdfImportCubit>();
    if (eventName == 'overlay_closed' &&
        fromWindowId == cubit.state.overlayWindowId) {
      print(
          'Главное окно: Получено сообщение, что оверлей ($fromWindowId) закрыт. Сбрасываем ID.');
      cubit.clearOverlayId();
    }
  }

  @override
  void onWindowClose([int? windowId]) async {
    final overlayId = context.read<PdfImportCubit>().state.overlayWindowId;
    if (overlayId != null) {
      try {
        final overlayWindow = WindowManagerPlus.fromWindowId(overlayId);
        await overlayWindow.destroy();
      } catch (e) {
        print("Не удалось закрыть оверлей при выходе: $e");
      }
    }
    super.onWindowClose(windowId);
  }

  Future<void> _pickAndAddFiles(BuildContext context) async {
    final cubit = context.read<PdfImportCubit>();
    final selectedCore = cubit.state.selectedCore;

    final List<String> allowedExtensions;
    if (selectedCore == ParsingCore.camelot) {
      allowedExtensions = ['pdf'];
    } else {
      allowedExtensions = const ['pdf', 'png', 'jpg', 'jpeg', 'bmp', 'tiff'];
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
    );
    if (result != null && result.paths.isNotEmpty) {
      if (!mounted) return;
      cubit.queueFilesForProcessing(result.paths.whereType<String>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Помощник обработки накладных'),
        actions: [
          const _CoreSelector(), // <-- ДОБАВЛЕН ПЕРЕКЛЮЧАТЕЛЬ
          BlocBuilder<PdfImportCubit, PdfImportState>(
            builder: (context, state) {
              if (state.processedFiles.isNotEmpty &&
                  state.status != LoadingStatus.loading) {
                return TextButton.icon(
                  onPressed: () => _pickAndAddFiles(context),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Добавить'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          BlocBuilder<PdfImportCubit, PdfImportState>(
            builder: (context, state) {
              if (state.processedFiles.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Очистить все',
                  onPressed: () => context.read<PdfImportCubit>().clearAll(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocConsumer<PdfImportCubit, PdfImportState>(
            listenWhen: (p, c) =>
                p.status != c.status &&
                c.status == LoadingStatus.needsBulkConfirmation,
            listener: (context, state) {
              if (state.duplicateFilePaths.isNotEmpty) {
                _showBulkUpdateDialog(context, state.duplicateFilePaths);
              }
            },
            builder: (context, state) {
              if (state.processedFiles.isEmpty) {
                return const _InitialView();
              }
              return _SuccessView(state: state);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showBulkUpdateDialog(
      BuildContext context, List<String> filePaths) async {
    final cubit = context.read<PdfImportCubit>();
    final fileNames =
        filePaths.map((p) => p.split(Platform.pathSeparator).last).join('\n');
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Найдены уже обработанные файлы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Следующие файлы уже были добавлены:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4)),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Text(fileNames),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
                'Хотите обновить их данные? Новые файлы будут добавлены в любом случае.')
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет, пропустить эти')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Да, обновить')),
        ],
      ),
    );
    cubit.resolveBulkDuplicates(result ?? false);
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PdfImportCubit>().state;
    switch (state.status) {
      case LoadingStatus.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(state.message)
            ],
          ),
        );
      case LoadingStatus.error:
        return _ErrorView(
          message: 'Не удалось обработать файл.',
          details: state.message,
          onRetry: () => context.read<PdfImportCubit>().resetStatus(),
        );
      default:
        return const FileImportArea();
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String details;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.red.shade900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('Показать детали'),
                children: [
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: Text(
                          details,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Понятно, попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatefulWidget {
  final PdfImportState state;
  const _SuccessView({required this.state});

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> {
  bool _isDragging = false;

  void _processFiles(List<String> paths) {
    final cubit = context.read<PdfImportCubit>();
    final selectedCore = cubit.state.selectedCore;

    final List<String> allowedExtensions;
    if (selectedCore == ParsingCore.camelot) {
      allowedExtensions = ['pdf'];
    } else {
      allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'bmp', 'tiff'];
    }

    final validPaths = paths.where((p) {
      final ext = p.split('.').last.toLowerCase();
      return allowedExtensions.contains(ext);
    }).toList();

    if (validPaths.isNotEmpty) {
      cubit.queueFilesForProcessing(validPaths);
    }
  }

  void _launchOrFocusOverlay(BuildContext context) async {
    final cubit = context.read<PdfImportCubit>();
    final ProcessedFile? activeFile = widget.state.activeFile;

    if (activeFile == null || activeFile.selectedNameColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ошибка: Не выбрана колонка для наименования.'),
          backgroundColor: Colors.red));
      return;
    }

    final currentOverlayId = widget.state.overlayWindowId;

    if (currentOverlayId != null) {
      final allWindowIds = await WindowManagerPlus.getAllWindowManagerIds();
      if (allWindowIds.contains(currentOverlayId)) {
        final existingWindow = WindowManagerPlus.fromWindowId(currentOverlayId);
        await existingWindow.focus();
        return;
      } else {
        cubit.clearOverlayId();
      }
    }

    try {
      final rowsToProcess = widget.state.hideEmptyRows
          ? activeFile.dataRows.where((row) {
              return row.values
                  .any((value) => (value?.toString() ?? '').isNotEmpty);
            }).toList()
          : activeFile.dataRows;

      final dataForOverlay = rowsToProcess.map((row) {
        return {
          ...row,
          '__name_col': activeFile.selectedNameColumn,
          '__price_col': activeFile.selectedPriceColumn,
          '__quantity_col': activeFile.selectedQuantityColumn
        };
      }).toList();

      final String argsJson = jsonEncode(dataForOverlay);
      final newWindow = await WindowManagerPlus.createWindow([argsJson]);

      if (newWindow != null) {
        cubit.setOverlayId(newWindow.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось создать окно оверлея.'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Критическая ошибка: $e'),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PdfImportCubit>();
    final ProcessedFile? activeFile = widget.state.activeFile;
    if (activeFile == null) {
      return const Center(child: Text('Нет активного файла.'));
    }

    final List<String> filteredHeaders;
    if (widget.state.hideEmptyColumns) {
      filteredHeaders = activeFile.headers.where((header) {
        return activeFile.dataRows
            .any((row) => (row[header]?.toString() ?? '').isNotEmpty);
      }).toList();
    } else {
      filteredHeaders = activeFile.headers;
    }

    final List<Map<String, dynamic>> filteredDataRows;
    if (widget.state.hideEmptyRows) {
      filteredDataRows = activeFile.dataRows.where((row) {
        return row.values.any((value) => (value?.toString() ?? '').isNotEmpty);
      }).toList();
    } else {
      filteredDataRows = activeFile.dataRows;
    }

    return DropTarget(
      onDragDone: (details) {
        setState(() => _isDragging = false);
        _processFiles(details.files.map((f) => f.path).toList());
      },
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const double controlsHeight = 200;
              final double availableHeight =
                  constraints.maxHeight - controlsHeight;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFileSelector(activeFile, cubit, widget.state),
                  const SizedBox(height: 12),
                  _ColumnSelectorsWrapper(
                      activeFile: activeFile,
                      cubit: cubit,
                      onLaunchOverlay: () => _launchOrFocusOverlay(context)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: availableHeight > 200 ? availableHeight : 200,
                    child: _TableViewWidget(
                      key: ValueKey(
                          '${activeFile.filePath}_${widget.state.hideEmptyColumns}_${widget.state.hideEmptyRows}'),
                      activeFile: activeFile,
                      filteredHeaders: filteredHeaders,
                      filteredDataRows: filteredDataRows,
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: (widget.state.status == LoadingStatus.loading)
                            ? Row(key: const ValueKey('loading'), children: [
                                const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(widget.state.message))
                              ])
                            : Text(widget.state.message,
                                key: ValueKey(widget.state.message),
                                style: TextStyle(
                                    color: widget.state.status ==
                                            LoadingStatus.error
                                        ? Colors.red
                                        : Colors.green)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 60, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Отпустите, чтобы добавить файлы',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileSelector(
      ProcessedFile activeFile, PdfImportCubit cubit, PdfImportState state) {
    return Row(
      children: [
        const Text('Файл: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: DropdownButton<String>(
            value: activeFile.filePath,
            isExpanded: true,
            isDense: true,
            items: state.processedFiles.map((file) {
              return DropdownMenuItem(
                  value: file.filePath,
                  child: Text(file.fileName, overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: state.status == LoadingStatus.loading
                ? null
                : (filePath) {
                    if (filePath != null) {
                      cubit.setActiveFile(filePath);
                    }
                  },
          ),
        ),
      ],
    );
  }
}

class _ColumnSelectorsWrapper extends StatelessWidget {
  final ProcessedFile activeFile;
  final PdfImportCubit cubit;
  final VoidCallback onLaunchOverlay;

  const _ColumnSelectorsWrapper({
    required this.activeFile,
    required this.cubit,
    required this.onLaunchOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PdfImportCubit>().state;
    final isQuantityEnabled = state.isQuantityEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: ColumnSelector(
                label: 'Наименование:',
                columns: activeFile.headers,
                selectedValue: activeFile.selectedNameColumn,
                onChanged: (newValue) =>
                    cubit.selectColumnsForActiveFile(nameColumn: newValue),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ColumnSelector(
                label: 'Цена:',
                columns: activeFile.headers,
                selectedValue: activeFile.selectedPriceColumn,
                onChanged: (newValue) =>
                    cubit.selectColumnsForActiveFile(priceColumn: newValue),
              ),
            ),
            const SizedBox(width: 16),
            if (isQuantityEnabled)
              Expanded(
                flex: 2,
                child: ColumnSelector(
                  label: 'Количество:',
                  columns: activeFile.headers,
                  selectedValue: activeFile.selectedQuantityColumn,
                  onChanged: (newValue) => cubit.selectColumnsForActiveFile(
                      quantityColumn: newValue),
                ),
              ),
            if (!isQuantityEnabled) const Spacer(flex: 2),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (activeFile.selectedNameColumn != null)
                    ? onLaunchOverlay
                    : null,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Оверлей'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Новая строка для всех чекбоксов
        Row(
          children: [
            _buildCheckbox(
              'Скрыть пустые столбцы',
              state.hideEmptyColumns,
              () => cubit.toggleHideEmptyColumns(),
            ),
            const SizedBox(width: 16),
            _buildCheckbox(
              'Скрыть пустые строки',
              state.hideEmptyRows,
              () => cubit.toggleHideEmptyRows(),
            ),
            const SizedBox(width: 16),
            _buildCheckbox(
              'Включить "Кол-во"',
              isQuantityEnabled,
              () => cubit.toggleIsQuantityEnabled(!isQuantityEnabled),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, VoidCallback onTap) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (_) => onTap(),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        InkWell(
          onTap: onTap,
          child: Text(label),
        ),
      ],
    );
  }
}

class _IgnoreManualScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const NeverScrollableScrollPhysics();
}

class _TableViewWidget extends StatefulWidget {
  final ProcessedFile activeFile;
  final List<String> filteredHeaders;
  final List<Map<String, dynamic>> filteredDataRows;

  const _TableViewWidget({
    super.key,
    required this.activeFile,
    required this.filteredHeaders,
    required this.filteredDataRows,
  });

  @override
  State<_TableViewWidget> createState() => _TableViewWidgetState();
}

class _TableViewWidgetState extends State<_TableViewWidget> {
  late final TableViewController _tableViewController;
  ScrollController? _horizontalScrollController;
  ScrollController? _verticalScrollController;
  bool _isHoveringFrozenArea = false;
  final List<double> _columnWidths = [];

  @override
  void initState() {
    super.initState();
    _tableViewController = TableViewController();
    _horizontalScrollController =
        _tableViewController.horizontalScrollController;
    _verticalScrollController = _tableViewController.verticalScrollController;
    _calculateColumnWidths();
  }

  @override
  void didUpdateWidget(_TableViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filteredHeaders != widget.filteredHeaders ||
        oldWidget.filteredDataRows != widget.filteredDataRows) {
      _calculateColumnWidths();
    }
  }

  @override
  void dispose() {
    _tableViewController.dispose();
    super.dispose();
  }

  void _calculateColumnWidths() {
    _columnWidths.clear();
    if (widget.filteredHeaders.isEmpty) return;

    for (int i = 0; i < widget.filteredHeaders.length; i++) {
      final header = widget.filteredHeaders[i];
      double baseWidth = 120;

      if (i == 0) {
        baseWidth = 80;
      } else if (i == widget.filteredHeaders.length - 1) {
        baseWidth = 140;
      } else if (header == widget.activeFile.selectedNameColumn) {
        baseWidth = 200;
      } else if (header == widget.activeFile.selectedPriceColumn) {
        baseWidth = 120;
      } else if (header == widget.activeFile.selectedQuantityColumn) {
        baseWidth = 100;
      }

      int maxLength = header.length;
      final sampleSize = widget.filteredDataRows.length > 20
          ? 20
          : widget.filteredDataRows.length;

      for (int j = 0; j < sampleSize; j++) {
        final cellValue = widget.filteredDataRows[j][header]?.toString() ?? '';
        if (cellValue.length > maxLength) {
          maxLength = cellValue.length;
        }
      }

      final calculatedWidth = (maxLength * 8.0).clamp(baseWidth, 300.0);
      _columnWidths.add(calculatedWidth);
    }
  }

  double _getLeftFrozenWidth() {
    return _columnWidths.isNotEmpty ? _columnWidths[0] : 80;
  }

  double _getRightFrozenWidth() {
    if (_columnWidths.length < 2) return 0;
    return _columnWidths.last;
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(event.position);
    final tableWidth = renderBox.size.width;

    final leftFrozenWidth = _getLeftFrozenWidth();
    final rightFrozenWidth = _getRightFrozenWidth();

    final isInLeftFrozenArea = localPosition.dx <= leftFrozenWidth;
    final isInRightFrozenArea =
        localPosition.dx >= (tableWidth - rightFrozenWidth);
    final isInFrozenArea = isInLeftFrozenArea || isInRightFrozenArea;

    if (isInFrozenArea) {
      if (_verticalScrollController != null &&
          _verticalScrollController!.hasClients) {
        final delta = event.scrollDelta.dy;
        final currentOffset = _verticalScrollController!.offset;
        final maxOffset = _verticalScrollController!.position.maxScrollExtent;
        final newOffset = (currentOffset + delta).clamp(0.0, maxOffset);
        _verticalScrollController!.jumpTo(newOffset);
      }
    } else {
      if (_horizontalScrollController != null &&
          _horizontalScrollController!.hasClients) {
        final delta = event.scrollDelta.dy;
        final currentOffset = _horizontalScrollController!.offset;
        final maxOffset = _horizontalScrollController!.position.maxScrollExtent;
        final newOffset = (currentOffset + delta).clamp(0.0, maxOffset);
        _horizontalScrollController!.jumpTo(newOffset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filteredHeaders.isEmpty) {
      return const Center(child: Text('Нет данных для отображения'));
    }

    final tableColumns = List.generate(widget.filteredHeaders.length, (index) {
      final width = _columnWidths.isNotEmpty ? _columnWidths[index] : 120.0;
      int freezePriority = 0;
      if (widget.filteredHeaders.length > 1) {
        if (index == 0) freezePriority = 2;
        if (index == widget.filteredHeaders.length - 1) freezePriority = 1;
      }
      return TableColumn(width: width, freezePriority: freezePriority);
    });

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              _handlePointerScroll(pointerSignal);
            }
          },
          child: ScrollConfiguration(
            behavior: _IgnoreManualScrollBehavior(),
            child: MouseRegion(
              onHover: (event) {
                final RenderBox? renderBox =
                    context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(event.position);
                final tableWidth = renderBox.size.width;
                final leftFrozenWidth = _getLeftFrozenWidth();
                final rightFrozenWidth = _getRightFrozenWidth();

                final isInLeftFrozenArea = localPosition.dx <= leftFrozenWidth;
                final isInRightFrozenArea =
                    localPosition.dx >= (tableWidth - rightFrozenWidth);
                final newHoveringState =
                    isInLeftFrozenArea || isInRightFrozenArea;

                if (newHoveringState != _isHoveringFrozenArea) {
                  setState(() => _isHoveringFrozenArea = newHoveringState);
                }
              },
              cursor: _isHoveringFrozenArea
                  ? SystemMouseCursors.resizeUpDown
                  : SystemMouseCursors.resizeLeftRight,
              child: TableView.builder(
                controller: _tableViewController,
                columns: tableColumns,
                rowCount: widget.filteredDataRows.length,
                rowHeight: 40,
                headerHeight: 56,
                headerBuilder: (context, contentBuilder) {
                  return contentBuilder(context, (context, column) {
                    final headerText = widget.filteredHeaders[column];
                    final originalIndex =
                        widget.activeFile.headers.indexOf(headerText);
                    final patternText = (originalIndex != -1 &&
                            originalIndex < widget.activeFile.patternRow.length)
                        ? widget.activeFile.patternRow[originalIndex]
                        : '';
                    final isSelected = headerText ==
                            widget.activeFile.selectedNameColumn ||
                        headerText == widget.activeFile.selectedPriceColumn ||
                        headerText == widget.activeFile.selectedQuantityColumn;

                    BorderSide leftBorder = BorderSide.none;
                    BorderSide rightBorder =
                        BorderSide(color: Colors.grey.shade300, width: 0.5);

                    if (widget.filteredHeaders.length > 1) {
                      if (column == 0) {
                        rightBorder =
                            BorderSide(color: Colors.blue.shade300, width: 2.0);
                      } else if (column == widget.filteredHeaders.length - 1) {
                        leftBorder =
                            BorderSide(color: Colors.blue.shade300, width: 2.0);
                        rightBorder = BorderSide.none;
                      }
                    }

                    final bool isFrozenColumn = column == 0 ||
                        column == widget.filteredHeaders.length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade100
                            : isFrozenColumn
                                ? Colors.blue.withOpacity(0.05)
                                : null,
                        border: Border(
                          left: leftBorder,
                          right: rightBorder,
                          bottom:
                              BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (patternText.isNotEmpty)
                            Text(
                              patternText,
                              style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 10,
                                  color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          Flexible(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    headerText,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : null),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                if (isFrozenColumn &&
                                    widget.filteredHeaders.length > 1)
                                  Icon(Icons.lock_outline,
                                      size: 12, color: Colors.blue.shade600),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                },
                rowBuilder: (context, row, contentBuilder) {
                  final rowData = widget.filteredDataRows[row];
                  return Container(
                    decoration: BoxDecoration(
                      color: row.isOdd
                          ? Colors.grey.withOpacity(0.05)
                          : Colors.transparent,
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.grey.shade200, width: 0.5)),
                    ),
                    child: contentBuilder(context, (context, column) {
                      final header = widget.filteredHeaders[column];
                      final cellValue = rowData[header]?.toString() ?? '';
                      final isSelected = header ==
                              widget.activeFile.selectedNameColumn ||
                          header == widget.activeFile.selectedPriceColumn ||
                          header == widget.activeFile.selectedQuantityColumn;

                      BorderSide leftBorder = BorderSide.none;
                      BorderSide rightBorder =
                          BorderSide(color: Colors.grey.shade300, width: 0.5);

                      if (widget.filteredHeaders.length > 1) {
                        if (column == 0) {
                          rightBorder = BorderSide(
                              color: Colors.blue.shade200, width: 1.5);
                        } else if (column ==
                            widget.filteredHeaders.length - 1) {
                          leftBorder = BorderSide(
                              color: Colors.blue.shade200, width: 1.5);
                          rightBorder = BorderSide.none;
                        }
                      }

                      final bool isFrozenColumn = column == 0 ||
                          column == widget.filteredHeaders.length - 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.shade50
                              : isFrozenColumn
                                  ? Colors.blue.withOpacity(0.02)
                                  : null,
                          border: Border(
                            left: leftBorder,
                            right: rightBorder,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cellValue,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreSelector extends StatelessWidget {
  const _CoreSelector();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PdfImportCubit>();
    final selectedCore = cubit.state.selectedCore;
    final isLoading = cubit.state.status == LoadingStatus.loading;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: SegmentedButton<ParsingCore>(
        segments: const <ButtonSegment<ParsingCore>>[
          ButtonSegment<ParsingCore>(
            value: ParsingCore.camelot,
            label: Text('Camelot'),
            icon: Tooltip(
                message: 'Быстрее, только для PDF',
                child: Icon(Icons.picture_as_pdf)),
          ),
          ButtonSegment<ParsingCore>(
            value: ParsingCore.dedoc,
            label: Text('Dedoc'),
            icon: Tooltip(
                message: 'Медленнее, для PDF и сканов',
                child: Icon(Icons.document_scanner)),
          ),
        ],
        selected: {selectedCore},
        onSelectionChanged: isLoading
            ? null
            : (newSelection) {
                context.read<PdfImportCubit>().selectCore(newSelection.first);
              },
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
