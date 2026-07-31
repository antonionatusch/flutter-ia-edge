import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_models.dart';
import '../providers/feeder_provider.dart';
import '../widgets/common_widgets.dart';

class RoundDetailScreen extends StatefulWidget {
  const RoundDetailScreen({super.key, required this.roundId});

  final int roundId;

  @override
  State<RoundDetailScreen> createState() => _RoundDetailScreenState();
}

class _RoundDetailScreenState extends State<RoundDetailScreen> {
  FeedingRoundDetail? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feeder = context.read<FeederProvider>();
      final detail = await feeder.fetchRoundDetail(widget.roundId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final round = _detail?.round;

    return Scaffold(
      appBar: AppBar(
        title: Text(round == null ? 'Detalle de ronda' : 'Ronda #${round.id}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: scheme.error),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _RoundSummaryCard(round: round!),
                  const SizedBox(height: 16),
                  const SectionHeading(
                    icon: Icons.analytics_outlined,
                    title: 'Muestras',
                  ),
                  const SizedBox(height: 12),
                  if (_detail!.classifications.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'No hay clasificaciones registradas para esta ronda.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ..._detail!.classifications.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ClassificationCard(classification: c),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RoundSummaryCard extends StatelessWidget {
  const _RoundSummaryCard({required this.round});

  final FeedingRound round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localTime = round.scheduledAt.toLocal();
    final minute = localTime.minute.toString().padLeft(2, '0');
    final resultText = round.result == null
        ? _statusText(round.status)
        : translateClassName(round.result!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _resultColor(
                    round.result,
                    scheme,
                  ).withValues(alpha: 0.12),
                  child: Icon(
                    round.source == 'debug' ? Icons.bug_report : Icons.schedule,
                    color: _resultColor(round.result, scheme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resultText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${localTime.day}/${localTime.month}/${localTime.year} '
                        '${localTime.hour}:$minute',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (round.confidence != null)
                  Text(
                    '${(round.confidence! * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.category,
              label: 'Fuente',
              value: round.source == 'debug' ? 'Prueba manual' : 'Automática',
            ),
            _InfoRow(
              icon: Icons.check_circle_outline,
              label: 'Estado',
              value: _statusText(round.status),
            ),
            _InfoRow(
              icon: Icons.scatter_plot,
              label: 'Muestras',
              value:
                  '${round.validSampleCount} válidas / ${round.sampleCount} totales',
            ),
            if (round.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        round.error!,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _resultColor(String? result, ColorScheme scheme) => switch (result) {
    'food_available' => const Color(0xFF17745A),
    'empty' => scheme.error,
    _ => scheme.onSurfaceVariant,
  };

  String _statusText(String status) => switch (status) {
    'pending' => 'Pendiente',
    'running' => 'En curso',
    'skipped' => 'Omitida',
    'completed' => 'Completada',
    'failed' => 'Fallida',
    _ => status,
  };
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({required this.classification});

  final RoundClassification classification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = classification.error != null;
    final className = classification.predictedClass;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: hasError
                      ? scheme.errorContainer
                      : _classColor(className).withValues(alpha: 0.12),
                  child: Text(
                    '${classification.sampleIndex + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasError
                          ? scheme.onErrorContainer
                          : _classColor(className),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasError
                      ? Text(
                          'Error',
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          translateClassName(className ?? 'unknown'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
                if (classification.confidence != null)
                  Text(
                    '${(classification.confidence! * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
              ],
            ),
            if (hasError) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  classification.error!,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (classification.scores != null &&
                classification.scores!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Confianza por clase',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ..._sortedScores(classification.scores!).map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ScoreBar(
                    label: translateClassName(entry.key),
                    value: entry.value,
                    color: _classColor(entry.key),
                    highlight: entry.key == className,
                  ),
                ),
              ),
            ],
            if (classification.frameId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Frame: ${classification.frameId}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _classColor(String? cls) => switch (cls) {
    'food_available' => const Color(0xFF17745A),
    'empty' => const Color(0xFFC62828),
    'unknown' => const Color(0xFF757575),
    _ => const Color(0xFF757575),
  };

  List<MapEntry<String, double>> _sortedScores(Map<String, double> scores) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? color : scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                highlight ? color : color.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 45,
          child: Text(
            '${(value * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
