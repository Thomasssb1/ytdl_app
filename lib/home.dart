import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:marquee/marquee.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:resize/resize.dart';

class HomeApp extends StatefulWidget {
  const HomeApp({super.key});

  @override
  State<HomeApp> createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> with ChangeNotifier {
  final TextEditingController urlController = TextEditingController();
  final YoutubeExplode yt = YoutubeExplode();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  late TextEditingController directoryController;
  late TextEditingController nameController;

  List<Map> videos = [];

  bool isDownloading = false;
  bool isPaused = false;
  bool isFetching = false;
  bool isDeleted = false;
  //Directory? downloadsDir;

  var settingsBox = Hive.box('settings');

  String defaultDownloadType = Hive.box('settings').get('downloadType', defaultValue: 'muxed');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    directoryController.dispose();
    nameController.dispose();
    super.dispose();
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
      .replaceAll('|', '')
      .replaceAll(' ', '-');

  bool containsURL(String url) {
    for (final item in videos) {
      if (item.containsValue(url)) {
        return true;
      }
    }
    return false;
  }

  Future<void> downloadVideo([int start = 0]) async {
    // check if currently downloading
    // if not downloading then start download
    // if downloading then ignore
    // at the end of downloading - go to next item in list
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
      File file = File(
          "${settingsBox.get('installDirectory')}/${generateFilename(videos[0]['metadata'].title)}.${streamInfo.container.name}");

      bool skipVideo = false;

      if (file.existsSync()) {
        nameController = TextEditingController();
        if (mounted) {
          await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text("This file already exists"),
                  content: SizedBox(
                      height: 150.h,
                      child: Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        const Text(
                            "The filename that has been generated has a duplicate name, either change the name or skip download."),
                        TextField(
                            controller: nameController,
                            enabled: true,
                            decoration: const InputDecoration(
                              hintText: "Enter new name..",
                            )),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () {
                          skipVideo = true;
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Skip",
                          style: GoogleFonts.inter(color: const Color(0xFFB0172A)),
                        )),
                    TextButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty) {
                            file = File(
                                "${settingsBox.get('installDirectory')}/${nameController.text}.${streamInfo.container.name}");
                          } else {
                            file.deleteSync();
                          }

                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Continue",
                          style: GoogleFonts.inter(color: const Color(0XFF2AB017)),
                        )),
                  ],
                );
              });
        }
      }
      if (!skipVideo) {
        final output = file.openWrite(mode: FileMode.writeOnlyAppend);

        videos[0]['length'] = streamInfo.size.totalBytes;
        int current = 0;

        await for (final data in stream) {
          print(isPaused);
          if (isPaused) {
            await Future.doWhile(() => Future.delayed(const Duration(seconds: 1)).then((_) => isPaused));
          }

          current += data.length;
          if (!isDeleted) {
            videos[0]['progress'].value = (current / streamInfo.size.totalBytes);
          } else {
            break;
          }
          output.add(data);
        }
        await output.close();

        if (isDeleted) file.deleteSync();

        setState(() {
          if (!isDeleted) videos.removeAt(0);
          isDeleted = false;
          isDownloading = false;
        });

        if (videos.isNotEmpty) {
          await downloadVideo();
        }
      } else {
        setState(() {
          videos.removeAt(0);
          isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          minimum: EdgeInsets.only(top: 40.h, left: 12.w, right: 12.w),
          child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                    child: Text(
                  'Queue up videos for download to your device',
                  style: GoogleFonts.inter(
                      color: const Color.fromRGBO(0, 0, 0, 0.7), fontWeight: FontWeight.bold, fontSize: 15.sp),
                )),
                SizedBox(height: 12.h),
                TextField(
                  controller: urlController,
                  textAlignVertical: TextAlignVertical.center,
                  onSubmitted: (_) async {
                    bool addVideo = true;
                    if (containsURL(urlController.text)) {
                      await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text("Duplicate link"),
                              content: const Text(
                                  "This video has already been added to the queue. Do you want to add it anyway?"),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      addVideo = false;
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(
                                      "No",
                                      style: GoogleFonts.inter(color: const Color(0xFFB0172A)),
                                    )),
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(
                                      "Yes",
                                      style: GoogleFonts.inter(color: const Color(0XFF2AB017)),
                                    ))
                              ],
                            );
                          });
                    }
                    if (addVideo) {
                      try {
                        setState(() => isFetching = true);
                        var video = await yt.videos.get(urlController.text);
                        setState(() {
                          videos.add({
                            "url": urlController.text,
                            "title": video.title,
                            "thumbnail": video.thumbnails.mediumResUrl,
                            "type": defaultDownloadType,
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
                      } on VideoUnavailableException catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            backgroundColor: Color(0xFFB0172A),
                            content: Text("The video that you tried to download is not valid or private."),
                            showCloseIcon: true,
                          ));
                        }
                      } on VideoRequiresPurchaseException catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            backgroundColor: Color(0xFFB0172A),
                            content: Text("The video that you tried to download requires purchase in order to view."),
                            showCloseIcon: true,
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            backgroundColor: Color(0xFFB0172A),
                            content: Text("Something went wrong.. Try again."),
                            showCloseIcon: true,
                          ));
                        }
                      }
                    } else {
                      setState(() => urlController.text = "");
                    }
                  },
                  decoration: InputDecoration(
                    prefix: Padding(padding: EdgeInsets.only(right: 7.w), child: Image.asset('assets/play.png')),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: 'Enter youtube URL here..',
                    suffixIcon: InkWell(
                        child: Ink(child: Image.asset('assets/search.png')),
                        onTap: () async {
                          bool addVideo = true;
                          if (containsURL(urlController.text)) {
                            await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text("Duplicate link"),
                                    content: const Text(
                                        "This video has already been added to the queue. Do you want to add it anyway?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            addVideo = false;
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            "No",
                                            style: GoogleFonts.inter(color: const Color(0xFFB0172A)),
                                          )),
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            "Yes",
                                            style: GoogleFonts.inter(color: const Color(0XFF2AB017)),
                                          ))
                                    ],
                                  );
                                });
                          }
                          if (addVideo) {
                            try {
                              setState(() => isFetching = true);

                              var video = await yt.videos.get(urlController.text);
                              setState(() {
                                videos.add({
                                  "url": urlController.text,
                                  "title": video.title,
                                  "thumbnail": video.thumbnails.mediumResUrl,
                                  "type": defaultDownloadType,
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
                                              height: 150.h,
                                              child:
                                                  Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
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
                                                                if (mounted) {
                                                                  Navigator.of(context).pop();
                                                                }
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
                                                child: Text("Submit",
                                                    style: GoogleFonts.inter(color: const Color(0XFF2AB017))))
                                          ],
                                        );
                                      });
                                }
                              }
                              if (videos.isNotEmpty) {
                                await downloadVideo();
                              }
                            } on VideoUnavailableException catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  backgroundColor: Color(0xFFB0172A),
                                  content: Text("The video that you tried to download is not valid or private."),
                                  showCloseIcon: true,
                                ));
                              }
                            } on VideoRequiresPurchaseException catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  backgroundColor: Color(0xFFB0172A),
                                  content:
                                      Text("The video that you tried to download requires purchase in order to view."),
                                  showCloseIcon: true,
                                ));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  backgroundColor: Color(0xFFB0172A),
                                  content: Text("Something went wrong.. Try again."),
                                  showCloseIcon: true,
                                ));
                              }
                            }
                          } else {
                            setState(() => urlController.text = "");
                          }
                        }),
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.only(top: 30.h, left: 12.w),
                    hintStyle: GoogleFonts.inter(color: const Color.fromRGBO(0, 0, 0, 0.3), fontSize: 15.sp),
                    filled: true,
                    fillColor: const Color(0xFFD9D9D9),
                    border: const OutlineInputBorder(
                        borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(20))),
                  ),
                ),
                SizedBox(height: 23.h),
                Row(children: [
                  Padding(
                    padding: EdgeInsets.only(left: 5.w, top: 3.h, right: 15.w),
                    child: Text(
                      'Queue',
                      style: GoogleFonts.inter(
                          color: const Color.fromRGBO(0, 0, 0, 0.7), fontSize: 20.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                      onTap: () {
                        setState(() {
                          isPaused = !isPaused;
                        });
                      },
                      child: Ink(child: isPaused ? Image.asset('assets/play.png') : Image.asset('assets/pause.png'))),
                  Padding(
                      padding: EdgeInsets.only(left: 240.w),
                      child: InkWell(
                          onTap: () async {
                            directoryController = TextEditingController();
                            await showDialog(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text("Settings"),
                                    content: StatefulBuilder(builder: (BuildContext context, setState) {
                                      return SizedBox(
                                        height: 200.h,
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text("Where should the videos be downloaded?"),
                                          TextField(
                                              readOnly: true,
                                              controller: directoryController,
                                              enabled: true,
                                              decoration: InputDecoration(
                                                  hintText: (settingsBox.get('installDirectory') == null)
                                                      ? "No directory selected.."
                                                      : settingsBox.get('installDirectory'),
                                                  suffixIcon: InkWell(
                                                      onTap: () async {
                                                        String? selectedDirectory =
                                                            await FilePicker.platform.getDirectoryPath();
                                                        if (selectedDirectory != null) {
                                                          settingsBox.put('installDirectory', selectedDirectory);
                                                          directoryController.text = selectedDirectory;
                                                        }
                                                      },
                                                      child: Ink(child: Image.asset('assets/folder.png'))))),
                                          SizedBox(
                                            height: 20.h,
                                          ),
                                          const Text("What should the default download type be?"),
                                          DropdownButton<String>(
                                              value: defaultDownloadType,
                                              items: [
                                                DropdownMenuItem(
                                                    value: 'muxed',
                                                    child: Text(
                                                      'muxed',
                                                      style: GoogleFonts.inter(),
                                                    )),
                                                DropdownMenuItem(
                                                    value: 'audio',
                                                    child: Text(
                                                      'audio',
                                                      style: GoogleFonts.inter(),
                                                    )),
                                                DropdownMenuItem(
                                                    value: 'video',
                                                    child: Text(
                                                      'video',
                                                      style: GoogleFonts.inter(),
                                                    ))
                                              ],
                                              onChanged: (String? value) async {
                                                if (value != null) {
                                                  //settingsBox.put('downloadType', value);
                                                  setState(() {
                                                    defaultDownloadType = value;
                                                  });
                                                }
                                              })
                                        ]),
                                      );
                                    }),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child:
                                              Text("Close", style: GoogleFonts.inter(color: const Color(0xFFB0172A))))
                                    ],
                                  );
                                });
                          },
                          child: Ink(child: Image.asset('assets/settings.png'))))
                ]),
                SizedBox(height: 17.h),
                Padding(
                    padding: EdgeInsets.only(left: 5.w),
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
                      return Padding(
                          padding: EdgeInsets.only(bottom: 25.h),
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
                                        content:
                                            const Text("Are you sure you want to remove the video from the queue?"),
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
                                                  isDownloading = false;
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
                                        height: 120.h,
                                        width: 140.w,
                                        fit: BoxFit.fitHeight,
                                      )),
                                  Container(
                                      height: 120.h,
                                      width: 220.w,
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
                                                  height: 40.h,
                                                  width: 180.w,
                                                  child: Marquee(
                                                    text: videos[count]['title'],
                                                    blankSpace: 20.w,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 20.sp,
                                                        color: const Color.fromRGBO(0, 0, 0, 0.7),
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                Padding(
                                                    padding: EdgeInsets.only(left: 5.w),
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
                                                                          isDownloading = false;
                                                                          if (count == 0) isDeleted = true;
                                                                        });
                                                                        Navigator.of(context).pop();
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(SnackBar(
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
                                                  padding: EdgeInsets.only(left: 3.w),
                                                  child: Text(
                                                    'Progress:',
                                                    style: GoogleFonts.inter(
                                                        color: const Color.fromRGBO(0, 0, 0, 0.7),
                                                        fontSize: 16.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ))),
                                          ValueListenableBuilder(
                                              valueListenable: videos[count]['progress'],
                                              builder: (BuildContext context, double value, child) {
                                                return Padding(
                                                    padding: EdgeInsets.only(left: 3.w, top: 5.h),
                                                    child: SizedBox(
                                                        width: 200.w,
                                                        child: LinearProgressIndicator(
                                                          value: value,
                                                          backgroundColor: const Color.fromRGBO(0, 0, 0, 0.7),
                                                          color: const Color(0xFFB0172A),
                                                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                                                        )));
                                              }),
                                          Padding(
                                              padding: EdgeInsets.all(12.w),
                                              child: (count == 0) && isDownloading
                                                  ? InkWell(
                                                      onTap: () {
                                                        showDialog(
                                                            context: context,
                                                            builder: (ctx) {
                                                              return AlertDialog(
                                                                  title: const Text('Video settings'),
                                                                  content: Column(children: [
                                                                    ListView(
                                                                        scrollDirection: Axis.horizontal,
                                                                        children: [
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
                                                                title: const Text('What do the icons mean?'),
                                                                content: SizedBox(
                                                                    height: 150.h,
                                                                    child: Column(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceAround,
                                                                        children: [
                                                                          Row(children: [
                                                                            Image.asset('assets/muxed.png'),
                                                                            Text(' - Both audio and video',
                                                                                style: GoogleFonts.inter(
                                                                                    color: const Color.fromRGBO(
                                                                                        0, 0, 0, 0.7)))
                                                                          ]),
                                                                          Row(children: [
                                                                            Image.asset('assets/music.png'),
                                                                            Text(' - Only audio',
                                                                                style: GoogleFonts.inter(
                                                                                    color: const Color.fromRGBO(
                                                                                        0, 0, 0, 0.7)))
                                                                          ]),
                                                                          Row(children: [
                                                                            Image.asset('assets/video.png'),
                                                                            Text(' - Only video',
                                                                                style: GoogleFonts.inter(
                                                                                    color: const Color.fromRGBO(
                                                                                        0, 0, 0, 0.7)))
                                                                          ])
                                                                        ])),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () {
                                                                        Navigator.of(context).pop();
                                                                      },
                                                                      child: Text("Close",
                                                                          style: GoogleFonts.inter(
                                                                              color: const Color(0xFFB0172A))))
                                                                ],
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
                    child: Padding(
                      padding: EdgeInsets.only(top: 30.h, left: 12.w),
                      child: const CircularProgressIndicator(
                        color: Color(0xFFD9D9D9),
                      ),
                    ))
              ]))),
    );
  }
}
