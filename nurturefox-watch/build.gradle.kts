plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.toleary.babyclock"
    compileSdk = 36 // Updated to match your previous screenshot

    defaultConfig {
        applicationId = "com.toleary.babyclock"
        minSdk = 30
        targetSdk = 36
        versionCode = 9
        versionName = "2.2"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    useLibrary("wear-sdk")
    buildFeatures {
        compose = true
    }
}

dependencies {
    // 1. Wear OS Core & Communication
    implementation("com.google.android.gms:play-services-wearable:18.1.0")

    // 2. Coroutine Bridges (Mandatory for .await() and .future {})
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.7.3")

    // 3. Modern Tiles & ProtoLayout (Hardcoded to override old 'libs' versions)
    implementation("androidx.wear.tiles:tiles:1.4.0")
    implementation("androidx.wear.protolayout:protolayout:1.2.0")
    implementation("androidx.wear.protolayout:protolayout-material:1.2.0")

    // 4. Complications & Splash Screen
    implementation(libs.androidx.watchface.complications.data.source.ktx)
    implementation(libs.androidx.core.splashscreen)

    // 5. Compose for Wear OS (Standard UI)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.wear.tooling.preview)
    implementation(libs.androidx.activity.compose)

    // 6. Debug & Testing
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    // Removed duplicate libs.androidx.tiles references to prevent version clashing
}