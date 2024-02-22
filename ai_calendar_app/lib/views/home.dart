import 'dart:convert';
import 'dart:math';

import 'package:ai_calendar_app/notificationController.dart';
import 'package:ai_calendar_app/views/journalScreen.dart';
import 'package:ai_calendar_app/views/journalHome.dart';
import 'package:ai_calendar_app/views/widgets/eventsList.dart';
import 'package:animate_do/animate_do.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_tts/flutter_tts.dart';
import "package:intl/intl.dart";
import 'package:ai_calendar_app/providers/aiFunctions.dart';
import 'package:ai_calendar_app/providers/stateProvider.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:ai_calendar_app/providers/auth.dart' as auth;
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void dispose() {
    _controller.dispose();
    _controller.removeListener(_scrollListener);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<auth.AuthProvider>(context, listen: false)
          .autoSignIn(context);
      Provider.of<AIFunctions>(context, listen: false).loadTodoList();
      Provider.of<AIFunctions>(context, listen: false)
          .loadConversations(_listKey);
    });

    AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod,
        onDismissActionReceivedMethod:
            NotificationController.onDismissActionReceivedMethod,
        onNotificationCreatedMethod:
            NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod:
            NotificationController.onNotificationDisplayedMethod);
    WidgetsFlutterBinding.ensureInitialized();
    _controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!_controller.hasClients) return;

    final bool shouldShowDownArrow =
        _controller.offset < _controller.position.maxScrollExtent;
    final bool shouldShowUpArrow =
        _controller.offset > _controller.position.minScrollExtent;
    if (shouldShowUpArrow != _showScrollUpButton) {
      setState(() {
        _showScrollUpButton = shouldShowUpArrow;
      });
    }

    if (shouldShowDownArrow != _showScrollDownButton) {
      setState(() {
        _showScrollDownButton = shouldShowDownArrow;
      });
    }
  }

  void _scrollDown() {
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeIn,
    );
  }

  void _scrollUp() {
    _controller.animateTo(
      _controller.position.minScrollExtent,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeIn,
    );
  }

  final gemini = Gemini.instance;

  Future<String> sample() async {
    await Future.delayed(Duration(seconds: 2), () async {
      return "It's gonna be great!!! You are gonna be amazing man.. keep going!";
    });
    return "It's gonna be great!!! You are gonna be amazing man.. keep going!";
  }

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  String getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else if (hour < 20) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  final ScrollController _controller = ScrollController();

  bool _showScrollDownButton = false;
  bool _showScrollUpButton = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
          child: Consumer3<auth.AuthProvider, AIFunctions, LoadingState>(
              builder:
                  (context, authProvider, aiFunctions, loadingState, child) {
            print(aiFunctions.accessToken);
            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInDown(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                //a circular container for the memoji
                                Container(
                                  alignment: Alignment.center,
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                      child: Text(
                                    "😎",
                                    style:
                                        Theme.of(context).textTheme.headline4,
                                    textAlign: TextAlign.center,
                                  )),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => JournalHome()),
                                    );
                                  },
                                  child: Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .tertiaryContainer
                                              .withOpacity(0.5)),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        color: Theme.of(context).primaryColor,
                                      )),
                                )
                                // CircleAvatar(
                                //   key: ValueKey(_key),
                                //   radius: 100,
                                //   backgroundColor: Colors.grey[200],
                                //   backgroundImage: _imagePath != null
                                //       ? FileImage(
                                //           File(
                                //             _imagePath!,
                                //           ),
                                //         )
                                //       : null,
                                // ),
                              ],
                            ),
                            SizedBox(height: 15),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  "${getGreetingMessage()} ${authProvider.displayName.split(" ")[0]}!",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headline5
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 31),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      FadeInDown(
                        child: EasyInfiniteDateTimeLine(
                          dayProps: EasyDayProps(
                            height: 130,
                          ),
                          controller: EasyInfiniteDateTimelineController(),
                          firstDate: DateTime(DateTime.now().year,
                              DateTime.now().month - 3, DateTime.now().day),
                          lastDate: DateTime(DateTime.now().year,
                              DateTime.now().month + 3, DateTime.now().day),
                          focusDate: aiFunctions.selectedDate,
                          onDateChange: (selectedDate) {
                            aiFunctions.setSelectedDate(selectedDate);
                            // Update your state to reflect the newly selected date
                          },
                          showTimelineHeader: false,
                          itemBuilder:
                              (context, a, b, c, dateTime, isSelected) {
                            return FutureBuilder<List<dynamic>>(
                              future:
                                  aiFunctions.eventsForSelectedDay(dateTime),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  // Limit the number of dots shown to prevent overflow
                                  int maxDotsToShow = 4;
                                  int eventsCount = snapshot.data!.length;
                                  List<Widget> dots = List<Widget>.generate(
                                    min(eventsCount, maxDotsToShow),
                                    (index) => Container(
                                      margin: EdgeInsets.only(right: 5),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  );

                                  // If there are more events than the maxDotsToShow, add a '+ more' indicator
                                  if (eventsCount > maxDotsToShow) {
                                    dots.add(Text(
                                        '+${eventsCount - maxDotsToShow} more',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2
                                            ?.copyWith(fontSize: 10)));
                                  }

                                  return SingleChildScrollView(
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: isSelected
                                            ? Colors.blue.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.1),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                DateFormat('EEE').format(
                                                    dateTime), // Short day name.
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              Text(
                                                dateTime.day.toString(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall,
                                              ),
                                              SizedBox(height: 5),
                                              Wrap(
                                                runSpacing: 5,
                                                alignment: WrapAlignment.center,
                                                runAlignment:
                                                    WrapAlignment.center,
                                                children: dots,
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  return Text(
                                      'No events'); // Handle the case where snapshot doesn't have data
                                }
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: FutureBuilder(
                          future: aiFunctions
                              .eventsForSelectedDay(aiFunctions.selectedDate),
                          builder: (context, snapshot) {
                            return ListView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                var event = snapshot.data![index];
                                bool isCompleted =
                                    aiFunctions.eventIsDoneMap[event['id']] ??
                                        false;
                                return AnimationLimiter(
                                  child: AnimationConfiguration.staggeredList(
                                      position: index,
                                      child: SlideAnimation(
                                          verticalOffset: 50.0,
                                          child: FadeInAnimation(
                                            duration:
                                                Duration(milliseconds: 500),
                                            child: buildEventTile(event,
                                                isCompleted, aiFunctions),
                                          ))),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      aiFunctions.messages.isEmpty
                          ? Align(
                              alignment: Alignment.center,
                              child: Text(
                                "Let's start planning your day!",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    ?.copyWith(
                                        fontSize: 25,
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.bold),
                              ),
                            )
                          : FadeIn(
                              child: AnimatedList(
                                key: _listKey,
                                physics: NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                initialItemCount:
                                    aiFunctions.messages.length ?? 0,
                                itemBuilder: (context, index, animation) {
                                  final curvedAnimation = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves
                                        .easeInOut, // Use the easeIn curve
                                    // Optionally, you can specify a reverseCurve if needed
                                  );

                                  final msg = aiFunctions.messages[index];
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 1),
                                      end: Offset.zero,
                                    ).animate(curvedAnimation),
                                    child: Align(
                                      alignment: msg.isUserMessage
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: msg.isLoading
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Shimmer.fromColors(
                                                enabled: true,
                                                child: Container(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width -
                                                      100,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                      color: Colors.black,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20)),
                                                ),
                                                baseColor: Colors.grey
                                                    .withOpacity(0.5),
                                                highlightColor: Colors.grey
                                                    .withOpacity(0.2),
                                              ),
                                            )
                                          : msg.isUserMessage
                                              ? Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Container(
                                                      decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          gradient:
                                                              LinearGradient(
                                                            // center: Alignment.center,
                                                            // radius: 03,
                                                            begin: Alignment
                                                                .bottomLeft,
                                                            end: Alignment
                                                                .bottomLeft,
                                                            stops: [0.0, 1.0],
                                                            colors: [
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .inversePrimary
                                                                  .withOpacity(
                                                                      0.2),
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .inversePrimary
                                                                  .withOpacity(
                                                                      0.1),
                                                            ],
                                                          )),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10,
                                                      ),
                                                      constraints: BoxConstraints(
                                                          maxWidth: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.7),
                                                      child: Container(
                                                        child: SelectableText(
                                                          msg.text,
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText1
                                                              ?.copyWith(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .primaryColor!),
                                                        ),
                                                      )),
                                                )
                                              : Markdown(
                                                  data: msg.text,
                                                  selectable: true,
                                                  onTapLink:
                                                      (text, href, title) {
                                                    launch(href!);
                                                  },
                                                  styleSheet:
                                                      MarkdownStyleSheet(),
                                                  physics:
                                                      NeverScrollableScrollPhysics(),
                                                  shrinkWrap: true,
                                                ),
                                    ),
                                  );
                                },
                              ),
                            ),
                      SizedBox(
                        height: 120,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 80, // Adjust the height to control the fade area
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Theme.of(context)
                              .scaffoldBackgroundColor, // Assuming this is your background color
                          Theme.of(context)
                              .scaffoldBackgroundColor
                              .withOpacity(0), // Transparent
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ChatInputBox(
                        onClickCamera: () {
                          aiFunctions.speechToText();
                          aiFunctions.setLastInputWasSpeech(true);
                        },
                        controller: aiFunctions.controller,
                        onSend: () async {
                          // aiFunctions.sendMessage(
                          //     "Hows my life gonna be", sample(), _listKey);
                          // AwesomeNotifications().createNotification(
                          //     content: NotificationContent(
                          //   id: 1,
                          //   title: "Hello",
                          //   body: "This is a test",
                          //   channelKey: 'alerts',
                          // ));
                          _scrollDown();
                          print(
                            jsonEncode(
                              List.generate(
                                  aiFunctions.messages.length,
                                  (index) =>
                                      aiFunctions.messages[index].toJson()),
                            ),
                          );
                          if (aiFunctions.controller.text.isNotEmpty) {
                            String userText = aiFunctions.controller.text;

                            aiFunctions.sendMessage(userText, _listKey);
                          }
                          _scrollDown();
                          setState(() {
                            aiFunctions.controller.clear();
                            aiFunctions
                                .eventsForSelectedDay(aiFunctions.selectedDate);
                          });
                        }),
                  ),
                ),

                //scroll down to the bottom of the list show only of it is not in the max extent
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30.0),
                    child: AnimatedOpacity(
                      opacity: _showScrollUpButton ? 1 : 0,
                      duration: Duration(milliseconds: 375),
                      child: GestureDetector(
                        onTap: _scrollUp,
                        child: Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle),
                          child: Icon(Icons.arrow_upward_rounded),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120.0),
                    child: AnimatedOpacity(
                      opacity: _showScrollDownButton ? 1 : 0,
                      duration: Duration(milliseconds: 375),
                      child: GestureDetector(
                        onTap: _scrollDown,
                        child: Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle),
                          child: Icon(Icons.arrow_downward_rounded),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            );
          }),
        ),
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
      child: SizedBox(
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

Widget GridButton(String title, String subtitle, context) {
  return Container(
    height: 80,
    padding: EdgeInsets.all(10),
    width: (MediaQuery.of(context).size.width / 2) - 20,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(width: 2, color: Colors.grey.withOpacity(0.2)),
    ),
    child: GestureDetector(
      onTap: () {
        // TODO: Implement button tap functionality
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: Theme.of(context).textTheme.headline6?.copyWith(
                    fontSize: 17,
                    color: Theme.of(context).colorScheme.primary,
                  )),
          SizedBox(height: 5),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
          ),
        ],
      ),
    ),
  );
}

class ChatInputBox extends StatefulWidget {
  final TextEditingController? controller;
  final VoidCallback? onSend, onClickCamera;

  ChatInputBox({
    super.key,
    this.controller,
    this.onSend,
    this.onClickCamera,
  });

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<ChatInputBox> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wrap(
        //   crossAxisAlignment: WrapCrossAlignment.center,
        //   alignment: WrapAlignment.center,
        //   runAlignment: WrapAlignment.center,
        //   spacing: 10,
        //   runSpacing: 10,
        //   children: <Widget>[
        //     GridButton('Write a SQL query',
        //         'that adds a "status" column to an "orders" table', context),
        //     GridButton('Write a text message', 'asking a friend', context),
        //     GridButton('Come up with concepts', 'for a arcade game', context),
        //     GridButton('Plan a trip',
        //         'to explore the nightlife scene in Bangkok', context),
        //   ],
        // ),
        SizedBox(height: 20),
        Card(
          margin: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Consumer<AIFunctions>(
                      builder: (context, aiFunctions, child) {
                    return AvatarGlow(
                      startDelay: const Duration(milliseconds: 1000),
                      glowColor: Colors.blue,
                      glowShape: BoxShape.circle,
                      animate: aiFunctions.isMicOn,
                      curve: Curves.fastOutSlowIn,
                      child: IconButton(
                          color: Theme.of(context).colorScheme.onBackground,
                          onPressed: widget.onClickCamera,
                          icon: Icon(
                            Icons.mic,
                          )),
                    );
                  })),
              Expanded(
                  child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 5,
                cursorColor: Theme.of(context).colorScheme.inversePrimary,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  hintText: 'Ask me to setup a meeting ..',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  isDense: true,
                ),
                onTapOutside: (event) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              )),
              Padding(
                padding: const EdgeInsets.all(4),
                child: FloatingActionButton.small(
                  onPressed: widget.onSend,
                  child: const Icon(Icons.send_rounded),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
