import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parts_stock/src/core/models/converter_config.dart';
import 'package:parts_stock/src/core/services/csv_converter.dart';

void main() {
  group('CsvConverter', () {
    late Directory tempDir;
    late File input;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('parts_stock_test');
      input = File('${tempDir.path}/source.csv');
      await input.writeAsString(
        <String>[
          'id,sku,manufacturer,name,excerpt,price',
          '1,LR000001,Land Rover-1,,,33767.14',
          '2,LR000002,Land Rover-1,,,150',
          '3,LR000003,Land Rover-1,,,12',
          '4,LR000003,Land Rover-1,,,12',
          '5,LR000004,Land Rover-1,,,0',
          '6,LR000005,Land Rover-1,,,4500',
        ].join('\n'),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('applies margin, dedupes, drops zero-priced rows', () async {
      final ConverterConfig config = ConverterConfig.defaults();
      final Directory outDirOverride =
          Directory('${tempDir.path}/out')..createSync(recursive: true);
      final CsvConverter converter = CsvConverter();
      final List<ConversionEvent> events = await converter
          .convertOne(
            inputPath: input.path,
            config: config,
            outputDirectoryOverride: outDirOverride.path,
          )
          .toList();

      final ConversionDone done = events.whereType<ConversionDone>().single;
      expect(done.rowsRead, 6);
      expect(done.rowsWritten, 4);
      expect(done.rowsSkipped, 2);

      final Directory outDir = Directory(done.outputDirectory);
      final List<File> files = outDir
          .listSync()
          .whereType<File>()
          .toList(growable: false);
      expect(files, hasLength(1));
      final List<String> rows = await files.first.readAsLines();
      expect(rows.first, 'Brand,SKU,Ціна,Кількість,Опис');
      expect(
        rows.any((String r) => r.startsWith('Land Rover,LR000001,')),
        isTrue,
      );
      expect(
        rows.any((String r) => r.startsWith('Land Rover,LR000005,5175')),
        isTrue,
      );
    });

    test('chunks the output by configured megabyte ceiling', () async {
      final StringBuffer buffer = StringBuffer('id,sku,price\n');
      for (int i = 1; i <= 3000; i++) {
        buffer.writeln(
          '$i,SKU$i,${(i % 47) + 1}',
        );
      }
      final File big = File('${tempDir.path}/big.csv');
      await big.writeAsString(buffer.toString());

      final ConverterConfig config = ConverterConfig.defaults().copyWith(
        maxFileSizeMb: 1,
      );
      final Directory outDirOverride =
          Directory('${tempDir.path}/out-big')..createSync(recursive: true);

      final CsvConverter converter = CsvConverter();
      final List<ConversionEvent> events = await converter
          .convertOne(
            inputPath: big.path,
            config: config,
            outputDirectoryOverride: outDirOverride.path,
          )
          .toList();
      final ConversionDone done = events.whereType<ConversionDone>().single;
      expect(done.rowsWritten, 3000);
      expect(done.chunks, greaterThanOrEqualTo(1));
    });
  });
}
