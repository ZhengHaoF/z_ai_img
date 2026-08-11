import 'package:flutter/material.dart';
import '../../models/image_result.dart';
import '../common/empty_state.dart';
import '../common/error_banner.dart';
import '../common/feedback.dart';
import '../common/result_grid.dart';

/// 共享的「结果区」组件：空态 / 错误横幅 / 结果网格三态，
/// generate / edit 页面共用，消除重复的结果渲染逻辑。
class ResultSection extends StatelessWidget {
  final List<ImageResult> images;
  final String title;
  final String? error;
  final bool isLoading;
  final ValueChanged<int>? onItemTap;
  final ValueChanged<int>? onItemSave;
  final VoidCallback? onClear;
  final IconData emptyIcon;
  final String emptyTitle;

  const ResultSection({
    super.key,
    required this.images,
    this.title = '生成结果',
    this.error,
    required this.isLoading,
    this.onItemTap,
    this.onItemSave,
    this.onClear,
    required this.emptyIcon,
    required this.emptyTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      if (isLoading) return const SizedBox.shrink();
      if (error != null) return _buildErrorState(context, error!);
      return EmptyState(icon: emptyIcon, title: emptyTitle);
    }

    final children = <Widget>[];
    if (error != null) {
      children.add(_buildErrorState(context, error!));
      children.add(const SizedBox(height: 12));
    }
    children.add(
      ResultGrid(
        images: images,
        title: title,
        onItemTap: onItemTap,
        onItemSave: onItemSave,
        onClear: onClear,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return ErrorBanner(
      message: message,
      onCopy: () => copyTextWithFeedback(context, message),
    );
  }
}
