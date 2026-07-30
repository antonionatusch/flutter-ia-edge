import 'package:flutter/material.dart';

class StatusRow {
  const StatusRow(this.label, this.value);

  final String label;
  final String value;
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.title,
    required this.icon,
    required this.online,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final bool online;
  final List<StatusRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionHeading(icon: icon, title: title),
                ),
                StatusPill(
                  label: online ? 'En línea' : 'Desconectado',
                  active: online,
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF17745A)
        : Theme.of(context).colorScheme.outline;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.message,
    required this.loading,
    required this.success,
  });

  final String message;
  final bool loading;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = loading
        ? scheme.secondaryContainer
        : success
        ? const Color(0xFFDCEFE7)
        : scheme.errorContainer;
    final foreground = loading
        ? scheme.onSecondaryContainer
        : success
        ? const Color(0xFF145743)
        : scheme.onErrorContainer;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (loading)
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foreground,
                ),
              )
            else
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: foreground,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

String formatUptime(int? milliseconds) {
  if (milliseconds == null) return '--';
  final duration = Duration(milliseconds: milliseconds);
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
}

String translateResetReason(String? reason) => switch (reason) {
  'power_on' => 'Encendido',
  'brownout' => 'Caída de voltaje',
  'software' => 'Software',
  'external' => 'Externo',
  'panic' => 'Error crítico',
  'interrupt_watchdog' ||
  'task_watchdog' ||
  'watchdog' => 'Temporizador de vigilancia',
  'deep_sleep' => 'Sueño profundo',
  null => '--',
  _ => 'Desconocido',
};

String translateClassName(String name) => switch (name) {
  'empty' => 'vacío',
  'food_available' => 'alimento disponible',
  'unknown' => 'desconocido',
  'not_classified' => 'sin clasificar',
  _ => name.replaceAll('_', ' '),
};
