import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final double? progress;
  final String? label;

  const LoadingIndicator({
    super.key,
    this.progress,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (label != null) ...[
        Text(label!, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
      ],
      if (progress != null)
        LinearProgressIndicator(value: progress)
      else
        const LinearProgressIndicator(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
