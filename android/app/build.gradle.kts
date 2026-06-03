import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// CI / store builds must not silently fall back to the debug keystore.
val isCiBuild = System.getenv("CI") == "true"
    || System.getenv("CM_BUILD_ID") != null
    || System.getenv("REQUIRE_RELEASE_KEYSTORE") == "true"

android {
    namespace = "app.lapis.todo"
    compileSdk = 36

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.lapis.todo"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Flutter obfuscation — run with:
            //   flutter build apk --obfuscate --split-debug-info=build/debug-info
            // or set the flags below if using the gradle plugin directly.
            // dartObfuscation = true
            // splitDebugInfo = file("build/debug-info")

            signingConfig = when {
                keystorePropertiesFile.exists() -> signingConfigs.getByName("release")
                isCiBuild -> throw GradleException(
                    "Release build requires android/key.properties with a upload keystore. " +
                        "See android/key.properties.example.",
                )
                else -> {
                    logger.warn(
                        "Release build is using the debug keystore. " +
                            "Configure android/key.properties before Play Store upload.",
                    )
                    signingConfigs.getByName("debug")
                }
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
