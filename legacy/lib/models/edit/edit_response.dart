import '../generate/generate_response.dart';

class EditResponse {
  final List<ImageData> data;
  final String? error;

  EditResponse({
    required this.data,
    this.error,
  });

  bool get hasError => error != null && error!.isNotEmpty;

  factory EditResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return EditResponse(
      data: dataList.map((e) => ImageData.fromJson(e as Map<String, dynamic>)).toList(),
      error: json['error']?['message'] as String?,
    );
  }
}
