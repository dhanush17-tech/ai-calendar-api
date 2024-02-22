import 'dart:convert';

import 'package:image_picker/image_picker.dart';

class JournalEntry {
  String title;
  String content;
  List<String> imagePaths;
  List<String> audioPaths;
  String id;

  JournalEntry({
    required this.title,
    required this.content,
    required this.imagePaths,
    required this.audioPaths,
    String? id,
  }) : id = id ?? DateTime.now().toIso8601String();

  // Convert a JournalEntry into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'imagePaths': imagePaths.join(','),
      'audioPaths': audioPaths.join(','),
      'id': id,
    };
  }

  // Implement a method to deserialize a map as a JournalEntry
  static JournalEntry fromMap(Map<String, dynamic> map) {
    var imagePathsString = map['imagePaths'] as String;
    var audioPathsString = map['audioPaths'] as String;

    // Convert the comma-separated string back into a List<String>
    List<String> imagePaths =
        imagePathsString.split(',').where((path) => path.isNotEmpty).toList();
    List<String> audioPaths =
        audioPathsString.split(',').where((path) => path.isNotEmpty).toList();

    print(map['imagePaths']);
    print(map['audioPaths']);
    return JournalEntry(
      title: map['title'],
      content: map['content'],
      imagePaths: imagePaths,
      audioPaths: audioPaths,
      id: map['id'],
    );
  }
}
