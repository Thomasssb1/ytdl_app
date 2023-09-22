import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:marquee/marquee.dart';

class HomeApp extends StatefulWidget {
  HomeApp({super.key});

  @override
  State<HomeApp> createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> {
  final TextEditingController urlController = TextEditingController();
  final yt = YoutubeExplode();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  List<Map> videos = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          minimum: EdgeInsets.only(top: 40, left: 12, right: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Text(
              'Queue up videos for download to your device',
              style: GoogleFonts.inter(color: Color.fromRGBO(0, 0, 0, 0.7), fontWeight: FontWeight.bold, fontSize: 15),
            )),
            SizedBox(height: 12),
            TextField(
              controller: urlController,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                prefix: Padding(
                    padding: EdgeInsets.only(right: 7),
                    child: InkWell(
                      child: Ink(child: Image.asset('assets/play.png')),
                      onTap: () {},
                    )),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: 'Enter youtube URL here..',
                suffixIcon: InkWell(
                    child: Ink(child: Image.asset('assets/search.png')),
                    onTap: () async {
                      try {
                        var video = await yt.videos.get(urlController.text);
                        setState(() {
                          videos.add({
                            "url": urlController.text,
                            "title": video.title,
                            "thumbnail": video.thumbnails.mediumResUrl
                          });
                        });
                      } on VideoUnavailableException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Color(0xFFB0172A),
                          content: Text("The video that you tried to download is not valid or private."),
                          showCloseIcon: true,
                        ));
                      } on VideoRequiresPurchaseException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Color(0xFFB0172A),
                          content: Text("The video that you tried to download requires purchase in order to view."),
                          showCloseIcon: true,
                        ));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Color(0xFFB0172A),
                          content: Text("Something went wrong.. Try again."),
                          showCloseIcon: true,
                        ));
                      }
                    }),
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.only(top: 30, left: 12),
                hintStyle: GoogleFonts.inter(color: Color.fromRGBO(0, 0, 0, 0.3), fontSize: 15),
                filled: true,
                fillColor: Color(0xFFD9D9D9),
                border: const OutlineInputBorder(
                    borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(20))),
              ),
            ),
            SizedBox(height: 23),
            Padding(
                padding: EdgeInsets.only(left: 5),
                child: Text(
                  'Queue',
                  style:
                      GoogleFonts.inter(color: Color.fromRGBO(0, 0, 0, 0.7), fontSize: 20, fontWeight: FontWeight.bold),
                )),
            SizedBox(height: 17),
            Padding(
                padding: EdgeInsets.only(left: 5),
                child: Visibility(
                  child: Text(
                    "Currently nothing is in the queue.",
                    style: GoogleFonts.inter(),
                  ),
                  visible: videos.isEmpty,
                )),
            Expanded(
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: videos.length,
                    itemBuilder: ((BuildContext context, int count) {
                      return Padding(
                          padding: EdgeInsets.only(bottom: 25),
                          child: Row(
                            children: [
                              ClipRRect(
                                  borderRadius:
                                      BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
                                  child: Image.network(
                                    videos[count]['thumbnail'],
                                    height: 115,
                                    width: 140,
                                    fit: BoxFit.fitHeight,
                                  )),
                              Container(
                                  height: 115,
                                  width: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
                                    color: Color(0xFFD9D9D9),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                          padding: EdgeInsets.only(top: 5, left: 5),
                                          child: SizedBox(
                                              height: 40,
                                              width: 200,
                                              child: Marquee(
                                                text: videos[count]['title'],
                                                blankSpace: 20,
                                                style: GoogleFonts.inter(
                                                    fontSize: 20,
                                                    color: Color.fromRGBO(0, 0, 0, 0.7),
                                                    fontWeight: FontWeight.bold),
                                              )))
                                    ],
                                  ))
                            ],
                          ));
                    })))
          ])),
    );
  }
}
