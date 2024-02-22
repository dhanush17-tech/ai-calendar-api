import 'dart:io';

import 'package:ai_calendar_app/models/journalModel.dart';
import 'package:ai_calendar_app/providers/journalProvider.dart';
import 'package:ai_calendar_app/views/journalScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

class JournalHome extends StatefulWidget {
  const JournalHome({super.key});

  @override
  State<JournalHome> createState() => _JournalHomeState();
}

class _JournalHomeState extends State<JournalHome> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    Provider.of<JournalProvider>(context, listen: false).loadJournalEntries();
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<JournalProvider>(context).loadJournalEntries();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              // Enable scrolling when content is overflowing
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Journals",
                        style: TextStyle(
                            fontSize: 40.0, fontWeight: FontWeight.bold),
                      ),
                      //create new journal button
                      GestureDetector(
                        onTap: () {
                          final journal = JournalEntry(
                              audioPaths: [],
                              title: "",
                              content: "",
                              imagePaths: [],
                              id: DateTime.now().toString());
                          final journalProvider = Provider.of<JournalProvider>(
                              context,
                              listen: false);
                          journalProvider.addJournalEntry(journal);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => JournalScreen(journal)),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer),
                          child: Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  FutureBuilder<List<JournalEntry>>(
                      future: Provider.of<JournalProvider>(context)
                          .loadJournalEntries(),
                      builder: (context, snapshot) {
                        return AnimationLimiter(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: snapshot.data!.length,
                            itemBuilder: (BuildContext context, int index) {
                              List<StaggeredGridTile> tiles = [];
                              print(snapshot.data![index].audioPaths);
                              print(snapshot.data![index].imagePaths);

                              // Add main image tile if it exists
                              if (snapshot.data![index].imagePaths.isNotEmpty) {
                                tiles.add(
                                  StaggeredGridTile.count(
                                    crossAxisCellCount: 4,
                                    mainAxisCellCount: 2,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                          File(snapshot
                                              .data![index].imagePaths[0]),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              }

                              // Add smaller image tiles, leaving space for the "+2" overlay if needed
                              int overlayIndex =
                                  snapshot.data![index].imagePaths.length > 4
                                      ? 4
                                      : snapshot.data![index].imagePaths.length;
                              for (int i = 1; i < overlayIndex; i++) {
                                tiles.add(
                                  StaggeredGridTile.count(
                                    crossAxisCellCount: 2,
                                    mainAxisCellCount: 2,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                          File(snapshot
                                              .data![index].imagePaths[i]),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              }

                              // Add the "+2" overlay tile if there are more than 4 images
                              if (snapshot.data![index].imagePaths.length > 4) {
                                int additionalImages =
                                    snapshot.data![index].imagePaths.length - 4;
                                tiles.add(
                                  StaggeredGridTile.count(
                                    crossAxisCellCount: 2,
                                    mainAxisCellCount: 2,
                                    child: GestureDetector(
                                      onTap:
                                          Provider.of<JournalProvider>(context)
                                              .pickImage,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.5),
                                          child: Center(
                                            child: Text(
                                              '+$additionalImages',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final entry = snapshot.data![index];

                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                        child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) {
                                              return JournalScreen(
                                                entry,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      child: Card(
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20.0,
                                                      vertical: 12),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(entry.title,
                                                            style: TextStyle(
                                                                height: 1,
                                                                fontSize: 30.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                        SizedBox(height: 5),
                                                        Text(entry.content
                                                            .trim()),
                                                      ],
                                                    ),
                                                    SizedBox(height: 8),
                                                    snapshot.data![index]
                                                                .imagePaths !=
                                                            []
                                                        ? StaggeredGrid.count(
                                                            crossAxisCount: 4,
                                                            mainAxisSpacing: 4,
                                                            crossAxisSpacing: 4,
                                                            children: tiles,
                                                          )
                                                        : SizedBox(),
                                                  ]))),
                                    ))),
                              );
                            },
                          ),
                        );
                      }),
                  SizedBox(
                    height: 30,
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
          ],
        ),
      ),
    );
  }
}
