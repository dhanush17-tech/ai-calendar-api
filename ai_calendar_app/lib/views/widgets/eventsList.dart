import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ai_calendar_app/providers/aiFunctions.dart';

class EventsList extends StatefulWidget {
  final AIFunctions aiFunctions;

  EventsList({required this.aiFunctions});

  @override
  _EventsListState createState() => _EventsListState();
}

class _EventsListState extends State<EventsList> {
  late ScrollController _scrollController; // Add a ScrollController

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(); // Initialize the ScrollController
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the ScrollController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: StreamBuilder(
        stream: widget.aiFunctions
            .eventsForSelectedDay(widget.aiFunctions.selectedDate)
            .asStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(); // Loading indicator while waiting for data
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}')); // Error state
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.builder(
              shrinkWrap: true,
              controller: _scrollController, // Use the ScrollController here
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                var event = snapshot.data![index];
                bool isCompleted =
                    widget.aiFunctions.eventIsDoneMap[event['id']] ?? false;
                return buildEventTile(event, isCompleted, widget.aiFunctions);
              },
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(child: Text('No events')), // No data state
            );
          }
        },
      ),
    );
  }

  Widget buildEventTile(var event, bool isCompleted, AIFunctions aiFunctions) {
    return GestureDetector(
      onTap: () {
        if (event['meetingLink'] != "") {
          launch(event['meetingLink']);
        }
        aiFunctions.setEventIsDone(event['id'], !isCompleted);
      },
      child: Container(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event["title"],
                  style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                ),
                Text(
                  "${aiFunctions.formatDateTime(event['startDate'], event["timeZone"])} - ${aiFunctions.formatDateTime(event['endDate'], event["timeZone"])}",
                  style: Theme.of(context).textTheme.bodyText2?.copyWith(
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                ),
              ],
            ),
            event['meetingLink'] != ""
                ? Icon(Icons.videocam)
                : Container(
                    width: 30,
                    child: Checkbox(
                      value: isCompleted,
                      onChanged: (bool? newValue) {
                        aiFunctions.setEventIsDone(event['id'], newValue!);
                        // Force a rebuild or notify listeners to refresh the UI
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
