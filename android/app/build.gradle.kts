import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * LAN IPv4 detected on the machine running Gradle (your dev PC). Baked into **debug** APKs so a
 * physical phone on the same Wi‑Fi reaches `http://<this-ip>:LANCY_PORT` without manual JSON edits.
 */
fun findLanIPv4ForDebug(): String {
    return try {
        val candidates = mutableListOf<String>()
        for (nic in NetworkInterface.getNetworkInterfaces()) {
            if (!nic.isUp || nic.isLoopback) continue
            val iface = nic.name.lowercase()
            // Skip typical VPN / tunnel / VM interfaces so we embed the real LAN IP (avoids timeouts on device).
            if (iface.startsWith("tun") || iface.startsWith("tap") ||
                iface.startsWith("ppp") || iface.contains("utun") ||
                iface.startsWith("docker") || iface.startsWith("vethernet") ||
                iface.startsWith("vmnet") || iface.startsWith("vbox")
            ) {
                continue
            }
            for (addr in nic.inetAddresses) {
                if (addr !is Inet4Address || addr.isLoopbackAddress) continue
                val h = addr.hostAddress ?: continue
                if (h.startsWith("169.254.")) continue
                candidates.add(h)
            }
        }
        candidates.firstOrNull { it.startsWith("192.168.") }
            ?: candidates.firstOrNull { it.startsWith("10.") }
            ?: candidates.firstOrNull { it.startsWith("172.") }
            ?: ""
    } catch (_: Exception) {
        ""
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pfe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.pfe"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            buildConfigField("String", "LANCY_DEBUG_LAN_HOST", "\"\"")
        }
        debug {
            val lanHost = findLanIPv4ForDebug()
            buildConfigField("String", "LANCY_DEBUG_LAN_HOST", "\"$lanHost\"")
        }
    }
}

flutter {
    source = "../.."
}
