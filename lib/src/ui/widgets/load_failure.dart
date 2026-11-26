import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shown when the local diary database could not be opened or read.
///
/// The most common cause is a platform where SQLite is not wired up, so the
/// message names that possibility instead of only printing the raw exception.
class LoadFailure extends StatelessWidget {
  const LoadFailure({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Fikk ikke åpnet dagboken',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Den lokale databasen kunne ikke startes i nettleseren. '
                        'Appen er laget for mobil — prøv Android eller iOS for '
                        'full funksjonalitet.'
                  : 'Den lokale databasen kunne ikke åpnes på denne plattformen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // The raw error is kept visible: without it a platform problem is
            // almost impossible to diagnose from a screenshot.
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Prøv igjen'),
            ),
          ],
        ),
      ),
    );
  }
}
