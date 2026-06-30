import '../config/api_config.dart';

class Validators {
  Validators._();

  static String? validatePrompt(String? value, {bool isEdit = false}) {
    if (value == null || value.trim().isEmpty) {
      return isEdit ? '请输入编辑描述' : '请输入提示词';
    }

    final maxLength = isEdit
        ? ApiConfig.maxEditPromptLength
        : ApiConfig.maxPromptLength;

    if (value.length > maxLength) {
      return '提示词不能超过 $maxLength 字符';
    }

    return null;
  }

  static String? validateApiKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入 API Key';
    }

    if (value.length < 10) {
      return 'API Key 格式不正确';
    }

    return null;
  }

  static String? validateBaseUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入 Base URL';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Base URL 格式不正确';
    }

    return null;
  }

  static String? validateCount(int? value) {
    if (value == null) {
      return '请选择生成数量';
    }

    if (value < ApiConfig.minGenerateCount ||
        value > ApiConfig.maxGenerateCount) {
      return '生成数量必须在 ${ApiConfig.minGenerateCount}-${ApiConfig.maxGenerateCount} 之间';
    }

    return null;
  }
}
