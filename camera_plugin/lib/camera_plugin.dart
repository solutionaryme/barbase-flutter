
import 'camera_plugin_platform_interface.dart';

class CameraPlugin {
  Future<String?> getPlatformVersion() {
    return CameraPluginPlatform.instance.getPlatformVersion();
  }
}
