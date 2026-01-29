import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Save file to Downloads folder (Android/iOS/Desktop)
Future<String?> saveFile(Uint8List bytes, String fileName) async {
  try {
    // Get downloads directory (or app documents as fallback)
    final directory = await getDownloadsDirectory() ?? 
                      await getApplicationDocumentsDirectory();
    
    final filePath = '${directory.path}/$fileName';
    
    // Write file
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    return filePath;
  } catch (e) {
    return null;
  }
}
