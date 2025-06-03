import 'dart:html' as html;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

Future<dynamic> pickFile(String type) async {
  final input = html.FileUploadInputElement()
    ..accept = type == 'photo' ? 'image/*' : 'video/*';
  input.click();
  await input.onChange.first;
  if (input.files?.isNotEmpty ?? false) {
    final file = input.files!.first;
    if (type == 'photo') {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = reader.result as Uint8List;
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');
      return file;
    }
    return file;
  }
  return null;
}
