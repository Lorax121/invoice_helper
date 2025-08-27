
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'settings_service.dart';

class CliPdfParserService implements PdfParserService {
  @override
  Future<Map<String, dynamic>> parse(String pdfFilePath,
      {required ParsingCore core,
      bool useDedocPreprocessing = false}) async {
    String? capturedStdout;
    String? capturedStderr;
    try {
      final executableDir = p.dirname(Platform.resolvedExecutable);
      final parserPath =
          p.join(executableDir, 'backend', 'parser', 'parser.exe');

      if (!await File(parserPath).exists()) {
        throw Exception(
            'Не найден исполняемый файл парсера по пути: $parserPath');
      }

      final arguments = [
        '--file',
        pdfFilePath,
        '--core',
        core.cliArgument,
      ];

      if (core == ParsingCore.dedoc && useDedocPreprocessing) {
        arguments.add('--preprocess-pdf');
      }

      final processResult = await Process.run(
        parserPath,
        arguments, 
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      capturedStdout = processResult.stdout as String?;
      capturedStderr = processResult.stderr as String?;

      if (processResult.exitCode == 0 &&
          capturedStdout != null &&
          capturedStdout!.trim().isNotEmpty) {
        final Map<String, dynamic> jsonData = jsonDecode(capturedStdout!);
        return jsonData;
      } else {
        if (processResult.exitCode == 0) {
          throw Exception(
              'Парсер завершился успешно, но не вернул никаких данных (stdout пуст).\n\n'
              '--- STDERR ---\n$capturedStderr');
        }
        throw Exception(
            'Ошибка парсера (код ${processResult.exitCode}): $capturedStderr');
      }
    } catch (e) {
      throw Exception(
          'Внутренняя ошибка при вызове парсера: ${e.toString()}\n\n'
          '--- STDOUT ---\n$capturedStdout\n'
          '--- STDERR ---\n$capturedStderr');
    }
  }
}

abstract class PdfParserService {
  Future<Map<String, dynamic>> parse(String pdfFilePath,
      {required ParsingCore core, bool useDedocPreprocessing = false});
}
