import 'package:flutter/material.dart';
import 'package:z_ai/models/image_result.dart';

class ResultGrid extends StatelessWidget {
  final List<ImageResult> images;
  final ValueChanged<int>? onItemTap;
  final VoidCallback? onClear;

  const ResultGrid({
    super.key,
    required this.images,
    this.onItemTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '生成结果',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (onClear != null)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清除'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return GestureDetector(
              onTap: onItemTap != null ? () => onItemTap!(index) : null,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      image.imageData,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.broken_image,
                            color: Theme.of(context).colorScheme.error,
                            size: 32,
                          ),
                        );
                      },
                    ),
                    const Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(
                        Icons.save_alt,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
