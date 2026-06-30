class GenerateRequest {
  final String model;
  final String prompt;
  final int n;
  final String size;
  final String quality;
  final String format;

  GenerateRequest({
    required this.model,
    required this.prompt,
    required this.n,
    required this.size,
    required this.quality,
    required this.format,
  });

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'prompt': prompt,
      'n': n,
      'size': size,
      'quality': quality,
      'format': format,
    };
  }
}
