import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/feature_flags.dart';
import 'feature_providers.dart';

class StarterScreen extends ConsumerStatefulWidget {
  const StarterScreen({super.key, this.changeRole = false});
  final bool changeRole;
  @override
  ConsumerState<StarterScreen> createState() => _StarterScreenState();
}

class _StarterScreenState extends ConsumerState<StarterScreen> {
  PrimaryRole? selected;
  bool saving = false;

  void _cancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  Future<void> _continue() async {
    setState(() => saving = true);
    try {
      await ref.read(featureSettingsStoreProvider).complete(selected!);
      if (!mounted) return;
      if (widget.changeRole) {
        _cancel();
      } else {
        context.go('/songs');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your role. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.changeRole && !saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && widget.changeRole && !saving) _cancel();
    },
    child: Scaffold(
      appBar: widget.changeRole
          ? AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: 'Cancel role change',
                onPressed: saving ? null : _cancel,
                icon: const Icon(Icons.close),
              ),
              title: const Text('Change role'),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: FocusTraversalGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.changeRole
                            ? 'Choose your role'
                            : 'Welcome to Praise',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.changeRole
                            ? 'Choose the role that best describes you. All tools remain available for every role.'
                            : 'Choose how you use Praise. All tools are available for every role.',
                      ),
                      const SizedBox(height: 28),
                      for (final role in PrimaryRole.values)
                        _role(context, role),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: selected == null || saving
                            ? null
                            : _continue,
                        child: Text(saving ? 'Saving…' : 'Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _role(BuildContext context, PrimaryRole role) {
    final icon = switch (role) {
      PrimaryRole.singer => Icons.mic,
      PrimaryRole.musician => Icons.music_note,
      PrimaryRole.worshipLeader => Icons.groups,
    };
    final description = switch (role) {
      PrimaryRole.singer => 'Lyrics and singing',
      PrimaryRole.musician => 'Chords and tempo',
      PrimaryRole.worshipLeader => 'Lists and service planning',
    };
    return Semantics(
      selected: selected == role,
      child: Card(
        color: selected == role
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: ListTile(
          enabled: !saving,
          selected: selected == role,
          leading: Icon(icon),
          title: Text(role.label),
          subtitle: Text(description),
          trailing: selected == role ? const Icon(Icons.check) : null,
          onTap: saving ? null : () => setState(() => selected = role),
        ),
      ),
    );
  }
}
