import 'package:flutter/material.dart';

class ARModeScreen extends StatefulWidget {
  const ARModeScreen({Key? key}) : super(key: key);

  @override
  _ARModeScreenState createState() => _ARModeScreenState();
}

class _ARModeScreenState extends State<ARModeScreen>
    with SingleTickerProviderStateMixin {
  // Simulated active filter – in a real app you might adjust brightness, contrast, etc.
  String _activeFilter = "None";
  // Animation controller for hotspot animations.
  late AnimationController _hotspotController;
  late Animation<double> _hotspotAnimation;

  @override
  void initState() {
    super.initState();
    _hotspotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hotspotAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_hotspotController);
  }

  @override
  void dispose() {
    _hotspotController.dispose();
    super.dispose();
  }

  void _showHotspotInfo(String info) {
    // Animate hotspot tap.
    _hotspotController.forward(from: 0.0);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AR Object Info",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(info, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showFilterSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final filters = ["None", "Sepia", "Black & White", "Vivid"];
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: filters
                .map((filter) => ListTile(
                      title: Text(filter),
                      onTap: () {
                        setState(() {
                          _activeFilter = filter;
                        });
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  void _shareExperience() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("AR experience shared!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // In a real AR app, replace this container with a live camera feed.
    return Scaffold(
      appBar: AppBar(
        title: const Text("Augmented Reality Mode"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter),
            onPressed: _showFilterSelector,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareExperience,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // General tap on AR view.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("General AR interaction detected!")),
          );
        },
        child: Stack(
          children: [
            // Simulated live camera feed.
            Container(
              color: Colors.black87,
              child: const Center(
                child: Text(
                  "Live Camera Feed",
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            // Apply a simulated filter overlay.
            if (_activeFilter != "None")
              Positioned.fill(
                child: Container(
                  color: _activeFilter == "Sepia"
                      ? Colors.brown.withOpacity(0.3)
                      : _activeFilter == "Black & White"
                          ? Colors.grey.withOpacity(0.3)
                          : _activeFilter == "Vivid"
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.transparent,
                ),
              ),
            // Interactive hotspot #1.
            Positioned(
              top: 100,
              left: 50,
              child: ScaleTransition(
                scale: _hotspotAnimation,
                child: GestureDetector(
                  onTap: () =>
                      _showHotspotInfo("This AR Poster shows XYZ details."),
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Text("AR Poster",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            // Interactive hotspot #2.
            Positioned(
              bottom: 150,
              right: 30,
              child: GestureDetector(
                onTap: () => _showHotspotInfo(
                    "Tap here for more info about this location."),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Text("Info Point",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _shareExperience,
        child: const Icon(Icons.send),
      ),
    );
  }
}
