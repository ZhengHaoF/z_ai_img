import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/network_log.dart';
import '../providers/network_log_provider.dart';

class NetworkLogDialog extends ConsumerStatefulWidget {
  const NetworkLogDialog({super.key});

  @override
  ConsumerState<NetworkLogDialog> createState() => _NetworkLogDialogState();
}

class _NetworkLogDialogState extends ConsumerState<NetworkLogDialog> {
  NetworkLogType? _filterType;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(networkLogProvider);
    final filteredLogs = _filterType == null
        ? logs
        : logs.where((log) => log.type == _filterType).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Text('网络请求日志'),
          const Spacer(),
          PopupMenuButton<NetworkLogType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterType = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              const PopupMenuItem(
                value: NetworkLogType.request,
                child: Text('请求'),
              ),
              const PopupMenuItem(
                value: NetworkLogType.response,
                child: Text('响应'),
              ),
              const PopupMenuItem(
                value: NetworkLogType.error,
                child: Text('错误'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(networkLogProvider.notifier).clearLogs();
            },
            tooltip: '清空日志',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: filteredLogs.isEmpty
            ? const Center(
                child: Text('暂无日志'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: filteredLogs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  return _LogTile(log: log);
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _LogTile extends StatefulWidget {
  final NetworkLog log;

  const _LogTile({required this.log});

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  Color get _typeColor {
    switch (widget.log.type) {
      case NetworkLogType.request:
        return Colors.blue;
      case NetworkLogType.response:
        return Colors.green;
      case NetworkLogType.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.typeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _typeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.method,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (log.statusCode != null) ...[
            Text(
              '${log.statusCode}',
              style: TextStyle(
                fontSize: 12,
                color: log.statusCode! >= 200 && log.statusCode! < 300
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            log.formattedTime,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          log.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (log.duration != null) ...[
                _buildInfoRow('耗时', '${log.duration!.inMilliseconds}ms'),
                const SizedBox(height: 4),
              ],
              if (log.headers != null) ...[
                _buildSectionTitle('Headers'),
                const SizedBox(height: 4),
                _buildJsonPreview(log.headers!),
                const SizedBox(height: 8),
              ],
              if (log.data != null) ...[
                _buildSectionTitle('Body'),
                const SizedBox(height: 4),
                _buildJsonPreview(log.data!),
              ],
              if (log.errorMessage != null) ...[
                _buildSectionTitle('错误信息'),
                const SizedBox(height: 4),
                Text(
                  log.errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildJsonPreview(dynamic data) {
    try {
      final jsonStr = data.toString();
      return SelectableText(
        jsonStr.length > 500 ? '${jsonStr.substring(0, 500)}...' : jsonStr,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      );
    } catch (e) {
      return Text(
        data.toString(),
        style: const TextStyle(fontSize: 11),
      );
    }
  }
}
