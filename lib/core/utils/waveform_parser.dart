List<int>? parseWaveform(dynamic raw) {
  final values = _readWaveformValues(raw);
  if (values == null || values.isEmpty) return null;

  final normalizedValues = values.map((value) => value.abs()).toList();
  final maxValue = normalizedValues.fold<double>(
    0,
    (max, value) => value > max ? value : max,
  );
  final scale = maxValue <= 1
      ? 100.0
      : maxValue > 100
          ? 100.0 / maxValue
          : 1.0;

  return normalizedValues
      .map((value) => (value * scale).round().clamp(0, 100))
      .toList(growable: false);
}

List<int>? parseWaveformFromMap(Map<dynamic, dynamic> raw) {
  for (final key in const [
    'waveform',
    'waveformData',
    'waveformSamples',
    'waveformPeaks',
    'waveForm',
    'normalizedWaveform',
    'peaks',
    'samples',
    'amplitudes',
    'frequencies',
    'frequency',
    'magnitudes',
    'bars',
    'points',
    'audioWaveform',
  ]) {
    if (raw.containsKey(key)) {
      final waveform = parseWaveform(raw[key]);
      if (waveform != null && waveform.isNotEmpty) return waveform;
    }
  }

  for (final key in const [
    'audio',
    'metadata',
    'analysis',
    'features',
    'audioFeatures',
    'waveformAnalysis',
    'analysisData',
  ]) {
    final nested = raw[key];
    if (nested is Map) {
      final waveform = parseWaveformFromMap(nested);
      if (waveform != null && waveform.isNotEmpty) return waveform;
    }
  }

  return null;
}

List<double>? _readWaveformValues(dynamic raw) {
  if (raw == null) return null;

  if (raw is List) {
    final values = <double>[];
    for (final item in raw) {
      final value = _readWaveformNumber(item);
      if (value != null) values.add(value);
    }
    return values;
  }

  if (raw is Map) {
    for (final key in const [
      'waveform',
      'waveformData',
      'waveformSamples',
      'waveformPeaks',
      'waveForm',
      'normalizedWaveform',
      'data',
      'samples',
      'peaks',
      'values',
      'amplitudes',
      'frequencies',
      'frequency',
      'magnitudes',
      'bars',
      'points',
    ]) {
      if (raw.containsKey(key)) {
        final values = _readWaveformValues(raw[key]);
        if (values != null && values.isNotEmpty) return values;
      }
    }

    final numericEntries = raw.entries
        .map((entry) => MapEntry(int.tryParse(entry.key.toString()), entry.value))
        .where((entry) => entry.key != null)
        .toList()
      ..sort((a, b) => a.key!.compareTo(b.key!));
    if (numericEntries.isNotEmpty) {
      final values = numericEntries
          .map((entry) => _readWaveformNumber(entry.value))
          .whereType<double>()
          .toList(growable: false);
      if (values.isNotEmpty) return values;
    }
    return null;
  }

  if (raw is String) {
    final values = RegExp(r'-?\d+(?:\.\d+)?')
        .allMatches(raw)
        .map((match) => double.tryParse(match.group(0)!))
        .whereType<double>()
        .toList(growable: false);
    return values;
  }

  return null;
}

double? _readWaveformNumber(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  if (raw is List && raw.isNotEmpty) {
    for (final item in raw.reversed) {
      final value = _readWaveformNumber(item);
      if (value != null) return value;
    }
  }
  if (raw is Map) {
    for (final key in const [
      'value',
      'height',
      'amplitude',
      'peak',
      'magnitude',
      'frequency',
      'y',
    ]) {
      final value = _readWaveformNumber(raw[key]);
      if (value != null) return value;
    }
  }
  return null;
}
