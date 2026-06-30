import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> platformSaveImage(Uint8List imageData, String fileName) async {
  try {
    final blob = html.Blob([imageData], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}
