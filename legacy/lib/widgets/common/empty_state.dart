import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
