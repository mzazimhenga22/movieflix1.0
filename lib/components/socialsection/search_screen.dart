import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _results = [];
  final List<String> _recentSearches = ['Movie', 'Action', 'Drama', 'Comedy'];

  void _search(String query) {
    setState(() {
      _results = query.isNotEmpty
          ? List.generate(5, (index) => "Result ${index + 1} for \"$query\"")
          : [];
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<SettingsProvider>(context).accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: accentColor.withOpacity(0.1),
        elevation: 0,
        title: const Text("Search", style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
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
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.3),
                  radius: 1.0,
                  colors: [accentColor.withOpacity(0.3), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [accentColor.withOpacity(0.3), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor.withOpacity(0.2),
                                    accentColor.withOpacity(0.4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.6),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  hintText: "Search posts, users, hashtags...",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  prefixIcon:
                                      Icon(Icons.search, color: accentColor),
                                  suffixIcon: _controller.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear,
                                              color: Colors.white70),
                                          onPressed: () {
                                            _controller.clear();
                                            _search('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: _search,
                                onSubmitted: _search,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _controller.text.isEmpty
                                  ? _buildRecentSearches(accentColor)
                                  : _buildSearchResults(accentColor),
                            ),
                          ],
                        ),
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
  }

  Widget _buildRecentSearches(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.2),
            accentColor.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Recent Searches",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _recentSearches
                  .map(
                    (search) => Chip(
                      label: Text(search,
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: accentColor.withOpacity(0.7),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(Color accentColor) {
    return _results.isEmpty
        ? const Center(
            child: Text(
              "No results found.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                shadows: [
                  Shadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 4),
                ],
              ),
            ),
          )
        : ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white54),
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.2),
                    accentColor.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                title: Text(
                  _results[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                          color: Colors.black54,
                          offset: Offset(2, 2),
                          blurRadius: 4),
                    ],
                  ),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("You selected: ${_results[index]}"),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: accentColor,
                    ),
                  );
                },
              ),
            ),
          );
  }
}
