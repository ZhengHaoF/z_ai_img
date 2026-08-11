import 'package:flutter/material.dart';
import '../../models/image_result.dart';
import '../../widgets/common/feedback.dart';

class ImagePreviewPage extends StatefulWidget {
  final List<ImageResult> images;
  final int initialIndex;

  const ImagePreviewPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showOverlay
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  tooltip: '保存到本地',
                  onPressed: _saveImage,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          children: [
            // 图片页面
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.memory(
                      image.imageData,
                      fit: BoxFit.contain,
                      cacheWidth: (MediaQuery.of(context).size.width *
                              MediaQuery.of(context).devicePixelRatio)
                          .round(),
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.red.withValues(alpha: 0.2),
                          child: const Icon(Icons.broken_image, color: Colors.white70, size: 48),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // 页码指示器
            if (_showOverlay && widget.images.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),

            // 页码文字
            if (_showOverlay && widget.images.length > 1)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),

            // 提示文字
            if (_showOverlay)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 0,
                right: 0,
                child: Text(
                  '双指缩放 · 点击切换',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage() {
    return saveImageWithFeedback(
      context,
      widget.images[_currentIndex].imageData,
    );
  }
}
