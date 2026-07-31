import 'dart:typed_data';

class MasterStatus {
  const MasterStatus({
    required this.mode,
    required this.relayEnabled,
    required this.timeSynchronized,
    required this.localTime,
    required this.wifiRssi,
    required this.uptimeMs,
    required this.resetReason,
  });

  factory MasterStatus.fromJson(Map<String, dynamic> json) => MasterStatus(
    mode: json['mode'] as String? ?? 'unknown',
    relayEnabled: json['relay_enabled'] as bool? ?? false,
    timeSynchronized: json['time_synchronized'] as bool? ?? false,
    localTime: json['local_time'] as String? ?? 'unavailable',
    wifiRssi: (json['wifi_rssi'] as num?)?.toInt() ?? 0,
    uptimeMs: (json['uptime_ms'] as num?)?.toInt() ?? 0,
    resetReason: json['reset_reason'] as String? ?? 'unknown',
  );

  final String mode;
  final bool relayEnabled;
  final bool timeSynchronized;
  final String localTime;
  final int wifiRssi;
  final int uptimeMs;
  final String resetReason;
}

class CameraStatus {
  const CameraStatus({
    required this.cameraReady,
    required this.modelReady,
    required this.frameCached,
    required this.operationBusy,
    required this.wifiRssi,
    required this.freeHeap,
    required this.freePsram,
    required this.streamActive,
    required this.streamFps,
    required this.uptimeMs,
  });

  factory CameraStatus.fromJson(Map<String, dynamic> json) => CameraStatus(
    cameraReady: json['camera_ready'] as bool? ?? false,
    modelReady: json['model_ready'] as bool? ?? false,
    frameCached: json['frame_cached'] as bool? ?? false,
    operationBusy: json['operation_busy'] as bool? ?? false,
    wifiRssi: (json['wifi_rssi'] as num?)?.toInt() ?? 0,
    freeHeap: (json['free_heap'] as num?)?.toInt() ?? 0,
    freePsram: (json['free_psram'] as num?)?.toInt() ?? 0,
    streamActive: json['stream_active'] as bool? ?? false,
    streamFps: (json['stream_fps'] as num?)?.toInt() ?? 0,
    uptimeMs: (json['uptime_ms'] as num?)?.toInt() ?? 0,
  );

  final bool cameraReady;
  final bool modelReady;
  final bool frameCached;
  final bool operationBusy;
  final int wifiRssi;
  final int freeHeap;
  final int freePsram;
  final bool streamActive;
  final int streamFps;
  final int uptimeMs;
}

class ClassificationResult {
  const ClassificationResult({
    required this.status,
    required this.predictedClass,
    required this.confidence,
    required this.scores,
    required this.frameId,
  });

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map<String, dynamic>? ?? const {};
    return ClassificationResult(
      status: json['status'] as String? ?? 'unknown',
      predictedClass: json['predicted_class'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      scores: rawScores.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      frameId: (json['frame_id'] as num?)?.toInt(),
    );
  }

  final String status;
  final String predictedClass;
  final double confidence;
  final Map<String, double> scores;
  final int? frameId;
}

class CaptureResult {
  const CaptureResult(this.bytes, this.frameId);

  final Uint8List bytes;
  final String? frameId;
}

class SystemStatus {
  const SystemStatus({
    required this.master,
    required this.camera,
    this.masterError,
    this.cameraError,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    final masterService = json['master'] as Map<String, dynamic>? ?? const {};
    final cameraService = json['camera'] as Map<String, dynamic>? ?? const {};
    final masterData = masterService['data'] as Map<String, dynamic>?;
    final cameraData = cameraService['data'] as Map<String, dynamic>?;
    return SystemStatus(
      master: masterData == null ? null : MasterStatus.fromJson(masterData),
      camera: cameraData == null ? null : CameraStatus.fromJson(cameraData),
      masterError: masterService['error']?.toString(),
      cameraError: cameraService['error']?.toString(),
    );
  }

  final MasterStatus? master;
  final CameraStatus? camera;
  final String? masterError;
  final String? cameraError;
}

class FeedingRound {
  const FeedingRound({
    required this.id,
    required this.scheduledAt,
    required this.source,
    required this.status,
    required this.result,
    required this.confidence,
    required this.sampleCount,
    required this.validSampleCount,
    required this.error,
  });

  factory FeedingRound.fromJson(Map<String, dynamic> json) => FeedingRound(
    id: (json['id'] as num).toInt(),
    scheduledAt: DateTime.parse(json['scheduled_at'] as String),
    source: json['source'] as String? ?? 'automatic',
    status: json['status'] as String? ?? 'pending',
    result: json['result'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble(),
    sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
    validSampleCount: (json['valid_sample_count'] as num?)?.toInt() ?? 0,
    error: json['error'] as String?,
  );

  final int id;
  final DateTime scheduledAt;
  final String source;
  final String status;
  final String? result;
  final double? confidence;
  final int sampleCount;
  final int validSampleCount;
  final String? error;
}
