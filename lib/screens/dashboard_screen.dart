import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_models.dart';
import '../providers/feeder_provider.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feeder = context.watch<FeederProvider>();
    return RefreshIndicator(
      onRefresh: feeder.refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pet feeder',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edge system control',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: feeder.loading ? null : feeder.refreshAll,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          if (feeder.loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            sliver: SliverList.list(
              children: [
                if (feeder.error != null) ...[
                  ErrorBanner(message: feeder.error!),
                  const SizedBox(height: 14),
                ],
                _ModeCard(master: feeder.master, loading: feeder.loading),
                const SizedBox(height: 14),
                _MasterCard(status: feeder.master),
                const SizedBox(height: 14),
                _CameraCard(status: feeder.camera),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.master, required this.loading});

  final MasterStatus? master;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(icon: Icons.tune, title: 'Operating mode'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'automatic',
                    icon: Icon(Icons.schedule),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: 'manual_on',
                    icon: Icon(Icons.power),
                    label: Text('On'),
                  ),
                  ButtonSegment(
                    value: 'manual_off',
                    icon: Icon(Icons.power_off),
                    label: Text('Off'),
                  ),
                ],
                selected: {master?.mode ?? 'automatic'},
                onSelectionChanged: loading
                    ? null
                    : (selection) => context.read<FeederProvider>().setMode(
                        selection.first,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              master?.relayEnabled == true
                  ? 'Camera and fan are powered'
                  : 'Camera and fan are powered off',
              style: TextStyle(
                color: master?.relayEnabled == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.status});

  final MasterStatus? status;

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      title: 'ESP32 master',
      icon: Icons.memory,
      online: status != null,
      rows: [
        StatusRow('Local time', status?.localTime ?? 'Unavailable'),
        StatusRow('Wi-Fi', status == null ? '--' : '${status!.wifiRssi} dBm'),
        StatusRow('Last reset', status?.resetReason ?? '--'),
        StatusRow('Uptime', formatUptime(status?.uptimeMs)),
        StatusRow(
          'Clock',
          status?.timeSynchronized == true
              ? 'Synchronized'
              : 'Not synchronized',
        ),
      ],
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.status});

  final CameraStatus? status;

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      title: 'ESP32-CAM',
      icon: Icons.photo_camera_outlined,
      online: status != null && status!.cameraReady,
      rows: [
        StatusRow(
          'Model',
          status?.modelReady == true ? 'Ready' : 'Unavailable',
        ),
        StatusRow('Wi-Fi', status == null ? '--' : '${status!.wifiRssi} dBm'),
        StatusRow(
          'Memory',
          status == null
              ? '--'
              : '${(status!.freePsram / 1048576).toStringAsFixed(1)} MB PSRAM',
        ),
        StatusRow('Stream', status?.streamActive == true ? 'Active' : 'Idle'),
        StatusRow('Uptime', formatUptime(status?.uptimeMs)),
      ],
    );
  }
}
