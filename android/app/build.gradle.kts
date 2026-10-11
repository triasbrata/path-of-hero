import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (dev-workflow.md "Android release signing", decisions-log 132). The release signing key lives
// outside the repo: ANDROID_KEY_PROPERTIES names its key.properties (scripts/release-build.sh sets it from the clone's
// `git config poh.androidKeyProperties`); without it, android/key.properties (git-ignored).
// - No key.properties (CI, other machines): release builds are signed with the debug key, with a warning.
// - A key.properties that doesn't work (no keystore, no password): release packaging fails, so a release meant for
//   the real key is never signed with the debug one.
// A password is `storePassword`/`keyPassword`, or (preferred) the first line of the file that `storePasswordFile`/
// `keyPasswordFile` names, so the value is never copied anywhere. Never log a password.
fun expandHome(path: String): File =
    File(if (path.startsWith("~/")) System.getProperty("user.home") + path.substring(1) else path)

val keyPropertiesFile: File =
    System.getenv("ANDROID_KEY_PROPERTIES")?.let { expandHome(it) } ?: rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.isFile) keyPropertiesFile.inputStream().use { keyProperties.load(it) }

fun keyPropertiesPassword(name: String): String? =
    keyProperties.getProperty(name)
        ?: keyProperties.getProperty("${name}File")?.let { path ->
            expandHome(path).takeIf { it.isFile }?.useLines { it.firstOrNull() }
        }

val releaseKeystore: File? =
    keyProperties.getProperty("storeFile")?.let { path ->
        expandHome(path).let { if (it.isAbsolute) it else File(keyPropertiesFile.parentFile, path) }
    }
val releaseKeyAlias: String? = keyProperties.getProperty("keyAlias")
val releaseStorePassword: String? = keyPropertiesPassword("storePassword")
val releaseKeyPassword: String? = keyPropertiesPassword("keyPassword")
val releaseSigningProblem: String? =
    when {
        !keyPropertiesFile.isFile -> null
        releaseKeystore?.isFile != true -> "storeFile is missing or isn't a file ($releaseKeystore)"
        releaseKeyAlias.isNullOrEmpty() -> "keyAlias is missing"
        releaseStorePassword.isNullOrEmpty() -> "storePassword(File) is missing, unreadable or empty"
        releaseKeyPassword.isNullOrEmpty() -> "keyPassword(File) is missing, unreadable or empty"
        else -> null
    }
val hasReleaseKey = keyPropertiesFile.isFile && releaseSigningProblem == null

if (!keyPropertiesFile.isFile) {
    logger.warn(
        "WARNING: no Android release signing key ($keyPropertiesFile not found; set ANDROID_KEY_PROPERTIES). " +
            "Release builds are signed with the DEBUG key: fine for testing, never for a published APK.",
    )
} else if (releaseSigningProblem != null) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { Regex("^(package|sign)Release(Bundle)?$").matches(it.name) }) {
            throw GradleException("Android release signing: $keyPropertiesFile: $releaseSigningProblem")
        }
    }
}

android {
    namespace = "cloud.brata.poh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The final Application ID (decisions-log 133): it can never change once an APK is out, or no update
        // installs over it. MainActivity's package (src/main/kotlin/cloud/brata/poh/) matches the namespace.
        applicationId = "cloud.brata.poh"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Both from pubspec.yaml's `version:` (name+code, e.g. 0.1.0+1): the code must rise with every release,
        // or Android refuses the update. When using split APKs, 1000 * ABI_VERSION is added automatically by
        // Flutter (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions); force
        // the plain versionCode with `-P force-version-code-ignoring-abi=true`.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // The release signing key when key.properties is there, else the debug key (see above).
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
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
