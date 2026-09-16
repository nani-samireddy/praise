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
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.changeRole ? 'Change role' : 'Welcome to Praise',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.changeRole
                      ? 'Choose a role to update your feature defaults.'
                      : 'Choose how you use Praise. You can change these features later in Settings.',
                ),
                const SizedBox(height: 28),
                for (final role in PrimaryRole.values) _role(context, role),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () async {
                          await ref
                              .read(featureSettingsStoreProvider)
                              .complete(selected!);
                          if (context.mounted) context.go('/songs');
                        },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _role(BuildContext context, PrimaryRole role) {
    final labels = {
      PrimaryRole.singer: 'Singer',
      PrimaryRole.musician: 'Musician',
      PrimaryRole.worshipLeader: 'Worship leader',
    };
    final icons = {
      PrimaryRole.singer: Icons.mic,
      PrimaryRole.musician: Icons.music_note,
      PrimaryRole.worshipLeader: Icons.groups,
    };
    return Card(
      color: selected == role
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ListTile(
        leading: Icon(icons[role]),
        title: Text(labels[role]!),
        subtitle: Text(
          role == PrimaryRole.singer
              ? 'Lyrics and singing'
              : role == PrimaryRole.musician
              ? 'Chords and tempo'
              : 'Lists and service planning',
        ),
        trailing: selected == role ? const Icon(Icons.check) : null,
        onTap: () => setState(() => selected = role),
      ),
    );
  }
}
