import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feeder_provider.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _hideToken = true;

  @override
  void initState() {
    super.initState();
    final feeder = context.read<FeederProvider>();
    _urlController = TextEditingController(text: feeder.backendUrl);
    _tokenController = TextEditingController(text: feeder.apiToken);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feeder = context.watch<FeederProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text(
          'Conexión',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Acceso al servidor desde este dispositivo',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        if (feeder.connectionMessage != null) ...[
          ConnectionBanner(
            message: feeder.connectionMessage!,
            loading: feeder.connectionPhase == ConnectionPhase.connecting,
            success: feeder.connectionPhase == ConnectionPhase.success,
          ),
          const SizedBox(height: 14),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    icon: Icons.dns_outlined,
                    title: 'Servidor FastAPI',
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL del servidor',
                      hintText: 'http://100.x.x.x:7890',
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: (value) {
                      final uri = Uri.tryParse(value?.trim() ?? '');
                      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                        return 'Ingresa una URL completa con http:// o https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _tokenController,
                    obscureText: _hideToken,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Token de acceso del servidor',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hideToken = !_hideToken),
                        icon: Icon(
                          _hideToken ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'El token es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: feeder.loading
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            await feeder.saveSettings(
                              _urlController.text,
                              _tokenController.text,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  feeder.error == null
                                      ? 'Conexión guardada y verificada'
                                      : 'Se guardó, pero no se pudo verificar',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar y probar'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'El token se guarda en las preferencias de la aplicación. Los valores iniciales se cargan desde el archivo .env.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
