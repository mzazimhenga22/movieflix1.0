import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<List<DownloadTask>?> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  /// Loads all tasks from FlutterDownloader.
  void _loadTasks() {
    _tasksFuture = FlutterDownloader.loadTasks();
  }

  /// Refreshes the task list.
  void _refresh() {
    setState(() {
      _loadTasks();
    });
  }

  /// Deletes a download task and its associated file.
  Future<void> _deleteTask(String taskId) async {
    await FlutterDownloader.remove(
      taskId: taskId,
      shouldDeleteContent: true,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Downloads"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<DownloadTask>?>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final tasks = snapshot.data ?? [];
          // Filter tasks that have completed downloads.
          final downloadedTasks = tasks
              .where((task) => task.status == DownloadTaskStatus.complete)
              .toList();

          if (downloadedTasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "No downloads yet.",
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: downloadedTasks.length,
            itemBuilder: (context, index) {
              final task = downloadedTasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.movie),
                  title: Text(task.filename ?? "Unknown"),
                  subtitle: Text("Saved at: ${task.savedDir}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTask(task.taskId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
