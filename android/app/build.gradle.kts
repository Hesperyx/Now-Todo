// 必须写在最前面：脚本里写 `java.util.Properties()` 会被解析成 Gradle 的 `java`
// 扩展（而不是包名），报 `Unresolved reference: util`。
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 代码包名与上架身份分开：`namespace` 决定 R 类与相对类名（清单里的
    // `.MainActivity`）怎么解析，`applicationId` 才是市场里的身份。
    namespace = "io.github.hesperyx.nowtodo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // `flutter_local_notifications` 从 10.x 起依赖 Java 8+ API 脱糖。
        // 不开这一步，构建会在 `:app:checkReleaseAarMetadata` 直接失败：
        //   Dependency ':flutter_local_notifications' requires core library
        //   desugaring to be enabled for :app.
        // 见插件 README 的「Gradle setup」一节。下面 `dependencies` 里的
        // `coreLibraryDesugaring` 是配套项，缺任意一条都构建不过。
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 上架之后**不可更改**：Android 用它判断「这是同一个应用的升级」
        // 还是「另一个应用」，市场也用它做唯一标识。所以选一个不会过期的：
        // 跟着 GitHub 账号走，而不是域名或某个自造的品牌词。
        applicationId = "io.github.hesperyx.nowtodo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 正式签名用的密钥不进仓库（`android/.gitignore` 已经挡住
        // `key.properties` 与 `*.jks`）。准备步骤见 `android/key.properties.example`。
        create("release") {
            val keyProperties = rootProject.file("key.properties")
            if (keyProperties.exists()) {
                val properties = Properties()
                keyProperties.inputStream().use { properties.load(it) }
                storeFile = file(properties.getProperty("storeFile"))
                storePassword = properties.getProperty("storePassword")
                keyAlias = properties.getProperty("keyAlias")
                keyPassword = properties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 没有 `key.properties` 时退回 debug 签名：这样 `flutter build apk --release`
            // 在没有密钥的开发机上照样能跑（只是**不能上架**，市场上会拒掉）。
            // 有密钥时走正式签名，两种情况共用一个命令。
            signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 与 `android.compileOptions.isCoreLibraryDesugaringEnabled` 配套。
    // 版本按 `flutter_local_notifications` README 指定的 2.1.4；
    // 该版本要求 AGP 8.6+，本项目 `settings.gradle.kts` 用的是 8.9.1。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
