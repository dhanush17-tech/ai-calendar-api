import 'dart:convert';
import 'dart:math';

import 'package:ai_calendar_app/models/chatModel.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_neat_and_clean_calendar/neat_and_clean_calendar_event.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class AIFunctions with ChangeNotifier {
  List<NeatCleanCalendarEvent> _events = [];
  final String _apiBaseUrl = "https://55b6-153-33-8-31.ngrok-free.app";
  String accessToken = '';
  String refreshToken = '';
  bool _lastInputWasSpeech = false;
  List todoEvents = [];
  setTodoEvents(todoEvents) {
    this.todoEvents = todoEvents;
    notifyListeners();
  }

 
  setLastInputWasSpeech(bool value) {
    _lastInputWasSpeech = value;
    notifyListeners();
  }

  bool get lastInputWasSpeech => _lastInputWasSpeech;

  FlutterTts flutterTts = FlutterTts();
  List<ChatMessage> _messages = [];
  setMessages(List<ChatMessage> messages) {
    _messages = messages;
    notifyListeners();
  }

  AIFunctions() {
    _initializeTts();
  }
  TextEditingController controller = TextEditingController();

  List jsonEvents = [];

  List<ChatMessage> get messages => _messages;

  List<NeatCleanCalendarEvent> get events => _events;

  Map<String, dynamic> _eventIsDoneMap = {};
  Map<String, dynamic> get eventIsDoneMap => _eventIsDoneMap;

  setEventIsDone(String id, bool isDone) {
    _eventIsDoneMap[id] = isDone;
    storeTodoList();
    notifyListeners();
  }
 

  bool _isMicOn = false;
  bool get isMicOn => _isMicOn;
  get http => null;
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;
  setSelectedDate(DateTime value) {
    _selectedDate = value;
    notifyListeners();
  }

  void setAuthTokens(String accessToken, String refreshToken) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  String stripMarkdown(String markdown) {
    // Replace bold text with plain text
    markdown = markdown.replaceAll(RegExp(r'\*\*(.+?)\*\*'), '');
    markdown = markdown.replaceAll(RegExp('__(.+?)__'), '');

    // Replace italicized text with plain text
    markdown = markdown.replaceAll(RegExp('_(.+?)_'), '');
    markdown = markdown.replaceAll(RegExp(r'\*(.+?)\*'), '');

    // Replace strikethrough text with plain text
    markdown = markdown.replaceAll(RegExp('~~(.+?)~~'), '');

    // Replace inline code blocks with plain text
    markdown = markdown.replaceAll(RegExp('`(.+?)`'), '');

    // Replace code blocks with plain text
    markdown =
        markdown.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
    markdown =
        markdown.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');

    // Remove links
    markdown = markdown.replaceAll(RegExp(r'\[(.+?)\]\((.+?)\)'), '');

    // Remove images
    markdown = markdown.replaceAll(RegExp(r'!\[(.+?)\]\((.+?)\)'), '');

    // Remove headings
    markdown =
        markdown.replaceAll(RegExp(r'^#+\s+(.+?)\s*$', multiLine: true), '');
    markdown = markdown.replaceAll(RegExp(r'^\s*=+\s*$', multiLine: true), '');
    markdown = markdown.replaceAll(RegExp(r'^\s*-+\s*$', multiLine: true), '');

    // Remove blockquotes
    markdown =
        markdown.replaceAll(RegExp(r'^\s*>\s+(.+?)\s*$', multiLine: true), '');

    // Remove lists
    markdown = markdown.replaceAll(
      RegExp(r'^\s*[\*\+-]\s+(.+?)\s*$', multiLine: true),
      '',
    );
    markdown = markdown.replaceAll(
      RegExp(r'^\s*\d+\.\s+(.+?)\s*$', multiLine: true),
      '',
    );

    // Remove horizontal lines
    markdown =
        markdown.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');

    return markdown;
  }

  Future loadConversations(GlobalKey<AnimatedListState> listKey) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? convo = prefs.getString("convo");
    if (convo != null) {
      setMessages(List<ChatMessage>.from(List<ChatMessage>.generate(
          json.decode(convo).length,
          (index) => ChatMessage.fromJson(json.decode(convo)[index]))));
    }
    listKey.currentState!.insertAllItems(0, _messages.length);
    print(convo);
    notifyListeners();
  }

  Future saveConversations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(
        "convo",
        jsonEncode(List.generate(
            _messages.length, (index) => _messages[index].toJson())));
  }

  Future<String> getCurrentTimeZone() async {
    final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    return timeZoneName;
  }

  Future<List> eventsForSelectedDay(
    DateTime date,
  ) async {
    // Make sure timezone data is initialized
    tz.initializeTimeZones();
    String localTimeZone = await getCurrentTimeZone();
    // await fetchEvents();
    // Assuming jsonEvents is a list of events with their respective timezones
    List<dynamic> events = jsonEvents.where((event) {
      // Parse the start date as UTC
      DateTime startDateUtc = DateTime.parse(event['startDate']).toUtc();
      // Get the event's timezone
      String eventTimeZone = event['timeZone'];

      // Convert the start date to the event's local timezone
      final location = tz.getLocation(eventTimeZone);
      final startDateLocal = tz.TZDateTime.from(startDateUtc, location);

      // Convert the start date to the user's local timezone for comparison
      final userLocation = tz.getLocation(localTimeZone);
      final userLocalDate = tz.TZDateTime.from(startDateLocal, userLocation);

      // Use only the date part for comparison
      return DateUtils.dateOnly(userLocalDate) == DateUtils.dateOnly(date);
    }).toList()
      // Sort events by startDate considering the user's local timezone
      ..sort((a, b) {
        DateTime aStartDateUtc = DateTime.parse(a['startDate']).toUtc();
        DateTime bStartDateUtc = DateTime.parse(b['startDate']).toUtc();

        final aLocation = tz.getLocation(a['timeZone']);
        final bLocation = tz.getLocation(b['timeZone']);

        final aStartDateLocal =
            tz.TZDateTime.from(aStartDateUtc, tz.getLocation(localTimeZone));
        final bStartDateLocal =
            tz.TZDateTime.from(bStartDateUtc, tz.getLocation(localTimeZone));

        final aUserLocalDate =
            tz.TZDateTime.from(aStartDateLocal, tz.getLocation(localTimeZone));
        final bUserLocalDate =
            tz.TZDateTime.from(bStartDateLocal, tz.getLocation(localTimeZone));

        return aUserLocalDate.compareTo(bUserLocalDate);
      });

    return events;
  }

  Future<void> _initializeTts() async {
    List<Object?> voices = await flutterTts.getVoices;
    List<String> jsonVoices = voices.map((e) => jsonEncode(e)).toList();
    List availVoices = jsonVoices.map((e) => jsonDecode(e)).toList();
    flutterTts.setVoice(
        {'name': availVoices[0]['name'], 'locale': availVoices[0]['locale']});
    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.0);
  }

  void textToSpeech(String text) async {
    // Your existing speech to text logic...
    _lastInputWasSpeech = true; // Set the flag when speech input is captured
    // Rest of your speech-to-text logic
    await flutterTts.speak(text);
  }

  void initializeTimeZones() => tz.initializeTimeZones();

  String formatDateTime(String isoDateTime, String timeZoneStr) {
    initializeTimeZones();

    DateTime parsedDateTime = DateTime.parse(isoDateTime);

    final location = tz.getLocation(timeZoneStr);

    final tzDateTime = tz.TZDateTime.from(parsedDateTime, location);

    DateFormat dateFormat = DateFormat('hh:mm a', 'en_US');

    String formattedDate = dateFormat.format(tzDateTime);

    return formattedDate;
  }

  Future<void> scheduleNotifications() async {
    for (var eventData in jsonEvents) {
      if (!jsonEvents.contains(eventData)) {
        DateTime startTime = DateTime.parse(eventData['startDate']);
        String title = eventData['title'];
        String description =
            eventData['description'] ?? 'You have an upcoming event';
        String? meetingLink = eventData['meetingLink'];

        // Calculate reminder time (10 minutes before the event)
        DateTime reminderTime = startTime;

        int notificationId =
            DateTime.now().millisecondsSinceEpoch.remainder(100000);

        // Define action buttons
        List<NotificationActionButton> buttons = [];
        if (meetingLink != null && meetingLink.isNotEmpty) {
          buttons.add(NotificationActionButton(
            key: 'OPEN_MEETING',
            label: 'Join Meeting',
            actionType: ActionType.Default,
          ));
        }

        // Scheduling the notification
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'alerts',
            title: title,
            body: description +
                "\nLet's get going ${["🚀", "😎", "🤘"][Random().nextInt(3)]}",
            notificationLayout: NotificationLayout.Default,
            payload: {'meetingLink': meetingLink ?? ''},
          ),
          actionButtons: buttons,
          schedule: NotificationCalendar.fromDate(date: reminderTime),
        );
      }
    }
  }

  void sendMessage(String prompt, GlobalKey<AnimatedListState> listKey) {
    int newIndex = _messages.length;
    ChatMessage newUserMessage = ChatMessage(text: prompt, isUserMessage: true);
    _messages.add(newUserMessage);
    listKey.currentState
        ?.insertItem(newIndex, duration: Duration(milliseconds: 500));

    int loadingIndex = _messages.length;
    ChatMessage loadingMessage =
        ChatMessage(text: 'Loading...', isUserMessage: false, isLoading: true);
    _messages.add(loadingMessage);
    listKey.currentState
        ?.insertItem(loadingIndex, duration: Duration(milliseconds: 500));

    notifyListeners();

    sendConversations(prompt).then((response) {
      _messages.removeAt(loadingIndex);
      listKey.currentState?.removeItem(
          loadingIndex,
          (context, animation) =>
              SizeTransition(sizeFactor: animation, child: Container()),
          duration: Duration(milliseconds: 250));

      ChatMessage responseMessage =
          ChatMessage(text: response, isUserMessage: false, isLoading: false);
      _messages.add(responseMessage);
      listKey.currentState?.insertItem(_messages.length - 1,
          duration: Duration(milliseconds: 500));

      notifyListeners();
      saveConversations(); // Move saveConversations call here
      if (_lastInputWasSpeech == true) {
        textToSpeech(stripMarkdown(response));
        _lastInputWasSpeech = false;
        notifyListeners();
      }
    }).catchError((error) {
      _messages.removeAt(loadingIndex);
      listKey.currentState?.removeItem(
          loadingIndex,
          (context, animation) =>
              SizeTransition(sizeFactor: animation, child: Container()),
          duration: Duration(milliseconds: 250));
      //add try that again
      ChatMessage responseMessage = ChatMessage(
          text: "Sorry, I couldn't process that. Please try again.",
          isUserMessage: false,
          isLoading: false);
      _messages.add(responseMessage);
      listKey.currentState?.insertItem(_messages.length - 1,
          duration: Duration(milliseconds: 500));
      notifyListeners();
    });
  }

  speechToText() async {
    stt.SpeechToText speech = stt.SpeechToText();
    bool available = await speech.initialize(
      onStatus: (status) {
        print('Result listener final: ${status}');
        if (status == 'listening') {
          // When the speech to text starts listening, set isMicOn to true
          _isMicOn = true;
          notifyListeners();
        } else if (status == 'done') {
          // When the speech to text stops listening, set isMicOn to false
          _isMicOn = false;
          notifyListeners();
        }
      },
    );
    if (available) {
      speech.listen(
          pauseFor: Duration(seconds: 5),
          onResult: (text) {
            print('Received speech recognition result: $text');
            controller.text = text.recognizedWords;
            notifyListeners();
          });
    }
  }

  Future<void> loadTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final todoList = prefs.getString('todoList');
    if (todoList != null) {
      _eventIsDoneMap = json.decode(todoList);
    }
  }

  Future<void> storeTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todoList', json.encode(_eventIsDoneMap));
  }

  Future<void> fetchEvents() async {
    try {
      final response = await Dio().post(
        '$_apiBaseUrl/listEvents',
        data: {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsData = response.data['events'];
        jsonEvents = eventsData;

        _events = eventsData.map((eventData) {
          if (_eventIsDoneMap[eventData['id']] == null) {
            _eventIsDoneMap[eventData['id']] = false;
          }

          DateTime startTime = DateTime.parse(eventData['startDate']);

          DateTime endTime = DateTime.parse(eventData['endDate']);
          return NeatCleanCalendarEvent(eventData['title'],
              description: eventData['description'],
              startTime: startTime,
              endTime: endTime,
              color: Colors.blue,
              isMultiDay: startTime.day != endTime.day,
              metadata: {
                "startDate": formatDateTime(
                    eventData['startDate'], eventData['timeZone']),
                "endDate":
                    formatDateTime(eventData['endDate'], eventData['timeZone'])
              });
        }).toList();
        //iterate throught events and set the isDone value to what is already is and if the eventId dosent exist add it and set the value to fasle

        notifyListeners();
      } else {
        throw Exception('Failed to load events');
      }
    } catch (e) {
      print("Error fetching events: $e");
    }
  }

  Future sendConversations(String prompt) async {
    await fetchEvents();
    print(accessToken);
    print(refreshToken);

    try {
      final response = await Dio().post('$_apiBaseUrl/chat', data: {
        "prompt": prompt,
        "accessToken": accessToken,
        "refreshToken": refreshToken,
        "context": jsonEncode(
          List.generate(
            _messages.length < 15 ? _messages.length : 15,
            (index) => _messages[_messages.length - 15 + index].toJson(),
          ),
        ),
        "events": jsonEvents,
      });

      print(response.data);
      if (response.statusCode == 200) {
        print("Event created successfully");
        return response.data["message"]; // Refresh events after creation
      } else {
        print("Failed to create event: ${response.data}");
      }
    } catch (e) {
      print("Error creating event: $e");
    }

    return "";
  }
}
