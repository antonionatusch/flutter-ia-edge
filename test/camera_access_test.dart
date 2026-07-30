import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_ia_edge/models/device_models.dart';
import 'package:flutter_ia_edge/providers/feeder_provider.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'BACKEND_URL=http://localhost:7890\nBACKEND_API_TOKEN=test',
    );
  });

  test('bloquea la cámara cuando el relé está apagado', () {
    final provider = FeederProvider();
    provider.master = _master(mode: 'automatic', relayEnabled: false);

    expect(provider.cameraAccessAllowed, isFalse);
  });

  test('bloquea la cámara en manual apagado', () {
    final provider = FeederProvider();
    provider.master = _master(mode: 'manual_off', relayEnabled: false);

    expect(provider.cameraAccessAllowed, isFalse);
  });

  test('permite la cámara durante una ronda activa', () {
    final provider = FeederProvider();
    provider.master = _master(mode: 'automatic', relayEnabled: true);

    expect(provider.cameraAccessAllowed, isTrue);
  });
}

MasterStatus _master({required String mode, required bool relayEnabled}) =>
    MasterStatus(
      mode: mode,
      relayEnabled: relayEnabled,
      timeSynchronized: true,
      localTime: '2026-07-30T19:00:00',
      wifiRssi: -55,
      uptimeMs: 1000,
      resetReason: 'power_on',
    );
