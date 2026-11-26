import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key for Google Play (android/key.properties + upload-keystore.jks,
// both kept out of version control). Without them release builds fall back
// to the debug key, which Play rejects.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Account IDs (AdMob app ID, Play Games project ID) live in
// android/secrets.properties, kept out of version control. Without it the
// build uses Google's public AdMob test app ID and no Play Games project.
val secrets = Properties()
val secretsFile = rootProject.file("secrets.properties")
if (secretsFile.exists()) {
    secrets.load(FileInputStream(secretsFile))
}

android {
    namespace = "com.kodexsolutions.blockboom"
    compileSdk = 37

    buildFeatures {
        resValues = true
    }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications (scheduled reminders).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kodexsolutions.blockboom"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = secrets.getProperty(
            "admobAppId", "ca-app-pub-3940256099942544~3347511713")
        resValue("string", "game_services_project_id",
            secrets.getProperty("playGamesProjectId", "0"))
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-games-v2:21.0.0")
}

// Launch guard: the Play upload bundle (bundleRelease) must carry real IDs,
// never Google's test ads or a missing upload key. Debug builds and the
// sideload APK (assembleRelease) are unaffected.
gradle.taskGraph.whenReady {
    if (allTasks.none { it.name == "bundleRelease" }) return@whenReady
    val problems = mutableListOf<String>()
    if (!keystorePropertiesFile.exists()) {
        problems += "android/key.properties (upload key) is missing"
    }
    val admob = secrets.getProperty("admobAppId", "")
    if (admob.isEmpty() || admob.startsWith("ca-app-pub-3940256099942544")) {
        problems += "android/secrets.properties needs your real admobAppId"
    }
    if (secrets.getProperty("playGamesProjectId", "0") == "0") {
        problems += "android/secrets.properties needs your playGamesProjectId"
    }
    // Flutter hands --dart-define values to Gradle base64-encoded.
    val defines = (project.findProperty("dart-defines") as String? ?: "")
        .split(",").filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        .associate { it.substringBefore("=") to it.substringAfter("=", "") }
    for (key in listOf("ADMOB_REWARDED", "ADMOB_INTERSTITIAL", "PGS_LB_CLASSIC")) {
        if (defines[key].isNullOrEmpty()) {
            problems += "$key is empty (build with --dart-define-from-file=secrets.json)"
        }
    }
    if (problems.isNotEmpty()) {
        throw GradleException(
            "Not building the Play upload bundle:\n - " + problems.joinToString("\n - "))
    }
}
