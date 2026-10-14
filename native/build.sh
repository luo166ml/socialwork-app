#!/usr/bin/env bash
# 生成社工站原生安卓工程
# 不下载 Android SDK：直接用 aapt2 / d8 / apksigner（若环境已有），否则用 jar 命令打包
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SRC")"
ASSETS="$SRC/assets"
GEN="$SRC/gen"
APP="$SRC/app"
PKG="com/baicang/socialwork"
MANIFEST_PKG="com.baicang.socialwork"

VARIANT="$(cat "$GEN/variant.txt" 2>/dev/null || echo team)"
VERSION="$(cat "$GEN/version.txt" 2>/dev/null || echo 1.0)"

echo "==> 生成 $VARIANT 版（v$VERSION）"

# ---------- 目录结构 ----------
rm -rf "$APP" "$SRC/build"
mkdir -p "$APP/src/main/java/$PKG"
mkdir -p "$APP/src/main/assets"
mkdir -p "$APP/src/main/res/values"
mkdir -p "$APP/src/main/res/mipmap-anydpi-v26"
mkdir -p "$APP/src/main/res/drawable"
mkdir -p "$APP/src/main/res/xml"
mkdir -p "$SRC/build/obj"

cp "$ASSETS/index.html" "$APP/src/main/assets/index.html"

# ---------- AndroidManifest.xml ----------
cat > "$APP/src/main/AndroidManifest.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.baicang.socialwork"
    android:versionCode="1"
    android:versionName="__VERSION__">

    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="33" />

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <application
        android:label="白仓镇民政社工站"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:allowBackup="true"
        android:supportsRtl="true"
        android:hardwareAccelerated="true"
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden|locale|uiMode"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
XML
sed -i "s/__VERSION__/$VERSION/g" "$APP/src/main/AndroidManifest.xml"

# ---------- MainActivity.java ----------
cat > "$APP/src/main/java/$PKG/MainActivity.java" <<'JAVA'
package com.baicang.socialwork;

import android.app.Activity;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.graphics.Color;

public class MainActivity extends Activity {

    private WebView wv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);

        wv = new WebView(this);
        wv.setBackgroundColor(Color.parseColor("#F5F8F6"));

        WebSettings s = wv.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setSupportZoom(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);

        wv.setWebViewClient(new WebViewClient());
        wv.loadUrl("file:///android_asset/index.html");

        setContentView(wv);
    }

    @Override
    public void onBackPressed() {
        if (wv != null && wv.canGoBack()) {
            wv.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
JAVA

# ---------- 资源：图标（矢量前景 + 自适应） ----------
# 前景：绿色水滴 + 白色对勾
cat > "$APP/src/main/res/drawable/ic_launcher_foreground.xml" <<'SVG'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#2E7D5B"
        android:pathData="M54,28 C39,28 28,40 28,55 c0,16 20,38 26,38 6,0 26,-22 26,-38 C80,40 69,28 54,28 Z"/>
    <path android:fillColor="#FFFFFF"
        android:pathData="M44,56 L50,62 L64,46"
        android:strokeWidth="6" android:strokeColor="#FFFFFF"
        android:strokeLineCap="round" android:strokeLineJoin="round"/>
</vector>
SVG

# 背景：圆角方块
cat > "$APP/src/main/res/drawable/ic_launcher_background.xml" <<'SVG'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#E8F3EE"
        android:pathData="M24,24 h60 a12,12 0 0 1 12,12 v48 a12,12 0 0 1 -12,12 h-60 a12,12 0 0 1 -12,-12 v-48 a12,12 0 0 1 12,-12 Z"/>
</vector>
SVG

# 自适应图标 mipmap
for d in m mipmap-anydpi-v26; do
  mkdir -p "$APP/src/main/res/$d"
done
cat > "$APP/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
XML
cp "$APP/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" \
   "$APP/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"

# 回退图标（9-patch 位图），minSdk21 兜底
cat > "$APP/src/main/res/drawable/ic_launcher_legacy.xml" <<'SVG'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp" android:height="48dp"
    android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#2E7D5B"
        android:pathData="M24,8 C14,8 8,18 8,27 c0,11 12,23 16,23 4,0 16,-12 16,-23 C40,18 34,8 24,8 Z"/>
    <path android:fillColor="#FFFFFF"
        android:pathData="M19,27 L23,31 L31,21"
        android:strokeWidth="3" android:strokeColor="#FFFFFF"
        android:strokeLineCap="round" android:strokeLineJoin="round"/>
</vector>
SVG

# ---------- values ----------
cat > "$APP/src/main/res/values/strings.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">白仓镇民政社工站</string>
</resources>
XML

cat > "$APP/src/main/res/values/colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#E8F3EE</color>
</resources>
XML

# 大屏适配
mkdir -p "$APP/src/main/res/values-sw600dp"
cat > "$APP/src/main/res/values-sw600dp/refs.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <bool name="isTablet">true</bool>
</resources>
XML

# ---------- build.gradle ----------
cat > "$APP/build.gradle" <<'GRADLE'
plugins { id 'com.android.application' }
android {
    namespace 'com.baicang.socialwork'
    compileSdk 34
    defaultConfig {
        applicationId "com.baicang.socialwork"
        minSdk 21
        targetSdk 33
        versionCode 1
        versionName "__VERSION__"
    }
    buildFeatures { buildConfig false }
    sourceSets {
        main {
            manifest.srcFile 'src/main/AndroidManifest.xml'
            java.srcDirs = ['src/main/java']
            resources.srcDirs = ['src/main/resources']
            res.srcDirs = ['src/main/res']
            assets.srcDirs = ['src/main/assets']
        }
    }
    signingConfigs { debug { storePassword 'android'; keyPassword 'android' } }
}
GRADLE
sed -i "s/__VERSION__/$VERSION/g" "$APP/build.gradle"

cat > "$SRC/build.gradle" <<'GRADLE'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.4'
    }
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
GRADLE

cat > "$SRC/settings.gradle" <<'GRADLE'
rootProject.name = "SocialWork"
include ':app'
GRADLE

cat > "$APP/proguard-rules.pro" <<'TXT'
# 保留 WebView 与 JS 接口
-keepattributes *Annotation*
-keep class * { @android.webkit.JavascriptInterface <methods>; }
TXT

# gradle wrapper（若本地无 gradle 命令）
mkdir -p "$SRC/gradle/wrapper"
cat > "$SRC/gradle/wrapper/gradle-wrapper.properties" <<'PROP'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
PROP

cat > "$SRC/gradle/wrapper/gradle-wrapper.jar.base64" <<'B64'
PLACEHOLDER_REPLACE_WITH_REAL_WRAPPER_JAR
B64

# ---------- 打包脚本（不依赖 gradle 的兜底方案） ----------
cat > "$SRC/apk_pack.sh" <<'PACK'
#!/usr/bin/env bash
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$SRC/app"
GEN="$SRC/gen"
PKG="com/baicang/socialwork"
VERSION="$(cat "$GEN/version.txt" 2>/dev/null || echo 1.0)"

echo "==> 打包为 APK（不依赖 gradle）"

BUILD="$SRC/build"
rm -rf "$BUILD"
mkdir -p "$BUILD/dex" "$BUILD/unsigned" "$BUILD/signed"

# 1. 编译 R.java
echo "--- 生成 R.java"
R_JAVA="$BUILD/gen/com/baicang/socialwork/R.java"
mkdir -p "$(dirname "$R_JAVA")"
cat > "$R_JAVA" <<'RJAVA'
package com.baicang.socialwork;
public final class R {
    public static final class drawable { public static final int ic_launcher_foreground=0x7f010000; public static final int ic_launcher_background=0x7f010001; public static final int ic_launcher_legacy=0x7f010002; }
    public static final class mipmap { public static final int ic_launcher=0x7f020000; public static final int ic_launcher_round=0x7f020001; }
    public static final class string { public static final int app_name=0x7f030000; }
    public static final class color { public static final int ic_launcher_background=0x7f040000; }
    public static final class bool { public static final int isTablet=0x7f050000; }
    public static final class xml { public static final int app_name=0x7f060000; }
}
RJAVA

# 2. 编译 java
echo "--- 编译 Java"
JAVAC="$BUILD/javac_out"
mkdir -p "$JAVAC"
find "$APP/src/main/java" -name "*.java" > "$BUILD/sources.txt"
javac -source 8 -target 8 -encoding UTF-8 \
    -classpath "$ANDROID_HOME/platforms/android-33/android.jar" \
    -d "$JAVAC" "@$BUILD/sources.txt" 2>&1 | tee "$BUILD/javac.log"

# 3. dx/d8 转 dex
echo "--- 生成 classes.dex"
if command -v d8 >/dev/null 2>&1; then
    d8 --min-api 21 --output "$BUILD/dex" "$JAVAC/com/baicang/socialwork/MainActivity.class"
else
    D8_JAR="$ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | sort -V | tail -1)/lib/d8.jar"
    java -cp "$D8_JAR" com.android.tools.r8.D8 \
        --min-api 21 --output "$BUILD/dex" "$JAVAC/com/baicang/socialwork/MainActivity.class"
fi
cp "$JAVAC/com/baicang/socialwork/R.class" "$BUILD/dex/" 2>/dev/null || true

# 4. 打包资源
echo "--- 打包资源"
AAPT2="$ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | sort -V | tail -1)/aapt2"
RES="$(dirname "$APP/src/main/res")"
$AAPT2 compile --dir "$APP/src/main/res" -o "$BUILD/res.zip"
$AAPT2 link -o "$BUILD/resources-res.apk" \
    -I "$ANDROID_HOME/platforms/android-33/android.jar" \
    --manifest "$APP/src/main/AndroidManifest.xml" \
    -A "$APP/src/main/assets" \
    --java "$BUILD/gen" \
    --min-sdk-version 21 --target-sdk-version 33 \
    --version-code 1 --version-name "$VERSION" \
    --asset-dir "$APP/src/main/assets"

# 5. 组 APK
echo "--- 组装 APK"
cd "$BUILD/dex" && zip -q -r "$BUILD/unsigned/classes.zip" "classes.dex" && cd "$SRC"
cd "$APP/src/main/assets" && zip -q -r "$BUILD/unsigned/assets.zip" "index.html" && cd "$SRC"
cp "$BUILD/resources-res.apk" "$BUILD/unsigned/base.apk"

# 合并
APK="$BUILD/unsigned/app-unsigned.apk"
cp "$BUILD/unsigned/base.apk" "$APK"
cd "$BUILD/unsigned" && zip -q "$APK" "classes.dex" && zip -q "$APK" "index.html" && cd "$SRC"

# 6. 对齐 + 签名
ALIGN="$ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | sort -V | tail -1)/zipalign"
APKSIGNER="$ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | sort -V | tail -1)/apksigner"

$ALIGN -f -p 4 "$APK" "$BUILD/signed/app-aligned.apk"

if [ -n "$KEYSTORE" ] && [ -f "$KEYSTORE" ]; then
    $APKSIGNER sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KEY_PASS" \
        --ks-key-alias "$KS_ALIAS" --min-sdk-version 21 \
        --out "$SRC/app/build/outputs/apk/release/app-release-unsigned.apk" \
        "$BUILD/signed/app-aligned.apk"
    echo "签名完成"
else
    echo "::warning::无签名密钥，使用 debug 签名"
    KEYTOOL="$JAVA_HOME/bin/keytool"
    TMPKS="$BUILD/debug.keystore"
    $KEYTOOL -genkeypair -v -keystore "$TMPKS" -storepass android -keypass android \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Debug,O=Android,C=US" 2>/dev/null
    $APKSIGNER sign --ks "$TMPKS" --ks-pass pass:android --key-pass pass:android \
        --ks-key-alias androiddebugkey --min-sdk-version 21 \
        --out "$SRC/app/build/outputs/apk/debug/app-debug.apk" \
        "$BUILD/signed/app-aligned.apk"
    echo "debug 签名完成"
fi

echo "==> 打包成功"
ls -lh "$SRC/app/build/outputs/apk/release/" "$SRC/app/build/outputs/apk/debug/" 2>/dev/null
PACK
chmod +x "$SRC/apk_pack.sh"

echo "==> 原生工程生成完成"
find "$APP" -type f | head -40
