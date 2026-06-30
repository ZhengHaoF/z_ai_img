import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/image_result.dart';
import '../../utils/image_utils.dart';

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
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareImage(),
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  onPressed: () => _saveImage(),
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
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    final currentImage = widget.images[_currentIndex];
    final success = await ImageUtils.saveImage(currentImage.imageData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '保存成功' : '保存失败'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _shareImage() async {
    // TODO: 实现分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('分享功能开发中'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
