import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feeder_provider.dart';
import 'camera_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [DashboardScreen(), CameraScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final feeder = context.watch<FeederProvider>();
    if (feeder.pendingNotificationMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notification = feeder.takePendingNotification();
        if (notification == null) return;
        setState(() => _index = 0);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notification.message)));
      });
    }
    if (_index == 1 && feeder.master != null && !feeder.cameraAccessAllowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _index != 1) return;
        feeder.stopStream();
        setState(() => _index = 0);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(feeder.cameraAccessMessage)));
      });
    }
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => _selectDestination(index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Estado',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Cámara',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }

  Future<void> _selectDestination(int index) async {
    if (index != 1) {
      setState(() => _index = index);
      return;
    }

    final feeder = context.read<FeederProvider>();
    final allowed = await feeder.verifyCameraAccess();
    if (!mounted) return;
    if (allowed) {
      setState(() => _index = index);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(feeder.cameraAccessMessage)));
  }
}
