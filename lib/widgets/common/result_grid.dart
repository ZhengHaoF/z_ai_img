import 'package:flutter/material.dart';
import 'package:z_ai/models/image_result.dart';

class ResultGrid extends StatelessWidget {
  final List<ImageResult> images;
  final ValueChanged<int>? onItemTap;

  /// 保存单张图片。为 null 时不渲染保存按钮
  /// （此前这里是一个不可点击的装饰图标，会误导用户以为能保存）。
  final ValueChanged<int>? onItemSave;
  final VoidCallback? onClear;
  final String title;

  const ResultGrid({
    super.key,
    required this.images,
    this.onItemTap,
    this.onItemSave,
    this.onClear,
    this.title = '生成结果',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      cacheWidth: 400,
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
                    if (onItemSave != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            icon: const Icon(
                              Icons.save_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                            tooltip: '保存到本地',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            onPressed: () => onItemSave!(index),
                          ),
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
