import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:marquee/marquee.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:ytdl_app/setting.dart';

class HomeApp extends StatefulWidget {
  HomeApp({super.key});

  @override
  State<HomeApp> createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> with ChangeNotifier {
  final TextEditingController urlController = TextEditingController();
  final YoutubeExplode yt = YoutubeExplode();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  late TextEditingController directoryController;

  List<Map> videos = [];

  bool isDownloading = false;
  bool isFetching = false;
  //Directory? downloadsDir;

  var settingsBox = Hive.box('settings');

  @override
  void initState() {
    super.initState();
  }

  String generateFilename(String title) => title
      .replaceAll('#', '')
      .replaceAll('%', '')
      .replaceAll('&', '')
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll(r'\', '')
      .replaceAll(r'$', '')
      .replaceAll('!', '')
      .replaceAll("'", '')
      .replaceAll('"', '')
      .replaceAll(':', '')
      .replaceAll('@', '')
      .replaceAll('.', '')
      .replaceAll(' ', '-');

  Future<void> downloadVideo() async {
    // check if currently downloading
    // if not downloading then start download
    // if downloading then ignore
    // at the end of downloading - go to next item in list
    print("trig");
    // need to check if file exists and ask if replace
    if (!isDownloading) {
      setState(() => isDownloading = true);
      late var streamInfo;
      var manifest = await yt.videos.streams.getManifest(videos[0]['metadata'].id);
      if (videos[0]['type'] == 'muxed') {
        streamInfo = manifest.muxed.sortByVideoQuality().first;
      } else if (videos[0]['type'] == 'video') {
        streamInfo = manifest.videoOnly.sortByVideoQuality().first;
      } else if (videos[0]['type'] == 'music') {
        streamInfo = manifest.audioOnly.sortByBitrate().first;
      }
      var stream = yt.videos.streamsClient.get(streamInfo);
      final file = File(
          "${settingsBox.get('installDirectory')}/${generateFilename(videos[0]['metadata'].title)}.${streamInfo.container.name}");

      if (file.existsSync()) {
        file.deleteSync();
      }

      final output = file.openWrite(mode: FileMode.writeOnlyAppend);

      videos[0]['length'] = streamInfo.size.totalBytes;
      int current = 0;

      await for (final data in stream) {
        print(data.length);
        current += data.length;
        videos[0]['progress'].value = (current / streamInfo.size.totalBytes);
        output.add(data);
      }
      await output.close();
      setState(() => videos.removeAt(0));

      if (videos.isNotEmpty) {
        await downloadVideo();
      } else {
        isDownloading = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          minimum: const EdgeInsets.only(top: 40, left: 12, right: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Text(
              'Queue up videos for download to your device',
              style: GoogleFonts.inter(
                  color: const Color.fromRGBO(0, 0, 0, 0.7), fontWeight: FontWeight.bold, fontSize: 15),
            )),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              textAlignVertical: TextAlignVertical.center,
              onSubmitted: (_) async {
                try {
                  setState(() {
                    isFetching = true;
                  });
                  var video = await yt.videos.get(urlController.text);
                  setState(() {
                    videos.add({
                      "url": urlController.text,
                      "title": video.title,
                      "thumbnail": video.thumbnails.mediumResUrl,
                      "type": 'muxed',
                      "progress": ValueNotifier<double>(0.0),
                      "metadata": video
                    });
                    urlController.text = "";
                    isFetching = false;
                  });
                  if (settingsBox.get('installDirectory') == null) {
                    directoryController = TextEditingController();
                    if (mounted) {
                      await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text("Download location"),
                              content: SizedBox(
                                  height: 150,
                                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                    const Text("Where should the videos be downloaded?"),
                                    TextField(
                                        readOnly: true,
                                        controller: directoryController,
                                        enabled: true,
                                        decoration: InputDecoration(
                                            hintText: "No directory selected..",
                                            suffixIcon: InkWell(
                                                onTap: () async {
                                                  String? selectedDirectory =
                                                      await FilePicker.platform.getDirectoryPath();
                                                  if (selectedDirectory == null) {
                                                    setState(() {
                                                      videos.removeLast();
                                                    });
                                                    Navigator.of(context).pop();
                                                  } else {
                                                    directoryController.text = selectedDirectory;
                                                  }
                                                },
                                                child: Ink(child: Image.asset('assets/folder.png')))))
                                  ])),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      if (directoryController.text.isNotEmpty) {
                                        settingsBox.put('installDirectory', directoryController.text);
                                      } else {
                                        setState(() {
                                          videos.removeLast();
                                        });
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Submit", style: GoogleFonts.inter(color: const Color(0XFF2AB017))))
                              ],
                            );
                          });
                    }
                  }
                  if (videos.isNotEmpty) {
                    await downloadVideo();
                  }
                } on VideoUnavailableException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: Color(0xFFB0172A),
                    content: Text("The video that you tried to download is not valid or private."),
                    showCloseIcon: true,
                  ));
                } on VideoRequiresPurchaseException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: Color(0xFFB0172A),
                    content: Text("The video that you tried to download requires purchase in order to view."),
                    showCloseIcon: true,
                  ));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: Color(0xFFB0172A),
                    content: Text("Something went wrong.. Try again."),
                    showCloseIcon: true,
                  ));
                }
              },
              decoration: InputDecoration(
                prefix: Padding(padding: const EdgeInsets.only(right: 7), child: Image.asset('assets/play.png')),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: 'Enter youtube URL here..',
                suffixIcon: InkWell(
                    child: Ink(child: Image.asset('assets/search.png')),
                    onTap: () async {
                      try {
                        setState(() {
                          isFetching = true;
                        });
                        var video = await yt.videos.get(urlController.text);
                        setState(() {
                          videos.add({
                            "url": urlController.text,
                            "title": video.title,
                            "thumbnail": video.thumbnails.mediumResUrl,
                            "type": 'muxed',
                            "progress": ValueNotifier<double>(0.0),
                            "metadata": video
                          });
                          isFetching = false;
                          urlController.text = "";
                        });
                        if (settingsBox.get('installDirectory') == null) {
                          directoryController = TextEditingController();
                          if (mounted) {
                            await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text("Download location"),
                                    content: SizedBox(
                                        height: 150,
                                        child: Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                          const Text("Where should the videos be downloaded?"),
                                          TextField(
                                              readOnly: true,
                                              controller: directoryController,
                                              enabled: true,
                                              decoration: InputDecoration(
                                                  hintText: "No directory selected..",
                                                  suffixIcon: InkWell(
                                                      onTap: () async {
                                                        String? selectedDirectory =
                                                            await FilePicker.platform.getDirectoryPath();
                                                        if (selectedDirectory == null) {
                                                          setState(() {
                                                            videos.removeLast();
                                                          });
                                                          Navigator.of(context).pop();
                                                        } else {
                                                          directoryController.text = selectedDirectory;
                                                        }
                                                      },
                                                      child: Ink(child: Image.asset('assets/folder.png')))))
                                        ])),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            if (directoryController.text.isNotEmpty) {
                                              settingsBox.put('installDirectory', directoryController.text);
                                            } else {
                                              setState(() {
                                                videos.removeLast();
                                              });
                                            }
                                            Navigator.of(context).pop();
                                          },
                                          child:
                                              Text("Submit", style: GoogleFonts.inter(color: const Color(0XFF2AB017))))
                                    ],
                                  );
                                });
                          }
                        }
                        if (videos.isNotEmpty) {
                          await downloadVideo();
                        }
                      } on VideoUnavailableException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          backgroundColor: Color(0xFFB0172A),
                          content: Text("The video that you tried to download is not valid or private."),
                          showCloseIcon: true,
                        ));
                      } on VideoRequiresPurchaseException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          backgroundColor: Color(0xFFB0172A),
                          content: Text("The video that you tried to download requires purchase in order to view."),
                          showCloseIcon: true,
                        ));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          backgroundColor: Color(0xFFB0172A),
                          content: Text("Something went wrong.. Try again."),
                          showCloseIcon: true,
                        ));
                      }
                    }),
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.only(top: 30, left: 12),
                hintStyle: GoogleFonts.inter(color: const Color.fromRGBO(0, 0, 0, 0.3), fontSize: 15),
                filled: true,
                fillColor: const Color(0xFFD9D9D9),
                border: const OutlineInputBorder(
                    borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(20))),
              ),
            ),
            const SizedBox(height: 23),
            Row(children: [
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 3, right: 15),
                child: Text(
                  'Queue',
                  style: GoogleFonts.inter(
                      color: const Color.fromRGBO(0, 0, 0, 0.7), fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                  onTap: () {
                    setState(() {
                      isDownloading = !isDownloading;
                    });
                  },
                  child: Ink(child: isDownloading ? Image.asset('assets/pause.png') : Image.asset('assets/play.png')))
            ]),
            const SizedBox(height: 17),
            Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Visibility(
                  visible: videos.isEmpty,
                  child: Text(
                    "Currently nothing is in the queue.",
                    style: GoogleFonts.inter(),
                  ),
                )),
            ListView.builder(
                shrinkWrap: true,
                itemCount: videos.length,
                itemBuilder: ((BuildContext context, int count) {
                  print(count);
                  print(isDownloading);
                  print((count == 0) && isDownloading);
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: GestureDetector(
                          onTap: () async {
                            await downloadVideo();
                          },
                          onLongPress: () {
                            showDialog(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text("Remove video"),
                                    content: const Text("Are you sure you want to remove the video from the queue?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            "No",
                                            style: GoogleFonts.inter(color: const Color(0xFFB0172A)),
                                          )),
                                      TextButton(
                                          onPressed: () {
                                            setState(() {
                                              videos.removeAt(count);
                                            });
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                              backgroundColor: const Color(0xFFD9D9D9),
                                              content: Text(
                                                "Removed video from the queue.",
                                                style: GoogleFonts.inter(
                                                  color: const Color.fromRGBO(0, 0, 0, 0.7),
                                                ),
                                              ),
                                              showCloseIcon: true,
                                            ));
                                          },
                                          child: Text(
                                            "Yes",
                                            style: GoogleFonts.inter(color: const Color(0XFF2AB017)),
                                          ))
                                    ],
                                  );
                                });
                          },
                          child: Row(
                            children: [
                              ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
                                  child: Image.network(
                                    videos[count]['thumbnail'],
                                    height: 120,
                                    width: 140,
                                    fit: BoxFit.fitHeight,
                                  )),
                              Container(
                                  height: 120,
                                  width: 220,
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
                                    color: Color(0xFFD9D9D9),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                          padding: const EdgeInsets.only(top: 5, left: 5),
                                          child: Row(children: [
                                            SizedBox(
                                              height: 40,
                                              width: 180,
                                              child: Marquee(
                                                text: videos[count]['title'],
                                                blankSpace: 20,
                                                style: GoogleFonts.inter(
                                                    fontSize: 20,
                                                    color: const Color.fromRGBO(0, 0, 0, 0.7),
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Padding(
                                                padding: const EdgeInsets.only(left: 5),
                                                child: InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                        context: context,
                                                        builder: (ctx) {
                                                          return AlertDialog(
                                                            title: const Text("Remove video"),
                                                            content: const Text(
                                                                "Are you sure you want to remove the video from the queue?"),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () {
                                                                    Navigator.of(context).pop();
                                                                  },
                                                                  child: Text(
                                                                    "No",
                                                                    style: GoogleFonts.inter(
                                                                        color: const Color(0xFFB0172A)),
                                                                  )),
                                                              TextButton(
                                                                  onPressed: () {
                                                                    setState(() {
                                                                      videos.removeAt(count);
                                                                    });
                                                                    Navigator.of(context).pop();
                                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                                      backgroundColor: const Color(0xFFD9D9D9),
                                                                      content: Text(
                                                                        "Removed video from the queue.",
                                                                        style: GoogleFonts.inter(
                                                                          color: const Color.fromRGBO(0, 0, 0, 0.7),
                                                                        ),
                                                                      ),
                                                                      showCloseIcon: true,
                                                                    ));
                                                                  },
                                                                  child: Text(
                                                                    "Yes",
                                                                    style: GoogleFonts.inter(
                                                                        color: const Color(0XFF2AB017)),
                                                                  ))
                                                            ],
                                                          );
                                                        });
                                                  },
                                                  child: Ink(child: Image.asset('assets/cancel.png')),
                                                ))
                                          ])),
                                      Visibility(
                                          visible: true,
                                          child: Padding(
                                              padding: const EdgeInsets.only(left: 3),
                                              child: Text(
                                                'Progress:',
                                                style: GoogleFonts.inter(
                                                    color: const Color.fromRGBO(0, 0, 0, 0.7),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold),
                                              ))),
                                      ValueListenableBuilder(
                                          valueListenable: videos[count]['progress'],
                                          builder: (BuildContext context, double value, child) {
                                            return Padding(
                                                padding: const EdgeInsets.only(left: 3, top: 5),
                                                child: SizedBox(
                                                    width: 200,
                                                    child: LinearProgressIndicator(
                                                      value: value,
                                                      backgroundColor: const Color.fromRGBO(0, 0, 0, 0.7),
                                                      color: const Color(0xFFB0172A),
                                                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                                                    )));
                                          }),
                                      Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: (count == 0) && isDownloading
                                              ? InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                        context: context,
                                                        builder: (ctx) {
                                                          return AlertDialog(
                                                              title: Text('Video settings'),
                                                              content: Column(children: [
                                                                ListView(scrollDirection: Axis.horizontal, children: [
                                                                  TextField(
                                                                    enabled: false,
                                                                    decoration: InputDecoration(
                                                                      labelText:
                                                                          'Title : ${generateFilename(videos[count]['title'])}',
                                                                    ),
                                                                  )
                                                                ]),
                                                              ]),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () {
                                                                      Navigator.of(context).pop();
                                                                    },
                                                                    child: Text("Close",
                                                                        style: GoogleFonts.inter(
                                                                            color: const Color(0xFFB0172A))))
                                                              ]);
                                                        });
                                                  },
                                                  child: Ink(child: Image.asset('assets/options.png')))
                                              : InkWell(
                                                  onTap: () {
                                                    if (videos[count]['type'] == 'muxed') {
                                                      setState(() {
                                                        videos[count]['type'] = 'music';
                                                      });
                                                    } else if (videos[count]['type'] == 'music') {
                                                      setState(() {
                                                        videos[count]['type'] = 'video';
                                                      });
                                                    } else if (videos[count]['type'] == 'video') {
                                                      setState(() {
                                                        videos[count]['type'] = 'muxed';
                                                      });
                                                    }
                                                  },
                                                  onLongPress: () {
                                                    showDialog(
                                                        context: context,
                                                        builder: (ctx) {
                                                          return AlertDialog(
                                                            title: Row(children: [
                                                              const Text('What do the icons mean?'),
                                                              Padding(
                                                                  padding: const EdgeInsets.only(left: 18, top: 5),
                                                                  child: InkWell(
                                                                      onTap: () {
                                                                        Navigator.of(context).pop();
                                                                      },
                                                                      child:
                                                                          Ink(child: Image.asset('assets/cancel.png'))))
                                                            ]),
                                                            content: SizedBox(
                                                                height: 150,
                                                                child: Column(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                                    children: [
                                                                      Row(children: [
                                                                        Image.asset('assets/muxed.png'),
                                                                        Text(' - Both audio and video',
                                                                            style: GoogleFonts.inter(
                                                                                color:
                                                                                    const Color.fromRGBO(0, 0, 0, 0.7)))
                                                                      ]),
                                                                      Row(children: [
                                                                        Image.asset('assets/music.png'),
                                                                        Text(' - Only audio',
                                                                            style: GoogleFonts.inter(
                                                                                color:
                                                                                    const Color.fromRGBO(0, 0, 0, 0.7)))
                                                                      ]),
                                                                      Row(children: [
                                                                        Image.asset('assets/video.png'),
                                                                        Text(' - Only video',
                                                                            style: GoogleFonts.inter(
                                                                                color:
                                                                                    const Color.fromRGBO(0, 0, 0, 0.7)))
                                                                      ])
                                                                    ])),
                                                          );
                                                        });
                                                  },
                                                  child: Ink(
                                                      child: Image.asset(
                                                    'assets/${videos[count]["type"]}.png',
                                                  ))))
                                    ],
                                  ))
                            ],
                          )));
                })),
            Visibility(
                visible: isFetching,
                child: const Padding(
                  padding: EdgeInsets.only(top: 30, left: 12),
                  child: CircularProgressIndicator(
                    color: Color(0xFFD9D9D9),
                  ),
                ))
          ])),
    );
  }
}
