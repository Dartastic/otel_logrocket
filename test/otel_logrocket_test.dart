// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_logrocket/otel_logrocket.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemoryLogExporter logs;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_logrocket-test',
    );
    logs = harness.logs;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(LogRecord r) {
    final list = r.attributes?.toList() ?? <Attribute<Object>>[];
    return {for (final a in list) a.key: a.value};
  }

  test('track records event', () async {
    OTelLogrocket().track('Cart Update', properties: {'count': 2});
    await harness.flushLogs();
    final r =
        logs.records.firstWhere((r) => r.body == 'logrocket.track Cart Update');
    final a = attrsOf(r);
    expect(a['logrocket.event.name'], 'Cart Update');
    expect(a['logrocket.property.count'], 2);
  });

  test('identify records session.url', () async {
    OTelLogrocket().identify(
      'user-1',
      traits: {'plan': 'pro'},
      sessionUrl: 'https://app.logrocket.com/sess/abc',
    );
    await harness.flushLogs();
    final r =
        logs.records.firstWhere((r) => r.body == 'logrocket.identify user-1');
    final a = attrsOf(r);
    expect(a['logrocket.session.url'], 'https://app.logrocket.com/sess/abc');
    expect(a['user.id'], 'user-1');
  });

  test('suppression skips emit but forwards', () async {
    var forwarded = 0;
    await runWithoutLogrocketInstrumentationAsync(() async {
      OTelLogrocket(forwardTrack: (_, __) => forwarded++).track('x');
    });
    await harness.flushLogs();
    expect(forwarded, 1);
    expect(logs.records.where((r) => r.body == 'logrocket.track x'), isEmpty);
  });
}
