import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({Key? key}) : super(key: key);
  @override
  _StorageSettingsScreenState createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  double _storageValue = 1024; // in MB
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageSettings();
  }

  Future<void> _loadStorageSettings() async {
    final prefs = await SharedPreferences.getInstance();
    int? allocated = prefs.getInt('allocatedStorage');
    setState(() {
      _storageValue = allocated != null ? allocated / (1024 * 1024) : 1024;
      _loading = false;
    });
  }

  Future<void> _updateStorage(double newValue) async {
    int newSizeInBytes = (newValue * 1024 * 1024).toInt();
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/allocated_storage.bin';
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    RandomAccessFile raf = await file.open(mode: FileMode.write);
    await raf.setPosition(newSizeInBytes - 1);
    await raf.writeByte(0);
    await raf.close();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('allocatedStorage', newSizeInBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Storage Settings")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text("Allocated Storage: ${_storageValue.toInt()} MB",
                      style: const TextStyle(fontSize: 18)),
                  Slider(
                    value: _storageValue,
                    min: 500,
                    max: 5120, // up to 5GB
                    divisions: ((5120 - 500) ~/ 100),
                    label: "${_storageValue.toInt()} MB",
                    onChanged: (value) {
                      setState(() {
                        _storageValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      _updateStorage(value);
                    },
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _loadStorageSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Storage settings refreshed")),
                      );
                    },
                    child: const Text("Refresh Settings"),
                  )
                ],
              ),
            ),
    );
  }
}
