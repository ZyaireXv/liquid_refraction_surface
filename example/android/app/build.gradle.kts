plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 这个参数只服务于 Android 调试场景下的后端复现。
//
// 这次项目里要排查的是 Impeller 在 OpenGLES / Vulkan 两条路径上的坐标差异，
// 问题本身和包逻辑有关，不应该靠长期修改 AndroidManifest 来回切换后端。
// 所以这里把入口收在 Gradle 参数里：
// - 默认不传，保持 Flutter 的自动选择逻辑
// - 需要压测某条分支时，再显式传 `impellerBackend`
//
// 这样做的重点不是“让业务永久绑定某个后端”，
// 而是把测试手段做成一次性、可回退、不会污染 release 的配置。
val impellerBackend = providers
    .gradleProperty("impellerBackend")
    .orElse("")
    .get()
    .trim()
    .lowercase()

check(impellerBackend in setOf("", "opengles", "vulkan")) {
    "impellerBackend 只允许为空、opengles 或 vulkan，当前值为: $impellerBackend"
}

android {
    namespace = "com.example.example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 这里只给 debug / profile manifest 提供占位符，
        // release 构建不会合并那两份 manifest，因此不会把测试用后端写进正式包。
        manifestPlaceholders["impellerBackend"] = impellerBackend
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
