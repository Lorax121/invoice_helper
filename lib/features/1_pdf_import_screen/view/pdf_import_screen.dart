import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager_plus_v2/window_manager_plus_v2.dart';
import '../../../core/models/processed_file.dart';
import '../state/pdf_import_cubit.dart';
import '../widgets/drag_and_drop_area.dart';
import 'column_selector_widget.dart';

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'bmp', 'tiff'],
      allowMultiple: true,
    );
    if (result != null && result.paths.isNotEmpty) {
      if (!mounted) return;
      context
          .read<PdfImportCubit>()
          .queueFilesForProcessing(result.paths.whereType<String>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Помощник обработки накладных'),
        actions: [
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocConsumer<PdfImportCubit, PdfImportState>(
          listenWhen: (p, c) =>
              p.status != c.status &&
              c.status == LoadingStatus.needsConfirmation,
          listener: (context, state) {
            if (state.duplicateFileName != null) {
              _showUpdateDialog(context, state.duplicateFileName!);
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
    );
  }

  Future<void> _showUpdateDialog(BuildContext context, String fileName) async {
    final cubit = context.read<PdfImportCubit>();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Файл уже существует'),
        content: Text(
            'Файл "$fileName" уже был добавлен. Хотите обновить его данные?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет, пропустить')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Да, обновить')),
        ],
      ),
    );
    cubit.resolveDuplicate(result ?? false);
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<PdfImportCubit>().state;
    return Column(
      children: [
        const Expanded(child: FileImportArea()),
        if (state.status == LoadingStatus.loading)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(state.message)
              ],
            ),
          ),
        if (state.status == LoadingStatus.error)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text('Ошибка: ${state.message}',
                style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final PdfImportState state;
  const _SuccessView({required this.state});

  void _launchOrFocusOverlay(BuildContext context) async {
    final cubit = context.read<PdfImportCubit>();
    final activeFile = state.activeFile;

    if (activeFile == null || activeFile.selectedNameColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ошибка: Не выбрана колонка для наименования.'),
          backgroundColor: Colors.red));
      return;
    }

    final currentOverlayId = state.overlayWindowId;

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
      final dataForOverlay = activeFile.dataRows.map((row) {
        return {
          ...row,
          '__name_col': activeFile.selectedNameColumn,
          '__price_col': activeFile.selectedPriceColumn
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
    final activeFile = state.activeFile;
    if (activeFile == null)
      return const Center(child: Text('Нет активного файла.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Текущий файл: ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: DropdownButton<String>(
                value: activeFile.filePath,
                isExpanded: true,
                items: state.processedFiles.map((file) {
                  return DropdownMenuItem(
                      value: file.filePath,
                      child:
                          Text(file.fileName, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: state.status == LoadingStatus.loading
                    ? null
                    : (filePath) {
                        if (filePath != null) {
                          context
                              .read<PdfImportCubit>()
                              .setActiveFile(filePath);
                        }
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16.0,
          runSpacing: 8.0,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 250, maxWidth: 400),
              child: ColumnSelector(
                label: 'Колонка Наименования:',
                columns: activeFile.headers,
                selectedValue: activeFile.selectedNameColumn,
                onChanged: (newValue) => context
                    .read<PdfImportCubit>()
                    .selectColumnsForActiveFile(nameColumn: newValue),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 250, maxWidth: 400),
              child: ColumnSelector(
                label: 'Колонка Цены:',
                columns: activeFile.headers,
                selectedValue: activeFile.selectedPriceColumn,
                onChanged: (newValue) => context
                    .read<PdfImportCubit>()
                    .selectColumnsForActiveFile(priceColumn: newValue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: (activeFile.selectedNameColumn != null)
              ? () => _launchOrFocusOverlay(context)
              : null,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Открыть оверлей-помощник'),
        ),
        const Divider(height: 16),
        Expanded(
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            dividerThickness: 1,
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columns: _buildDataColumns(context, activeFile),
            rows: _buildDataRows(activeFile),
          ),
        ),
        SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: (state.status == LoadingStatus.loading)
                  ? Row(key: const ValueKey('loading'), children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(state.message)
                    ])
                  : Text(state.message,
                      key: ValueKey(state.message),
                      style: TextStyle(
                          color: state.status == LoadingStatus.error
                              ? Colors.red
                              : Colors.green)),
            ),
          ),
        ),
      ],
    );
  }

  List<DataColumn2> _buildDataColumns(
      BuildContext context, ProcessedFile file) {
    return List.generate(file.headers.length, (i) {
      final headerText = file.headers[i];
      final patternText =
          (i < file.patternRow.length) ? file.patternRow[i] : '';
      final isSelected = headerText == file.selectedNameColumn ||
          headerText == file.selectedPriceColumn;
      return DataColumn2(
        size: ColumnSize.S,
        label: Tooltip(
          message: headerText,
          child: AutoSizeText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$patternText\n',
                  style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                      color: Colors.grey.shade600),
                ),
                TextSpan(
                  text: headerText,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          isSelected ? Theme.of(context).primaryColor : null),
                ),
              ],
            ),
            maxLines: 3,
            minFontSize: 9,
            stepGranularity: 1.0,
            wrapWords: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    });
  }

  List<DataRow> _buildDataRows(ProcessedFile file) {
    return List.generate(file.dataRows.length, (index) {
      final row = file.dataRows[index];
      return DataRow2(
        color: MaterialStateProperty.all(
            index.isOdd ? Colors.grey.withAlpha(15) : Colors.transparent),
        cells: file.headers.map((header) {
          return DataCell(SelectableText(row[header]?.toString() ?? ''));
        }).toList(),
      );
    });
  }
}
