import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/pdf_import_cubit.dart';
import '../../../core/services/settings_service.dart';

class FileImportArea extends StatefulWidget {
  const FileImportArea({Key? key}) : super(key: key);

  @override
  State<FileImportArea> createState() => _FileImportAreaState();
}

class _FileImportAreaState extends State<FileImportArea> {
  final List<String> _supportedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'bmp',
    'tiff'
  ];

  bool _isDragging = false;

  void _processFiles(List<String> paths) {
    if (paths.isEmpty || !mounted) return;
    context.read<PdfImportCubit>().queueFilesForProcessing(paths);
  }

  Future<void> _pickFiles() async {
    final cubit = context.read<PdfImportCubit>();
    final selectedCore = cubit.state.selectedCore;

    final List<String> allowedExtensions;
    if (selectedCore == ParsingCore.camelot) {
      allowedExtensions = ['pdf'];
    } else {
      allowedExtensions = _supportedExtensions;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      _processFiles(result.paths.whereType<String>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300, minWidth: 400),
      child: DropTarget(
        onDragDone: (details) {
          final cubit = context.read<PdfImportCubit>();
          final selectedCore = cubit.state.selectedCore;

          final List<String> allowedExtensions;
          if (selectedCore == ParsingCore.camelot) {
            allowedExtensions = ['pdf'];
          } else {
            allowedExtensions = _supportedExtensions;
          }

          final validPaths = details.files
              .map((f) => f.path)
              .where((p) =>
                  allowedExtensions.contains(p.split('.').last.toLowerCase()))
              .toList();

          if (validPaths.isNotEmpty) {
            _processFiles(validPaths);
          }
        },
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        child: Container(
          decoration: BoxDecoration(
            color: _isDragging
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging ? Colors.blueAccent : Colors.grey.shade400,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 80,
                    color:
                        _isDragging ? Colors.blueAccent : Colors.grey.shade600),
                const SizedBox(height: 16),
                const Text('Перетащите файлы сюда',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('или',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выберите файлы...'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
