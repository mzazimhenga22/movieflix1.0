import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

Future<dynamic> pickFile(String type) async {
  final picker = ImagePicker();
  if (type == 'photo') {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');
      return pickedFile;
    }
  } else if (type == 'video') {
    return await picker.pickVideo(source: ImageSource.gallery);
  }
  return null;
}
