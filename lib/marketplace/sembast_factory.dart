import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

// Import both platforms explicitly so we can use them
import 'package:sembast/sembast_io.dart' as sembast_io;
import 'package:sembast_web/sembast_web.dart' as sembast_web;

// Expose the correct factory depending on platform
DatabaseFactory get databaseFactory =>
    kIsWeb ? sembast_web.databaseFactoryWeb : sembast_io.databaseFactoryIo;
