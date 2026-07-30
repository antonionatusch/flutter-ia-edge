import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feeder_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/rgb565_image.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feeder = context.watch<FeederProvider>();
    final hasLiveFrame = feeder.streamFrame != null && feeder.streamConnected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text(
          'Camera lab',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Live RGB565 stream and model results',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        if (feeder.error != null) ...[
          ErrorBanner(message: feeder.error!),
          const SizedBox(height: 14),
        ],
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: const Color(0xFF17211E),
              child: hasLiveFrame
                  ? Rgb565Image(bytes: feeder.streamFrame!)
                  : feeder.capturedImage != null
                  ? Image.memory(feeder.capturedImage!, fit: BoxFit.cover)
                  : const _CameraPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StatusPill(
              label: feeder.streamStatus,
              active: feeder.streamConnected,
            ),
            const Spacer(),
            Text('320 × 240', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: feeder.streamConnected
                    ? feeder.stopStream
                    : feeder.startStream,
                icon: Icon(
                  feeder.streamConnected ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(
                  feeder.streamConnected ? 'Stop live' : 'Start live',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: feeder.cameraBusy || feeder.streamConnected
                    ? null
                    : feeder.captureAndClassify,
                icon: feeder.cameraBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.center_focus_strong),
                label: const Text('Capture'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ClassificationCard(),
        const SizedBox(height: 12),
        Text(
          'Starting live view switches the master to manual_on. Stop the stream and select Off or Auto from Status when finished.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            'No frame yet',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final result = context.watch<FeederProvider>().classification;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              icon: Icons.auto_awesome,
              title: 'Classification',
            ),
            const SizedBox(height: 14),
            if (result == null)
              Text(
                'Capture a frame or start live view to see a prediction.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.predictedClass.replaceAll('_', ' '),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${(result.confidence * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final score in result.scores.entries) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(score.key.replaceAll('_', ' ')),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(value: score.value),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: Text('${(score.value * 100).toStringAsFixed(0)}%'),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
