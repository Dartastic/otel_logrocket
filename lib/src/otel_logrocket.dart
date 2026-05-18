// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_logrocket_suppression.dart';

const _loggerName = 'package.logrocket';

/// Bridges LogRocket SDK calls (track, identify, captureMessage) into
/// OpenTelemetry log records. Records the session URL on identify
/// so server-side traces can link to the replay.
class OTelLogrocket {
  OTelLogrocket({
    LoggerProvider? loggerProvider,
    this.forwardTrack,
    this.forwardIdentify,
  }) : _loggerProvider = loggerProvider;

  final LoggerProvider? _loggerProvider;
  final void Function(String event, Map<String, Object?>? properties)?
      forwardTrack;
  final void Function(String uid, Map<String, Object?>? traits)?
      forwardIdentify;

  OTelLogger _logger() =>
      (_loggerProvider ?? OTel.loggerProvider()).getLogger(_loggerName);

  void track(String event, {Map<String, Object?>? properties}) {
    forwardTrack?.call(event, properties);
    if (logrocketInstrumentationSuppressed()) return;
    _emit(
      body: 'logrocket.track $event',
      eventType: 'track',
      attrs: [OTel.attributeString('logrocket.event.name', event)],
      flatPrefix: 'logrocket.property.',
      payload: properties,
    );
  }

  void identify(String uid,
      {Map<String, Object?>? traits, String? sessionUrl}) {
    forwardIdentify?.call(uid, traits);
    if (logrocketInstrumentationSuppressed()) return;
    _emit(
      body: 'logrocket.identify $uid',
      eventType: 'identify',
      attrs: [
        OTel.attributeString('logrocket.uid', uid),
        OTel.attributeString(User.userId.key, uid),
        if (sessionUrl != null)
          OTel.attributeString('logrocket.session.url', sessionUrl),
      ],
      flatPrefix: 'logrocket.user.',
      payload: traits,
    );
  }

  void _emit({
    required String body,
    required String eventType,
    required List<Attribute<Object>> attrs,
    String? flatPrefix,
    Map<String, Object?>? payload,
  }) {
    final all = <Attribute<Object>>[
      OTel.attributeString('logrocket.event.type', eventType),
      ...attrs,
    ];
    if (payload != null && flatPrefix != null) {
      payload.forEach((k, v) {
        if (v == null) return;
        final key = '$flatPrefix$k';
        if (v is String) {
          all.add(OTel.attributeString(key, v));
        } else if (v is int) {
          all.add(OTel.attributeInt(key, v));
        } else if (v is double) {
          all.add(OTel.attributeDouble(key, v));
        } else if (v is bool) {
          all.add(OTel.attributeBool(key, v));
        } else {
          all.add(OTel.attributeString(key, v.toString()));
        }
      });
    }
    _logger().emit(
      severityNumber: Severity.INFO,
      severityText: 'info',
      body: body,
      attributes: OTel.attributes(all),
    );
  }
}
