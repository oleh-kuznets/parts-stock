import 'dart:convert';

import 'package:flutter/foundation.dart';

/// How a single output column is filled.
enum ColumnMappingKind {
  /// Pull the value from a named input column (case-insensitive).
  source,

  /// Hardcoded literal value, written into every output row as-is.
  hardcoded,
}

@immutable
class ColumnMapping {
  const ColumnMapping({
    required this.outputColumn,
    required this.kind,
    this.sourceColumn,
    this.hardcodedValue,
  });

  factory ColumnMapping.fromJson(Map<String, dynamic> json) {
    final String kindRaw = (json['kind'] as String?) ?? 'source';
    final ColumnMappingKind kind = ColumnMappingKind.values.firstWhere(
      (ColumnMappingKind k) => k.name == kindRaw,
      orElse: () => ColumnMappingKind.source,
    );
    return ColumnMapping(
      outputColumn: (json['outputColumn'] as String?)?.trim() ?? '',
      kind: kind,
      sourceColumn: (json['sourceColumn'] as String?)?.trim(),
      hardcodedValue: json['hardcodedValue'] as String?,
    );
  }

  final String outputColumn;
  final ColumnMappingKind kind;
  final String? sourceColumn;
  final String? hardcodedValue;

  ColumnMapping copyWith({
    String? outputColumn,
    ColumnMappingKind? kind,
    String? sourceColumn,
    String? hardcodedValue,
    bool clearSource = false,
    bool clearHardcoded = false,
  }) {
    return ColumnMapping(
      outputColumn: outputColumn ?? this.outputColumn,
      kind: kind ?? this.kind,
      sourceColumn: clearSource ? null : (sourceColumn ?? this.sourceColumn),
      hardcodedValue: clearHardcoded
          ? null
          : (hardcodedValue ?? this.hardcodedValue),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'outputColumn': outputColumn,
    'kind': kind.name,
    if (sourceColumn != null) 'sourceColumn': sourceColumn,
    if (hardcodedValue != null) 'hardcodedValue': hardcodedValue,
  };
}

/// Conditional price multiplier.
///
/// A row's price is matched against the first rule whose
/// `[minPrice, maxPrice)` window contains it. `maxPrice == null` means
/// "no upper bound" (catch-all tail).
@immutable
class MarginRule {
  const MarginRule({
    required this.minPrice,
    required this.multiplier,
    this.maxPrice,
    this.label,
  });

  factory MarginRule.fromJson(Map<String, dynamic> json) {
    return MarginRule(
      minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      label: json['label'] as String?,
    );
  }

  final double minPrice;
  final double? maxPrice;
  final double multiplier;
  final String? label;

  /// Multiplier expressed as a percent markup (e.g. `1.25 → 25.0`).
  double get markupPercent => (multiplier - 1.0) * 100.0;

  bool matches(double price) {
    if (price < minPrice) return false;
    if (maxPrice != null && price >= maxPrice!) return false;
    return true;
  }

  MarginRule copyWith({
    double? minPrice,
    double? maxPrice,
    double? multiplier,
    String? label,
    bool clearMax = false,
  }) {
    return MarginRule(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: clearMax ? null : (maxPrice ?? this.maxPrice),
      multiplier: multiplier ?? this.multiplier,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'minPrice': minPrice,
    if (maxPrice != null) 'maxPrice': maxPrice,
    'multiplier': multiplier,
    if (label != null && label!.isNotEmpty) 'label': label,
  };
}

@immutable
class PriceColumnConfig {
  const PriceColumnConfig({
    required this.sourceColumn,
    required this.outputColumn,
    this.roundToInt = true,
    this.dropZeroOrNegative = true,
    this.minimumPrice = 1,
  });

  factory PriceColumnConfig.fromJson(Map<String, dynamic> json) {
    return PriceColumnConfig(
      sourceColumn: (json['sourceColumn'] as String?)?.trim() ?? 'price',
      outputColumn: (json['outputColumn'] as String?)?.trim() ?? 'Ціна',
      roundToInt: (json['roundToInt'] as bool?) ?? true,
      dropZeroOrNegative: (json['dropZeroOrNegative'] as bool?) ?? true,
      minimumPrice: (json['minimumPrice'] as num?)?.toDouble() ?? 1,
    );
  }

  final String sourceColumn;
  final String outputColumn;
  final bool roundToInt;
  final bool dropZeroOrNegative;
  final double minimumPrice;

  PriceColumnConfig copyWith({
    String? sourceColumn,
    String? outputColumn,
    bool? roundToInt,
    bool? dropZeroOrNegative,
    double? minimumPrice,
  }) {
    return PriceColumnConfig(
      sourceColumn: sourceColumn ?? this.sourceColumn,
      outputColumn: outputColumn ?? this.outputColumn,
      roundToInt: roundToInt ?? this.roundToInt,
      dropZeroOrNegative: dropZeroOrNegative ?? this.dropZeroOrNegative,
      minimumPrice: minimumPrice ?? this.minimumPrice,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceColumn': sourceColumn,
    'outputColumn': outputColumn,
    'roundToInt': roundToInt,
    'dropZeroOrNegative': dropZeroOrNegative,
    'minimumPrice': minimumPrice,
  };
}

@immutable
class DedupeConfig {
  const DedupeConfig({this.enabled = true, this.column = 'sku'});

  factory DedupeConfig.fromJson(Map<String, dynamic> json) {
    return DedupeConfig(
      enabled: (json['enabled'] as bool?) ?? false,
      column: (json['column'] as String?)?.trim() ?? '',
    );
  }

  final bool enabled;
  final String column;

  DedupeConfig copyWith({bool? enabled, String? column}) {
    return DedupeConfig(
      enabled: enabled ?? this.enabled,
      column: column ?? this.column,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'column': column,
  };
}

@immutable
class ConverterConfig {
  const ConverterConfig({
    required this.mappings,
    required this.priceConfig,
    required this.dedupe,
    required this.margins,
    required this.maxFileSizeMb,
    required this.outputBaseSuffix,
  });

  factory ConverterConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMappings =
        (json['mappings'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawMargins =
        (json['margins'] as List<dynamic>?) ?? const <dynamic>[];
    return ConverterConfig(
      mappings: rawMappings
          .whereType<Map<String, dynamic>>()
          .map(ColumnMapping.fromJson)
          .toList(growable: false),
      priceConfig: PriceColumnConfig.fromJson(
        (json['price'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      dedupe: DedupeConfig.fromJson(
        (json['dedupe'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      margins: rawMargins
          .whereType<Map<String, dynamic>>()
          .map(MarginRule.fromJson)
          .toList(growable: false),
      maxFileSizeMb: (json['maxFileSizeMb'] as num?)?.toInt() ?? 25,
      outputBaseSuffix:
          (json['outputBaseSuffix'] as String?)?.trim() ?? '_pricelist',
    );
  }

  factory ConverterConfig.fromJsonString(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Config root must be a JSON object');
    }
    return ConverterConfig.fromJson(decoded);
  }

  static ConverterConfig defaults() {
    return const ConverterConfig(
      mappings: <ColumnMapping>[
        ColumnMapping(
          outputColumn: 'Brand',
          kind: ColumnMappingKind.hardcoded,
          hardcodedValue: 'Land Rover',
        ),
        ColumnMapping(
          outputColumn: 'SKU',
          kind: ColumnMappingKind.source,
          sourceColumn: 'sku',
        ),
        ColumnMapping(
          outputColumn: 'Ціна',
          kind: ColumnMappingKind.source,
          sourceColumn: 'price',
        ),
        ColumnMapping(
          outputColumn: 'Кількість',
          kind: ColumnMappingKind.hardcoded,
          hardcodedValue: '100',
        ),
        ColumnMapping(
          outputColumn: 'Опис',
          kind: ColumnMappingKind.hardcoded,
          hardcodedValue:
              'Ціни та терміни доставки уточнюйте (курс постійно змінюється)',
        ),
      ],
      priceConfig: PriceColumnConfig(
        sourceColumn: 'price',
        outputColumn: 'Ціна',
      ),
      dedupe: DedupeConfig(enabled: true, column: 'sku'),
      margins: <MarginRule>[
        MarginRule(minPrice: 0, maxPrice: 100, multiplier: 1.25),
        MarginRule(minPrice: 100, maxPrice: 300, multiplier: 1.23),
        MarginRule(minPrice: 300, maxPrice: 700, multiplier: 1.21),
        MarginRule(minPrice: 700, maxPrice: 1000, multiplier: 1.20),
        MarginRule(minPrice: 1000, maxPrice: 5000, multiplier: 1.15),
        MarginRule(minPrice: 5000, multiplier: 1.10),
      ],
      maxFileSizeMb: 25,
      outputBaseSuffix: '_pricelist',
    );
  }

  final List<ColumnMapping> mappings;
  final PriceColumnConfig priceConfig;
  final DedupeConfig dedupe;
  final List<MarginRule> margins;
  final int maxFileSizeMb;
  final String outputBaseSuffix;

  ConverterConfig copyWith({
    List<ColumnMapping>? mappings,
    PriceColumnConfig? priceConfig,
    DedupeConfig? dedupe,
    List<MarginRule>? margins,
    int? maxFileSizeMb,
    String? outputBaseSuffix,
  }) {
    return ConverterConfig(
      mappings: mappings ?? this.mappings,
      priceConfig: priceConfig ?? this.priceConfig,
      dedupe: dedupe ?? this.dedupe,
      margins: margins ?? this.margins,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      outputBaseSuffix: outputBaseSuffix ?? this.outputBaseSuffix,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mappings': mappings
        .map((ColumnMapping m) => m.toJson())
        .toList(growable: false),
    'price': priceConfig.toJson(),
    'dedupe': dedupe.toJson(),
    'margins': margins
        .map((MarginRule r) => r.toJson())
        .toList(growable: false),
    'maxFileSizeMb': maxFileSizeMb,
    'outputBaseSuffix': outputBaseSuffix,
  };

  /// Pretty-printed JSON, suitable for `config.txt` next to source CSV files.
  String toPrettyJsonString() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
