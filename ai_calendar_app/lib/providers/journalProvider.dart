import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ai_calendar_app/models/journalModel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalProvider with ChangeNotifier {
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  RecorderController recorderController = RecorderController();
  PlayerController playerController = PlayerController();
  Directory? appDirectory;
  String? path;
  TextEditingController titleController = TextEditingController();
  TextEditingController contentController = TextEditingController();
  JournalProvider() {
    _requestPermission();
    _initialiseControllers();
    _getDir();
  }

  Future<bool> _requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  List<JournalEntry> journalEntries = [];
  void setAudioPaths(List<String> paths) {
    notifyListeners();
  }

  Future<void> addJournalEntry(JournalEntry entry) async {
    journalEntries.add(entry);
    await saveJournalEntries();
  }

  Future<void> saveJournalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData =
        jsonEncode(journalEntries.map((e) => e.toMap()).toList());
    await prefs.setString('journalEntries', encodedData);
  }

  Future<List<JournalEntry>> loadJournalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    String? entriesString = prefs.getString('journalEntries');
    if (entriesString != null) {
      Iterable decoded = jsonDecode(entriesString);
      journalEntries = decoded.map((e) => JournalEntry.fromMap(e)).toList();
      print(journalEntries);
      return journalEntries.reversed.toList();
    }
    return [];
  }

  void updateJournalEntry(JournalEntry updatedEntry) {
    int index =
        journalEntries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      journalEntries[index] = updatedEntry;
      saveJournalEntries(); // This will persist the updated entries list
      notifyListeners();
    } else {
      addJournalEntry(updatedEntry); // Adds new entry if it doesn't exist
    }
  }

  //delete journal
  void deleteJournalEntry(JournalEntry entry) {
    int index = journalEntries.indexWhere((entry) => entry.id == entry.id);
    if (index != -1) {
      journalEntries.removeAt(index);
      saveJournalEntries(); // This will persist the updated entries list
      notifyListeners();
    }
  }

  void _initialiseControllers() {
    recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
    notifyListeners();
  }

  Future<void> _getDir() async {
    appDirectory = await getApplicationDocumentsDirectory();
    path = "${appDirectory!.path}/recording.m4a";
    notifyListeners();
  }

  Future<List<String>> pickImage() async {
    final imagePicker = ImagePicker();
    final pickedImages = await imagePicker.pickMultiImage();
    return pickedImages.map((e) => e.path).toList();
  }

  List<String> _audioPaths = [];
//delete recording
  Future<void> deleteRecording(String path) async {
    _audioPaths.remove(path);
    await File(path).delete();

    notifyListeners();
  }

  Future<String?> startOrStopRecording(List<String> currentPaths) async {
    await _requestPermission();
    String? path;
    if (_isRecording) {
      // Stop recording
      path = await recorderController.stop();
      _isRecording = false;
      if (path != null) {
        _audioPaths.add(path);
      }
    } else {
      // Start recording
      final newPath =
          "${appDirectory!.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a";
      await recorderController.record(path: newPath);
      _isRecording = true;
      // Do not add to _audioPaths here, wait for recording to stop
    }
    notifyListeners();
    return path; // Return the path where recording was saved, or null
  }

  String? _currentlyPlayingPath;
  bool _isCurrentlyPlaying = false;

  String? get currentlyPlayingPath => _currentlyPlayingPath;
  bool get isCurrentlyPlaying => _isCurrentlyPlaying;

  Future<void> toggleAudioPlayback(String path) async {
    playerController.preparePlayer(path: path);
    if (_currentlyPlayingPath == path && _isCurrentlyPlaying) {
      await playerController.pausePlayer();
      _isCurrentlyPlaying = false;
    } else {
      if (_currentlyPlayingPath != path) {
        await playerController.stopPlayer(); // Stop any currently playing audio
        await playerController.preparePlayer(
            path: path, shouldExtractWaveform: true);
      }
      await playerController.startPlayer();
      _currentlyPlayingPath = path;
      _isCurrentlyPlaying = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    recorderController.dispose();
    playerController.dispose();
    super.dispose();
  }
}
