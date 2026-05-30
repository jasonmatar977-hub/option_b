import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/app_config.dart';
import 'models/backend_models.dart' as backend;
import 'models/service_request.dart';
import 'models/store_crm_models.dart';
import 'services/auth_service.dart';
import 'services/directions_service.dart';
import 'services/firebase_service.dart';
import 'services/google_places_service.dart';
import 'services/job_service.dart';
import 'services/location_service.dart';
import 'services/location_sync_service.dart';
import 'services/marketplace_service.dart';
import 'services/notification_permission_service.dart';
import 'services/notification_service.dart';
import 'services/request_service.dart';
import 'services/storage_service.dart';
import 'services/store_crm_service.dart';
import 'services/user_service.dart';
import 'services/worker_service.dart';
import 'widgets/app_map.dart';

part 'app/app_routes.dart';
part 'app/role_router.dart';
part 'app/omw_app.dart';
part 'app/app_theme.dart';
part 'screens/auth/login_screen.dart';
part 'screens/worker/worker_dashboard_screen.dart';
part 'screens/owner/owner_dashboard_screen.dart';
part 'screens/store_owner/store_owner_dashboard_screen.dart';
part 'screens/customer/customer_dashboard_screen.dart';
part 'screens/marketplace/marketplace_screen.dart';
part 'screens/tracking/tracking_screen.dart';
part 'widgets/common/omw_button.dart';
part 'widgets/common/loading_view.dart';
part 'widgets/common/omw_card.dart';
part 'widgets/common/empty_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.instance.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OptionBApp());
}
