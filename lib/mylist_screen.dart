import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'dart:ui';

class MyListScreen extends StatefulWidget {
  const MyListScreen({Key? key}) : super(key: key);

  @override
  _MyListScreenState createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  Future<List<Map<String, dynamic>>> _getMyList() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> myList = prefs.getStringList('myList') ?? [];
    return myList
        .map((jsonStr) => json.decode(jsonStr) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _removeFromMyList(String movieId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> myList = prefs.getStringList('myList') ?? [];
    myList.removeWhere((jsonStr) {
      final movieMap = json.decode(jsonStr);
      return movieMap['id'].toString() == movieId;
    });
    await prefs.setStringList('myList', myList);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, Color>(
      selector: (_, settings) => settings.accentColor,
      builder: (context, accentColor, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              "My List",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              Container(color: const Color(0xFF111927)),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.06, -0.34),
                    radius: 1.0,
                    colors: [
                      accentColor.withOpacity(0.5),
                      const Color.fromARGB(255, 0, 0, 0),
                    ],
                    stops: const [0.0, 0.59],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.64, 0.3),
                    radius: 1.0,
                    colors: [
                      accentColor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
              Positioned.fill(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          accentColor.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(160, 17, 19, 40),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            border: Border(
                              top: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                              bottom: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                              left: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                              right: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                            ),
                          ),
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _getMyList(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator(
                                        color: accentColor));
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    "Error: ${snapshot.error}",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7)),
                                  ),
                                );
                              }
                              final myList = snapshot.data!;
                              if (myList.isEmpty) {
                                return Center(
                                  child: Text(
                                    "Your list is empty.",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 18),
                                  ),
                                );
                              }
                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.7,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                                itemCount: myList.length,
                                itemBuilder: (context, index) {
                                  final movie = myList[index];
                                  final posterPath = movie['poster_path'];
                                  final posterUrl = posterPath != null
                                      ? 'https://image.tmdb.org/t/p/w500$posterPath'
                                      : '';
                                  final title = movie['title'] ??
                                      movie['name'] ??
                                      'No Title';
                                  final rating = movie['vote_average'] != null
                                      ? double.tryParse(
                                          movie['vote_average'].toString())
                                      : null;
                                  return Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(4),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            accentColor.withOpacity(0.1),
                                            accentColor.withOpacity(0.3)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color:
                                                accentColor.withOpacity(0.3)),
                                      ),
                                      child: Stack(
                                        children: [
                                          MovieCard(
                                            imageUrl: posterUrl,
                                            title: title,
                                            rating: rating,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      MovieDetailScreen(
                                                          movie: movie),
                                                ),
                                              );
                                            },
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: IconButton(
                                              icon: Icon(Icons.remove_circle,
                                                  color: accentColor),
                                              onPressed: () =>
                                                  _removeFromMyList(
                                                      movie['id'].toString()),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
