import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../services/app_lock_service.dart';
import '../theme/app_spacing.dart';

/// Blocks the app behind a biometric prompt when the lock is enabled.
///
/// Re-prompts when the app returns from the background past the grace period.
/// Without the grace window, photographing a receipt — which backgrounds the
/// app — would demand a fingerprint on every return, and users would turn the
/// feature off within a day.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = true;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _evaluate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_prompting) {
      _evaluate();
    }
  }

  Future<void> _evaluate() async {
    final AppLockService svc = ref.read(appLockServiceProvider);
    final bool needed = await svc.shouldPrompt();
    if (!mounted) return;

    setState(() {
      _locked = needed;
      _checking = false;
    });
    if (needed) await _unlock();
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;

    final AppLockService svc = ref.read(appLockServiceProvider);
    final bool ok = await svc.authenticate(reason: 'Unlock Builder CRM');
    if (ok) await svc.markUnlocked();

    _prompting = false;
    if (!mounted) return;
    setState(() => _locked = !ok);
  }

  @override
  Widget build(BuildContext context) {
    // Hold the UI blank during the first check so protected content never
    // flashes before the lock decides.
    if (_checking) {
      return const ColoredBox(
        color: Color(0xFFFCFCFD),
        child: SizedBox.expand(),
      );
    }

    return Stack(
      children: <Widget>[
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(onUnlock: _unlock),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.xl),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text(
                '${AppConstants.appName} is locked',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Verify to see your business records.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.xxl),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
