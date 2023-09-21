import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final TextEditingController urlController = TextEditingController();
  final yt = YoutubeExplode();

  List<Map> videos = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
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
                    onTap: () {
                      // check if valid
                      var video = yt.videos.get('https://youtube.com/watch?v=Dpp1sIL1m5Q');

                      videos.add({"url": urlController.text});
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
                    itemCount: videos.length,
                    itemBuilder: ((BuildContext context, int count) {
                      return SizedBox();
                    })))
          ])),
    ));
  }
}
