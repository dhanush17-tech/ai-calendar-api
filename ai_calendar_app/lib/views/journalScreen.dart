import 'dart:async';
import 'dart:io';
import 'package:ai_calendar_app/models/journalModel.dart';
import 'package:ai_calendar_app/models/journalModel.dart';
import 'package:ai_calendar_app/providers/journalProvider.dart';
import 'package:ai_calendar_app/views/journalHome.dart';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

class JournalScreen extends StatefulWidget {
  final JournalEntry journalEntry;
  JournalScreen(this.journalEntry);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  TextEditingController titleController = TextEditingController();

  TextEditingController descriptionController = TextEditingController();
  late PlayerController playerController;

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.journalEntry.title);
    descriptionController =
        TextEditingController(text: widget.journalEntry.content);

    titleController.addListener(_saveForm);
    descriptionController.addListener(_saveForm);
    WidgetsFlutterBinding.ensureInitialized();
    playerController = PlayerController();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    titleController.dispose();
    descriptionController.dispose();
  }

  void _saveForm() {
    // Proceed to save the journal entry only if it has content
    final updatedEntry = JournalEntry(
      id: widget.journalEntry.id,
      title: titleController.text.trim(),
      content: descriptionController.text.trim(),
      imagePaths: widget.journalEntry.imagePaths,
      audioPaths: widget.journalEntry.audioPaths,
    );
    Provider.of<JournalProvider>(context, listen: false)
        .updateJournalEntry(updatedEntry);
  }

  List<Widget> _buildTiles(List<String> imagePaths) {
    List<Widget> tiles = [];
    if (imagePaths.isNotEmpty) {
      tiles.add(
        StaggeredGridTile.count(
          crossAxisCellCount: 4,
          mainAxisCellCount: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(imagePaths[0]), fit: BoxFit.cover),
          ),
        ),
      );
    }

    // Add smaller image tiles, leaving space for the "+2" overlay if needed
    int overlayIndex = imagePaths.length > 4 ? 4 : imagePaths.length;
    for (int i = 1; i < overlayIndex; i++) {
      tiles.add(
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(imagePaths[i]), fit: BoxFit.cover),
          ),
        ),
      );
    }

    // Add the "+2" overlay tile if there are more than 4 images
    if (imagePaths.length > 4) {
      int additionalImages = imagePaths.length - 4;
      tiles.add(
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 2,
          child: GestureDetector(
            onTap: Provider.of<JournalProvider>(context).pickImage,
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
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    // Add main image tile if it exists
    final journalProvider = Provider.of<JournalProvider>(context);

    journalProvider.setAudioPaths(widget.journalEntry.audioPaths);
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            // Enable scrolling when content is overflowing
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: titleController,
                        onChanged: (value) => _saveForm(),
                        maxLines: 1,
                        decoration: InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: false,
                            fillColor: Colors.transparent),
                        style: TextStyle(
                            fontSize: 40.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 5),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            final journalProvider =
                                Provider.of<JournalProvider>(context,
                                    listen: false);
                            journalProvider
                                .deleteJournalEntry(widget.journalEntry);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                            ),
                            child: Icon(
                              Icons.delete_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final pickedImages = await Provider.of<JournalProvider>(
                                context,
                                listen: false)
                            .pickImage();

                        setState(() {
                          widget.journalEntry.imagePaths.addAll(pickedImages);
                          _saveForm();
                        });
                      },
                      child: Text('Add Image'),
                    ),
                    SizedBox(
                      width: 20,
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final audioPath = await Provider.of<JournalProvider>(
                                context,
                                listen: false)
                            .startOrStopRecording(
                                widget.journalEntry.audioPaths);
                        if (audioPath != null) {
                          // A new recording was completed, update the journal entry and UI accordingly
                          setState(() {
                            widget.journalEntry.audioPaths.add(audioPath);
                            // Use a key to insert the item into AnimatedList
                            _listKey.currentState?.insertItem(
                                widget.journalEntry.audioPaths.length - 1,
                                duration: Duration(milliseconds: 375));
                          });
                          _saveForm(); // Ensure this method updates the entry in your provider
                        }
                      },
                      child: Text('Add Audio'),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // Display images in a staggered grid view

                TextField(
                  controller: descriptionController,
                  maxLines: null,
                  onChanged: (value) => _saveForm(),
                  decoration: InputDecoration(
                      hintText: 'Write your journal entry...',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: false,
                      fillColor: Colors.transparent),
                  style: TextStyle(fontSize: 18.0),
                ),
                AnimationLimiter(
                  child: AnimatedList(
                    physics: NeverScrollableScrollPhysics(),
                    key: _listKey,
                    initialItemCount: widget.journalEntry.audioPaths.length,
                    shrinkWrap: true,
                    itemBuilder: (ctx, index, ani) {
                      final journalProvider =
                          Provider.of<JournalProvider>(context);
                      final path = widget.journalEntry.audioPaths[index];
                      final isPlaying =
                          journalProvider.currentlyPlayingPath == path &&
                              journalProvider.isCurrentlyPlaying;
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: FadeTransition(
                              opacity: ani,
                              child: ListTile(
                                leading: Icon(Icons.audiotrack),
                                title: Text('Recording ${index + 1}'),
                                trailing: Container(
                                  width: 70,
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => journalProvider
                                            .toggleAudioPlayback(path),
                                        child: isPlaying
                                            ? Icon(Icons.pause)
                                            : Icon(Icons.play_arrow),
                                      ),
                                      SizedBox(width: 20),
                                      GestureDetector(
                                        onTap: () {
                                          // Use AnimatedList's removeItem method to animate the item out
                                          _listKey.currentState?.removeItem(
                                            index,
                                            (context, animation) =>
                                                FadeTransition(
                                              opacity: CurvedAnimation(
                                                  parent: animation,
                                                  curve: Interval(0.0, 1.0)),
                                              child: SizeTransition(
                                                sizeFactor: CurvedAnimation(
                                                    parent: animation,
                                                    curve: Interval(0.0, 1.0)),
                                                axisAlignment: 0.0,
                                                child: ListTile(
                                                  leading:
                                                      Icon(Icons.audiotrack),
                                                  title: Text(
                                                      'Recording ${index + 1}'),
                                                ),
                                              ),
                                            ),
                                            duration: const Duration(
                                                milliseconds: 300),
                                          );
                                          // After the animation is done, then remove the item from your model and update the state
                                          Future.delayed(
                                              Duration(milliseconds: 300), () {
                                            setState(() {
                                              journalProvider
                                                  .deleteRecording(path);
                                              widget.journalEntry.audioPaths
                                                  .removeAt(index);

                                              // Consider notifying your provider or model here if needed
                                            });
                                          });
                                        },
                                        child: Icon(Icons.delete,
                                            color: Colors.redAccent
                                                .withOpacity(0.5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                widget.journalEntry.imagePaths != []
                    ? AnimationConfiguration.staggeredList(
                        position: 0,
                        child: ScaleAnimation(
                          child: FadeInAnimation(
                            child: StaggeredGrid.count(
                              crossAxisCount: 4,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              children:
                                  _buildTiles(widget.journalEntry.imagePaths),
                            ),
                          ),
                        ),
                      )
                    : Container(),

                SizedBox(height: 10),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(8.0),
                child: journalProvider.isRecording
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Play/Pause button based on the recording or playing state
                          if (journalProvider.isRecording)
                            IconButton(
                              icon: Icon(Icons.stop),
                              onPressed: () async {
                                final audioPath =
                                    await Provider.of<JournalProvider>(context,
                                            listen: false)
                                        .startOrStopRecording(
                                            widget.journalEntry.audioPaths);
                                if (audioPath != null) {
                                  // A new recording was completed, update the journal entry and UI accordingly
                                  setState(() {
                                    widget.journalEntry.audioPaths
                                        .add(audioPath);
                                    // Use a key to insert the item into AnimatedList
                                    _listKey.currentState?.insertItem(
                                        widget.journalEntry.audioPaths.length -
                                            1,
                                        duration: Duration(milliseconds: 375));
                                  });
                                  _saveForm(); // Ensure this method updates the entry in your provider
                                }
                              },
                            ),

                          AudioWaveforms(
                            enableGesture: true,
                            size:
                                Size(MediaQuery.of(context).size.width / 2, 50),
                            recorderController: Provider.of<JournalProvider>(
                                    context,
                                    listen: false)
                                .recorderController,
                            waveStyle: const WaveStyle(
                              waveColor: Colors.white,
                              extendWaveform: true,
                              showMiddleLine: false,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: Colors.grey.withOpacity(0.1),
                            ),
                            padding: const EdgeInsets.only(left: 18),
                            margin: const EdgeInsets.symmetric(horizontal: 15),
                          ),
                        ],
                      )
                    : Container()),
          ),
        ]),
      ),
    );
  }
}
