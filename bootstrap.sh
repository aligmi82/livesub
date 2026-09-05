#!/usr/bin/env bash
set -euo pipefail

echo "==> project tree"
mkdir -p app/src/main/java/ir/livesub
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/assets/fonts

# ------------------------------------------------------------------ font
echo "==> Vazirmatn font"
FONT=app/src/main/assets/fonts/Vazirmatn-Medium.ttf
for u in \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/vazirmatn/Vazirmatn%5Bwght%5D.ttf" \
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/vazirmatn/Vazirmatn%5Bwght%5D.ttf" \
  "https://cdn.jsdelivr.net/npm/vazirmatn@33.0.3/fonts/ttf/Vazirmatn-Medium.ttf" ; do
  if curl -fsSL "$u" -o "$FONT" 2>/dev/null && [ "$(stat -c%s "$FONT")" -gt 20000 ]; then
    echo "    font from $u"
    break
  fi
  rm -f "$FONT"
done
[ -f "$FONT" ] || echo "    !! font not downloaded, app falls back to sans-serif"

# ------------------------------------------------------------------ gradle
cat > settings.gradle.kts <<'EOF_SETTINGS'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "LiveSub"
include(":app")
EOF_SETTINGS

cat > build.gradle.kts <<'EOF_ROOT'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
EOF_ROOT

cat > gradle.properties <<'EOF_PROPS'
org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
kotlin.daemon.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
EOF_PROPS

cat > app/build.gradle.kts <<'EOF_APP'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "ir.livesub"
    compileSdk = 34

    defaultConfig {
        applicationId = "ir.livesub"
        minSdk = 29
        targetSdk = 34
        versionCode = 2
        versionName = "2.0"
    }

    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}") }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
EOF_APP

if [ -n "${ANDROID_HOME:-}" ]; then
  echo "sdk.dir=$ANDROID_HOME" > local.properties
fi

# ------------------------------------------------------------------ manifest + res
cat > app/src/main/AndroidManifest.xml <<'EOF_MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="false"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.LiveSub">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden|uiMode">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".CaptureService"
            android:exported="false"
            android:foregroundServiceType="mediaProjection|microphone" />
    </application>
</manifest>
EOF_MANIFEST

cat > app/src/main/res/values/strings.xml <<'EOF_STRINGS'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">زیرنویس زنده</string>
</resources>
EOF_STRINGS

cat > app/src/main/res/values/themes.xml <<'EOF_THEMES'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.LiveSub" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">#0F1013</item>
        <item name="android:statusBarColor">#0F1013</item>
        <item name="android:navigationBarColor">#0F1013</item>
    </style>
</resources>
EOF_THEMES

cat > app/src/main/res/drawable/ic_sub.xml <<'EOF_ICON'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M20,4H4C2.9,4 2,4.9 2,6v12c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2V6C22,4.9 21.1,4 20,4zM5,11h3v2H5V11zM14,17H5v-2h9V17zM19,17h-3v-2h3V17zM19,13h-9v-2h9V13z" />
</vector>
EOF_ICON

# ------------------------------------------------------------------ Core.kt
cat > app/src/main/java/ir/livesub/Core.kt <<'EOF_CORE'
package ir.livesub

import android.content.Context
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import okhttp3.ConnectionPool
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.TimeUnit
import kotlin.math.log10
import kotlin.math.sqrt

// ======================================================= وضعیت مشترک

data class UiSettings(
    val fontSizeSp: Float = 22f,
    val bottomDp: Int = 96,
    val showSource: Boolean = true,
)

/** حالت مشترک درون یک پروسه: سرویس می‌نویسد، رابط کاربری می‌خواند. */
object Bus {
    val running = MutableStateFlow(false)
    val status = MutableStateFlow("")
    val lastError = MutableStateFlow<String?>(null)
    val settings = MutableStateFlow(UiSettings())
    val uiTick = MutableStateFlow(0)
}

// ======================================================= تنظیمات

/** سه حالت آماده برای معاوضهٔ تأخیر با کیفیت. */
data class LatencyPreset(val label: String, val chunkMs: Int, val tailMs: Int)

val LATENCY_PRESETS = listOf(
    LatencyPreset("کم‌ترین تأخیر — تکه‌های ۱٫۲ ثانیه", 1_200, 200),
    LatencyPreset("متعادل — تکه‌های ۲ ثانیه", 2_000, 260),
    LatencyPreset("کیفیت بیشتر — تکه‌های ۳٫۵ ثانیه", 3_500, 380),
)

/**
 * فقط یک کلید و یک آدرس: هر دو مرحله روی گروک.
 * نام خانه‌های ذخیره‌سازی از نسخهٔ قبل عوض نشده تا کلید وارد‌شده از دست نرود.
 */
class Prefs(context: Context) {

    private val sp: SharedPreferences = try {
        val key = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context, "livesub_secure", key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (t: Throwable) {
        context.getSharedPreferences("livesub", Context.MODE_PRIVATE)
    }

    private fun s(k: String, d: String) = sp.getString(k, d) ?: d
    private fun w(k: String, v: String) { sp.edit().putString(k, v).apply() }

    var apiKey: String
        get() = s("stt_key", "")
        set(v) { w("stt_key", v) }

    var baseUrl: String
        get() {
            val v = s("stt_url", GROQ_URL)
            // آدرس دیپ‌سیک نسخهٔ قبل خودکار دور ریخته می‌شود
            return if (v.isBlank() || v.contains("deepseek")) GROQ_URL else v
        }
        set(v) { w("stt_url", v) }

    var sttModel: String
        get() {
            val v = s("stt_model", STT_MODEL)
            return if (v.isBlank()) STT_MODEL else v
        }
        set(v) { w("stt_model", v) }

    var chatModel: String
        get() {
            val v = s("ds_model", CHAT_MODEL)
            return if (v.isBlank() || v.startsWith("deepseek")) CHAT_MODEL else v
        }
        set(v) { w("ds_model", v) }

    /** کد ISO زبان مبدأ. "auto" یعنی تشخیص خودکار که کندتر است. */
    var sourceLang: String
        get() = s("src_lang", "en")
        set(v) { w("src_lang", v) }

    /** "internal" = صدای پخش‌شدهٔ گوشی، "mic" = میکروفون */
    var audioSource: String
        get() = s("audio_src", "internal")
        set(v) { w("audio_src", v) }

    var latencyPreset: Int
        get() = sp.getInt("latency", 1).coerceIn(0, LATENCY_PRESETS.size - 1)
        set(v) { sp.edit().putInt("latency", v).apply() }

    var showSource: Boolean
        get() = sp.getBoolean("show_src", true)
        set(v) { sp.edit().putBoolean("show_src", v).apply() }

    var fontSize: Float
        get() = sp.getFloat("font_size", 22f)
        set(v) { sp.edit().putFloat("font_size", v).apply() }

    var bottomDp: Int
        get() = sp.getInt("bottom_dp", 96)
        set(v) { sp.edit().putInt("bottom_dp", v).apply() }

    fun uiSettings() = UiSettings(fontSize, bottomDp, showSource)

    companion object {
        const val GROQ_URL = "https://api.groq.com/openai/v1"
        const val STT_MODEL = "whisper-large-v3-turbo"
        const val CHAT_MODEL = "llama-3.3-70b-versatile"
    }
}

// ======================================================= زبان‌ها

data class Lang(val code: String, val english: String, val fa: String)

val LANGS = listOf(
    Lang("en", "English", "انگلیسی"),
    Lang("ar", "Arabic", "عربی"),
    Lang("tr", "Turkish", "ترکی استانبولی"),
    Lang("ur", "Urdu", "اردو"),
    Lang("hi", "Hindi", "هندی"),
    Lang("es", "Spanish", "اسپانیایی"),
    Lang("fr", "French", "فرانسوی"),
    Lang("de", "German", "آلمانی"),
    Lang("it", "Italian", "ایتالیایی"),
    Lang("pt", "Portuguese", "پرتغالی"),
    Lang("ru", "Russian", "روسی"),
    Lang("uk", "Ukrainian", "اوکراینی"),
    Lang("nl", "Dutch", "هلندی"),
    Lang("sv", "Swedish", "سوئدی"),
    Lang("pl", "Polish", "لهستانی"),
    Lang("el", "Greek", "یونانی"),
    Lang("he", "Hebrew", "عبری"),
    Lang("ja", "Japanese", "ژاپنی"),
    Lang("ko", "Korean", "کره‌ای"),
    Lang("zh", "Chinese", "چینی"),
    Lang("th", "Thai", "تایلندی"),
    Lang("vi", "Vietnamese", "ویتنامی"),
    Lang("id", "Indonesian", "اندونزیایی"),
    Lang("auto", "the source language", "تشخیص خودکار (کندتر)"),
)

fun langOf(code: String): Lang = LANGS.firstOrNull { it.code == code } ?: LANGS[0]

// ======================================================= صدا

object WavEncoder {

    fun encode(pcm: ShortArray, length: Int, sampleRate: Int): ByteArray {
        val dataSize = length * 2
        val bb = ByteBuffer.allocate(44 + dataSize).order(ByteOrder.LITTLE_ENDIAN)
        bb.put("RIFF".toByteArray(Charsets.US_ASCII))
        bb.putInt(36 + dataSize)
        bb.put("WAVE".toByteArray(Charsets.US_ASCII))
        bb.put("fmt ".toByteArray(Charsets.US_ASCII))
        bb.putInt(16)
        bb.putShort(1)
        bb.putShort(1)
        bb.putInt(sampleRate)
        bb.putInt(sampleRate * 2)
        bb.putShort(2)
        bb.putShort(16)
        bb.put("data".toByteArray(Charsets.US_ASCII))
        bb.putInt(dataSize)
        for (i in 0 until length) bb.putShort(pcm[i])
        return bb.array()
    }
}

object AudioCapture {

    const val SAMPLE_RATE = 16_000

    private fun bufferSize(): Int {
        val min = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        val twoSeconds = SAMPLE_RATE * 2 * 2
        return maxOf(if (min > 0) min * 4 else 0, twoSeconds)
    }

    private fun format(): AudioFormat = AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(SAMPLE_RATE)
        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
        .build()

    /**
     * ضبط صدای پخش‌شدهٔ خود دستگاه. برنامه‌های DRM‌دار فقط سکوت می‌دهند.
     */
    fun forPlayback(projection: MediaProjection): AudioRecord {
        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()
        val rec = AudioRecord.Builder()
            .setAudioFormat(format())
            .setBufferSizeInBytes(bufferSize())
            .setAudioPlaybackCaptureConfig(config)
            .build()
        check(rec.state == AudioRecord.STATE_INITIALIZED) { "ضبط صدای دستگاه راه‌اندازی نشد" }
        return rec
    }

    fun forMic(): AudioRecord {
        for (src in intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
        )) {
            val rec = runCatching {
                AudioRecord.Builder()
                    .setAudioSource(src)
                    .setAudioFormat(format())
                    .setBufferSizeInBytes(bufferSize())
                    .build()
            }.getOrNull()
            if (rec != null && rec.state == AudioRecord.STATE_INITIALIZED) return rec
            rec?.release()
        }
        error("میکروفون راه‌اندازی نشد")
    }
}

/**
 * تشخیص گفتار با کف نویز تطبیقی.
 * برای کم‌کردن تأخیر منتظر پایان جمله نمی‌ماند: هر chunkMs یک تکه می‌فرستد،
 * ولی نقطهٔ برش را روی کم‌انرژی‌ترین فریم آخر می‌گذارد تا وسط کلمه نیفتد.
 */
class VadSegmenter(
    private val sampleRate: Int = AudioCapture.SAMPLE_RATE,
    private val frameMs: Int = 20,
    private val minSpeechMs: Int = 260,
    private val tailSilenceMs: Int = 260,
    private val chunkMs: Int = 2_000,
    private val preRollMs: Int = 200,
    private val overlapMs: Int = 100,
    private val cutSearchMs: Int = 320,
    private val speechMarginDb: Float = 9f,
    private val absoluteFloorDb: Float = -50f,
) {
    class Segment(
        val pcm: ShortArray,
        val durationMs: Int,
        val avgDb: Float,
        val continued: Boolean,
        val createdAt: Long,
    )

    private val frameSize = sampleRate * frameMs / 1000
    private val tailFrames = maxOf(1, tailSilenceMs / frameMs)
    private val chunkFrames = maxOf(10, chunkMs / frameMs)
    private val preRollFrames = maxOf(1, preRollMs / frameMs)
    private val overlapFrames = maxOf(1, overlapMs / frameMs)
    private val cutSearchFrames = maxOf(2, cutSearchMs / frameMs)

    private val partial = ShortArray(frameSize)
    private var partialLen = 0

    private val preRoll = ArrayDeque<ShortArray>()
    private val preRollDb = ArrayDeque<Float>()
    private var speech = ArrayList<ShortArray>()
    private var dbs = ArrayList<Float>()
    private var inSpeech = false
    private var silenceRun = 0
    private var noiseFloor = -60f

    var lastFrameDb: Float = -90f
        private set

    fun feed(buf: ShortArray, len: Int, out: (Segment) -> Unit) {
        var i = 0
        while (i < len) {
            val n = minOf(frameSize - partialLen, len - i)
            System.arraycopy(buf, i, partial, partialLen, n)
            partialLen += n
            i += n
            if (partialLen == frameSize) {
                pushFrame(partial.copyOf(), out)
                partialLen = 0
            }
        }
    }

    fun flush(out: (Segment) -> Unit) {
        if (inSpeech) endOfSpeech(out)
    }

    private fun pushFrame(frame: ShortArray, out: (Segment) -> Unit) {
        val db = dbfs(frame)
        lastFrameDb = db
        val isSpeech = db > noiseFloor + speechMarginDb && db > absoluteFloorDb
        if (!isSpeech) {
            // کف نویز فقط در سکوت تطبیق می‌یابد تا با گفتار بالا نرود
            noiseFloor = (noiseFloor * 0.97f + db * 0.03f).coerceIn(-70f, -20f)
        }

        if (inSpeech) {
            speech.add(frame)
            dbs.add(db)
            silenceRun = if (isSpeech) 0 else silenceRun + 1
            if (silenceRun >= tailFrames) endOfSpeech(out)
            else if (speech.size >= chunkFrames) chunkCut(out)
        } else {
            preRoll.addLast(frame)
            preRollDb.addLast(db)
            while (preRoll.size > preRollFrames) {
                preRoll.removeFirst()
                preRollDb.removeFirst()
            }
            if (isSpeech) {
                inSpeech = true
                silenceRun = 0
                speech = ArrayList(preRoll)
                dbs = ArrayList(preRollDb)
                preRoll.clear()
                preRollDb.clear()
            }
        }
    }

    /** جمله تمام شد: سکوت انتهایی جز دو فریم دور ریخته می‌شود. */
    private fun endOfSpeech(out: (Segment) -> Unit) {
        val cut = (speech.size - silenceRun + 2).coerceIn(1, speech.size)
        emit(cut, false, out)
    }

    /** به سقف طول تکه رسیدیم: آرام‌ترین نقطهٔ نزدیک را برای برش پیدا کن. */
    private fun chunkCut(out: (Segment) -> Unit) {
        val total = speech.size
        val from = maxOf(1, total - cutSearchFrames)
        var cut = total
        var best = Float.MAX_VALUE
        for (i in from until total) {
            if (dbs[i] < best) {
                best = dbs[i]
                cut = i + 1
            }
        }
        emit(cut, true, out)
    }

    private fun emit(cutIndex: Int, forceCut: Boolean, out: (Segment) -> Unit) {
        val frames = speech
        val dbList = dbs
        val cut = cutIndex.coerceIn(1, frames.size)
        val head = ArrayList(frames.subList(0, cut))
        val headDb = ArrayList(dbList.subList(0, cut))

        if (forceCut) {
            val keepFrom = maxOf(0, cut - overlapFrames)
            speech = ArrayList(frames.subList(keepFrom, frames.size))
            dbs = ArrayList(dbList.subList(keepFrom, dbList.size))
            inSpeech = true
        } else {
            speech = ArrayList()
            dbs = ArrayList()
            inSpeech = false
            preRoll.clear()
            preRollDb.clear()
        }
        silenceRun = 0

        val voiced = headDb.count { it > absoluteFloorDb }
        if (voiced * frameMs < minSpeechMs) return

        val pcm = ShortArray(head.size * frameSize)
        var p = 0
        for (f in head) {
            System.arraycopy(f, 0, pcm, p, frameSize)
            p += frameSize
        }
        val avg = if (headDb.isEmpty()) -90f else headDb.average().toFloat()
        out(Segment(pcm, head.size * frameMs, avg, forceCut, System.currentTimeMillis()))
    }

    private fun dbfs(f: ShortArray): Float {
        var sum = 0.0
        for (s in f) {
            val v = s / 32768.0
            sum += v * v
        }
        return (20.0 * log10(sqrt(sum / f.size) + 1e-9)).toFloat()
    }
}

// ======================================================= شبکه

object Net {

    private val pool = ConnectionPool(6, 5, TimeUnit.MINUTES)

    private fun base() = OkHttpClient.Builder()
        .connectionPool(pool)
        .connectTimeout(8, TimeUnit.SECONDS)
        .writeTimeout(12, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)

    /** رونویسی: مهلت کوتاه، چون یک درخواست گیرکرده کل صف را عقب می‌اندازد. */
    val stt: OkHttpClient = base()
        .readTimeout(15, TimeUnit.SECONDS)
        .callTimeout(15, TimeUnit.SECONDS)
        .build()

    /** ترجمهٔ استریمی: مهلت بلندتر لازم دارد. */
    val chat: OkHttpClient = base()
        .readTimeout(25, TimeUnit.SECONDS)
        .callTimeout(30, TimeUnit.SECONDS)
        .build()

    /**
     * اتصال TLS را پیش از اولین جمله باز می‌کند و کلید را همان اول اعتبارسنجی می‌کند.
     * حدود نیم ثانیه از تأخیر اولین زیرنویس کم می‌شود.
     */
    suspend fun warmUp(baseUrl: String, apiKey: String) = withContext(Dispatchers.IO) {
        runCatching {
            val req = Request.Builder()
                .url(baseUrl.trimEnd('/') + "/models")
                .addHeader("Authorization", "Bearer " + apiKey)
                .build()
            stt.newCall(req).execute().use { r ->
                r.body?.string()
                if (r.code == 401 || r.code == 403) {
                    Bus.lastError.value = "کلید API پذیرفته نشد (کد " + r.code + ")"
                }
            }
        }
        Unit
    }

    /** آزمایش دستی از داخل برنامه: کلید سالم است؟ مدل‌ها موجودند؟ */
    suspend fun checkKey(
        baseUrl: String,
        apiKey: String,
        sttModel: String,
        chatModel: String,
    ): String = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url(baseUrl.trimEnd('/') + "/models")
                .addHeader("Authorization", "Bearer " + apiKey)
                .build()
            stt.newCall(req).execute().use { r ->
                val body = r.body?.string().orEmpty()
                if (!r.isSuccessful) {
                    return@withContext "پذیرفته نشد (کد " + r.code + "): " + body.take(120)
                }
                val arr: JSONArray? = JSONObject(body).optJSONArray("data")
                val names = ArrayList<String>()
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        names.add(arr.optJSONObject(i)?.optString("id").orEmpty())
                    }
                }
                val a = if (names.contains(sttModel)) "موجود" else "پیدا نشد"
                val b = if (names.contains(chatModel)) "موجود" else "پیدا نشد"
                "کلید سالم است. مدل شنیدن: " + a + " — مدل ترجمه: " + b
            }
        } catch (t: Throwable) {
            "خطای شبکه: " + (t.message ?: "نامعلوم")
        }
    }
}

/** رونویسی با ویسپر روی گروک (سازگار با OpenAI). */
class SttClient(private val http: OkHttpClient = Net.stt) {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val language: String?,
    )

    suspend fun transcribe(wav: ByteArray, cfg: Config, prompt: String?): String =
        withContext(Dispatchers.IO) {
            val body = MultipartBody.Builder().setType(MultipartBody.FORM)
                .addFormDataPart("file", "a.wav", wav.toRequestBody(WAV))
                .addFormDataPart("model", cfg.model)
                .addFormDataPart("response_format", "json")
                .addFormDataPart("temperature", "0")
                .also { b ->
                    // زبان از پیش معلوم است، پس مرحلهٔ تشخیص زبان حذف می‌شود
                    if (!cfg.language.isNullOrBlank() && cfg.language != "auto") {
                        b.addFormDataPart("language", cfg.language)
                    }
                    // متن تکهٔ قبل به عنوان زمینه، برای پیوستگی کلمه‌های بریده
                    if (!prompt.isNullOrBlank()) b.addFormDataPart("prompt", prompt.take(220))
                }
                .build()

            val req = Request.Builder()
                .url(cfg.baseUrl.trimEnd('/') + "/audio/transcriptions")
                .addHeader("Authorization", "Bearer " + cfg.apiKey)
                .post(body)
                .build()

            http.newCall(req).execute().use { r ->
                val text = r.body?.string().orEmpty()
                if (!r.isSuccessful) throw IOException("STT " + r.code + ": " + text.take(200))
                runCatching { JSONObject(text).optString("text") }.getOrDefault("").trim()
            }
        }

    private companion object {
        val WAV = "audio/wav".toMediaType()
    }
}

/** ترجمه با مدل چت گروک، استریمی تا متن فارسی کلمه‌به‌کلمه بیاید. */
class Translator(private val http: OkHttpClient = Net.chat) {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val temperature: Double = 0.2,
    )

    suspend fun translate(
        text: String,
        sourceLanguageEnglish: String,
        cfg: Config,
        history: List<Pair<String, String>>,
        onPartial: (String) -> Unit,
    ): String = withContext(Dispatchers.IO) {

        val messages = JSONArray().apply {
            put(msg("system", systemPrompt(sourceLanguageEnglish)))
            // دو جملهٔ قبلی برای پیوستگی ضمیرها و لحن
            history.takeLast(2).forEach { pair ->
                put(msg("user", pair.first))
                put(msg("assistant", pair.second))
            }
            put(msg("user", text))
        }

        val payload = JSONObject().apply {
            put("model", cfg.model)
            put("messages", messages)
            put("stream", true)
            put("temperature", cfg.temperature)
            put("max_tokens", 260)
        }

        val req = Request.Builder()
            .url(cfg.baseUrl.trimEnd('/') + "/chat/completions")
            .addHeader("Authorization", "Bearer " + cfg.apiKey)
            .addHeader("Accept", "text/event-stream")
            .post(payload.toString().toRequestBody(JSON))
            .build()

        http.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) {
                throw IOException(
                    "Chat " + resp.code + ": " + resp.body?.string()?.take(200).orEmpty()
                )
            }
            val source = resp.body!!.source()
            val out = StringBuilder()
            while (currentCoroutineContext().isActive) {
                val line = source.readUtf8Line() ?: break
                if (!line.startsWith("data:")) continue
                val data = line.substring(5).trim()
                if (data == "[DONE]") break
                val delta = runCatching {
                    JSONObject(data).getJSONArray("choices").getJSONObject(0)
                        .optJSONObject("delta")?.optString("content").orEmpty()
                }.getOrDefault("")
                if (delta.isNotEmpty()) {
                    out.append(delta)
                    onPartial(out.toString())
                }
            }
            out.toString().trim()
        }
    }

    private fun msg(role: String, content: String) =
        JSONObject().put("role", role).put("content", content)

    /** کوتاه نگه داشته شده تا مرحلهٔ prefill سریع‌تر تمام شود. */
    private fun systemPrompt(src: String) = "Translate each line from " + src +
        " into natural spoken Persian. Reply with the Persian only: no quotes, no notes," +
        " no source text, no romanization. Subtitle style, short and idiomatic." +
        " Keep names and numbers. A fragment stays a fragment, never invent an ending." +
        " If nothing is translatable, reply with a single hyphen: -"

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}

// ======================================================= پاک‌سازی متن

/** ویسپر روی موسیقی و سکوت جمله‌های خیالی می‌سازد؛ اینجا فیلتر می‌شوند. */
object TextClean {

    private val ARTIFACTS = setOf(
        "thank you", "thanks", "thanks for watching", "thank you very much",
        "bye", "okay", "ok", "you", "yeah", "hmm", "mm", "uh", "um", "so",
        "subtitles by the amara.org community", "amara.org", "the end",
        "please subscribe", "subscribe to my channel",
        "music", "applause", "silence", "laughter",
    )

    private val BRACKETED = Regex("^[\\[(].*[\\])]$")
    private val PUNCT_ONLY = Regex("^[\\p{Punct}\\s\u266A\u266B\u2026\u00B7\u2014\u2013\u200C]+$")
    private val THINK = Regex("(?s)<think>.*?</think>")

    fun normalize(s: String): String = s
        .replace(THINK, "")
        .replace('\n', ' ')
        .replace(Regex("\\s+"), " ")
        .trim()

    fun isNoise(text: String, durationMs: Int): Boolean {
        if (text.isBlank()) return true
        if (PUNCT_ONLY.matches(text)) return true
        if (BRACKETED.matches(text)) return true
        val key = text.lowercase().trim().trimEnd('.', '!', '?', ',', '\u060C')
        // فقط وقتی تکهٔ صدا کوتاه است حذف می‌کنیم تا دیالوگ واقعی قربانی نشود
        return key in ARTIFACTS && durationMs < 2_000
    }

    fun collapseRepeats(s: String): String {
        val words = s.split(' ')
        if (words.size < 6) return s
        for (l in 1..6) {
            if (words.size < l * 3) continue
            val a = words.subList(words.size - l, words.size)
            val b = words.subList(words.size - 2 * l, words.size - l)
            val c = words.subList(words.size - 3 * l, words.size - 2 * l)
            if (a == b && b == c) {
                var end = words.size
                while (end - 2 * l >= 0 &&
                    words.subList(end - l, end) == words.subList(end - 2 * l, end - l)
                ) end -= l
                return words.subList(0, end).joinToString(" ")
            }
        }
        return s
    }

    /** پیام خطای خام سرویس را به یک جملهٔ کوتاه فارسی تبدیل می‌کند. */
    fun friendlyError(raw: String): String = when {
        raw.contains("401") || raw.contains("403") -> "کلید API پذیرفته نشد"
        raw.contains("402") || raw.contains("insufficient") -> "اعتبار حساب تمام شده"
        raw.contains("429") -> "سقف درخواست پر شد، کمی صبر کنید"
        raw.contains("decommission") || raw.contains("does not exist") -> "نام مدل معتبر نیست"
        raw.contains("timeout", true) || raw.contains("timed out", true) -> "اینترنت کند است"
        raw.contains("Unable to resolve host") || raw.contains("Failed to connect") ->
            "به سرویس وصل نشد"
        else -> raw.take(90)
    }
}
EOF_CORE

# ------------------------------------------------------------------ Overlay.kt
cat > app/src/main/java/ir/livesub/Overlay.kt <<'EOF_OVERLAY'
package ir.livesub

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/** فونت وزیرمتن از assets، با بازگشت بی‌صدا به فونت پیش‌فرض اگر نبود. */
object VazirFont {

    private val CANDIDATES = listOf(
        "fonts/Vazirmatn-Medium.ttf",
        "fonts/Vazirmatn-Regular.ttf",
        "fonts/Vazir-Medium.ttf",
        "fonts/Vazir.ttf",
    )

    @Volatile private var cached: Typeface? = null

    @Volatile var loadedFromAssets: Boolean = false
        private set

    fun get(context: Context): Typeface {
        cached?.let { return it }
        synchronized(this) {
            cached?.let { return it }
            for (path in CANDIDATES) {
                val tf = runCatching { Typeface.createFromAsset(context.assets, path) }.getOrNull()
                if (tf != null) {
                    loadedFromAssets = true
                    cached = tf
                    return tf
                }
            }
            val fallback = Typeface.SANS_SERIF
            cached = fallback
            return fallback
        }
    }
}

/**
 * پنجرهٔ شفاف زیرنویس روی همهٔ برنامه‌ها.
 * FLAG_NOT_TOUCHABLE دارد تا لمس‌ها به پلیر زیرش برسند.
 */
class OverlayController(private val context: Context) {

    private val main = Handler(Looper.getMainLooper())
    private val wm = context.getSystemService(WindowManager::class.java)

    private var root: LinearLayout? = null
    private var sourceView: TextView? = null
    private var persianView: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var settings = UiSettings()

    private val hide = Runnable { root?.visibility = View.GONE }

    fun attach() {
        main.post { if (root == null) build() }
    }

    fun detach() {
        main.post {
            main.removeCallbacks(hide)
            root?.let { v -> runCatching { wm.removeView(v) } }
            root = null
            sourceView = null
            persianView = null
            params = null
        }
    }

    fun applySettings(s: UiSettings) {
        main.post {
            settings = s
            persianView?.setTextSize(TypedValue.COMPLEX_UNIT_SP, s.fontSizeSp)
            sourceView?.setTextSize(TypedValue.COMPLEX_UNIT_SP, s.fontSizeSp * 0.72f)
            sourceView?.visibility = if (s.showSource) View.VISIBLE else View.GONE
            val p = params
            val v = root
            if (p != null && v != null) {
                p.y = dp(s.bottomDp)
                runCatching { wm.updateViewLayout(v, p) }
            }
        }
    }

    /** متن مبدأ پیش از ترجمه دیده می‌شود، پس چشم زودتر چیزی می‌گیرد. */
    fun beginLine(source: String) {
        main.post {
            show()
            sourceView?.setTextColor(0xCCFFFFFF.toInt())
            sourceView?.visibility = if (settings.showSource) View.VISIBLE else View.GONE
            sourceView?.text = source
            persianView?.alpha = 0.45f   // خط قبلی محو می‌ماند تا چشمک نزند
        }
    }

    fun updateTranslation(partial: String) {
        main.post {
            show()
            persianView?.alpha = 1f
            persianView?.text = partial
        }
    }

    fun commitLine(persian: String) {
        main.post {
            show()
            persianView?.alpha = 1f
            persianView?.text = persian
            scheduleHide()
        }
    }

    fun finishLine() {
        main.post {
            persianView?.alpha = 1f
            scheduleHide()
        }
    }

    /** خطا را روی صفحه نشان می‌دهد تا لازم نباشد از فیلم بیرون بیایید. */
    fun showError(message: String) {
        main.post {
            show()
            sourceView?.visibility = View.VISIBLE
            sourceView?.setTextColor(0xFFFF8A80.toInt())
            sourceView?.text = message
            persianView?.text = ""
            persianView?.alpha = 1f
            scheduleHide()
        }
    }

    private fun show() {
        main.removeCallbacks(hide)
        root?.visibility = View.VISIBLE
    }

    private fun scheduleHide() {
        main.removeCallbacks(hide)
        main.postDelayed(hide, 8_000)
    }

    private fun bubble(): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = dp(12).toFloat()
        setColor(0xB8000000.toInt())
    }

    private fun build() {
        val src = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.fontSizeSp * 0.72f)
            setTextColor(0xCCFFFFFF.toInt())
            typeface = Typeface.SANS_SERIF
            gravity = Gravity.CENTER
            textDirection = View.TEXT_DIRECTION_LTR
            background = bubble()
            setPadding(dp(10), dp(4), dp(10), dp(4))
            maxLines = 2
            setShadowLayer(5f, 0f, 1f, Color.BLACK)
            visibility = if (settings.showSource) View.VISIBLE else View.GONE
        }

        val fa = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.fontSizeSp)
            setTextColor(Color.WHITE)
            typeface = VazirFont.get(context)
            gravity = Gravity.CENTER
            textDirection = View.TEXT_DIRECTION_RTL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            background = bubble()
            setPadding(dp(12), dp(6), dp(12), dp(8))
            maxLines = 3
            setLineSpacing(0f, 1.25f)
            setShadowLayer(6f, 0f, 2f, Color.BLACK)
        }

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(14), 0, dp(14), 0)
            addView(
                src,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dp(4) }
            )
            addView(
                fa,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            )
            visibility = View.GONE
        }

        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(settings.bottomDp)
        }

        runCatching { wm.addView(container, p) }
        root = container
        sourceView = src
        persianView = fa
        params = p
    }

    private fun dp(v: Int): Int = (v * context.resources.displayMetrics.density).toInt()
}
EOF_OVERLAY

# ------------------------------------------------------------------ Pipeline.kt
cat > app/src/main/java/ir/livesub/Pipeline.kt <<'EOF_PIPELINE'
package ir.livesub

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * دو مرحلهٔ زنجیره‌وار: تا وقتی تکهٔ n ترجمه می‌شود، تکهٔ n+1 رونویسی می‌شود.
 * ترتیب حفظ می‌شود چون هر مرحله تک‌رشته‌ای است.
 *
 * دو سازوکار برای اینکه زیرنویس عقب نیفتد:
 *  - صف‌ها DROP_OLDEST هستند، پس حال نمایش داده می‌شود نه گذشته
 *  - هر چیزی که بیش از چند ثانیه در صف مانده باشد دور ریخته می‌شود
 */
class SubtitlePipeline(
    private val scope: CoroutineScope,
    private val overlay: OverlayController,
    private val sttCfg: SttClient.Config,
    private val chatCfg: Translator.Config,
    private val sourceLanguageEnglish: String,
) {
    private class Line(val text: String, val createdAt: Long)

    private val stt = SttClient()
    private val translator = Translator()

    private val segments = Channel<VadSegmenter.Segment>(3, BufferOverflow.DROP_OLDEST)
    private val lines = Channel<Line>(3, BufferOverflow.DROP_OLDEST)

    fun start() {
        scope.launch(Dispatchers.IO) { sttLoop() }
        scope.launch(Dispatchers.IO) { translateLoop() }
    }

    fun offer(segment: VadSegmenter.Segment) {
        segments.trySend(segment)
    }

    fun close() {
        segments.close()
        lines.close()
    }

    private suspend fun sttLoop() {
        var previous = ""
        for (seg in segments) {
            if (System.currentTimeMillis() - seg.createdAt > STALE_AUDIO_MS) continue
            try {
                val wav = WavEncoder.encode(seg.pcm, seg.pcm.size, AudioCapture.SAMPLE_RATE)
                var text = TextClean.normalize(stt.transcribe(wav, sttCfg, previous))
                text = TextClean.collapseRepeats(text)
                if (TextClean.isNoise(text, seg.durationMs)) continue
                if (text.equals(previous, ignoreCase = true) && text.length < 30) continue
                previous = text
                lines.trySend(Line(text, System.currentTimeMillis()))
            } catch (c: CancellationException) {
                throw c
            } catch (t: Throwable) {
                report("شنیدن", t)
            }
        }
    }

    private suspend fun translateLoop() {
        val history = ArrayDeque<Pair<String, String>>()
        for (line in lines) {
            if (System.currentTimeMillis() - line.createdAt > STALE_TEXT_MS) continue
            try {
                overlay.beginLine(line.text)
                val fa = TextClean.normalize(
                    translator.translate(line.text, sourceLanguageEnglish, chatCfg, history.toList()) {
                        overlay.updateTranslation(it)
                    }
                )
                if (fa.isBlank() || fa == "-") {
                    overlay.finishLine()
                } else {
                    overlay.commitLine(fa)
                    history.addLast(line.text to fa)
                    while (history.size > 2) history.removeFirst()
                }
                Bus.status.value = "در حال گوش دادن…"
            } catch (c: CancellationException) {
                throw c
            } catch (t: Throwable) {
                report("ترجمه", t)
                overlay.finishLine()
            }
        }
    }

    private suspend fun report(stage: String, t: Throwable) {
        val raw = t.message ?: ""
        val friendly = TextClean.friendlyError(raw)
        Bus.lastError.value = stage + ": " + friendly
        overlay.showError(friendly)
        delay(if (raw.contains("429")) 1_500 else 400)
    }

    private companion object {
        const val STALE_AUDIO_MS = 6_000L
        const val STALE_TEXT_MS = 5_000L
    }
}
EOF_PIPELINE

# ------------------------------------------------------------------ CaptureService.kt
cat > app/src/main/java/ir/livesub/CaptureService.kt <<'EOF_SERVICE'
package ir.livesub

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.IntentCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class CaptureService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var captureJob: Job? = null
    private var pipeline: SubtitlePipeline? = null
    private var overlay: OverlayController? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_START) return START_NOT_STICKY

        val prefs = Prefs(this)
        val internal = prefs.audioSource == "internal"

        createChannel()
        // در اندروید ۱۴ نوع سرویس باید صریح باشد و پیش از getMediaProjection شروع شود
        ServiceCompat.startForeground(
            this, NOTIF_ID, notification(),
            if (internal) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            else ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
        )

        if (!Bus.running.value) {
            val code = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
            val data = IntentCompat.getParcelableExtra(intent, EXTRA_RESULT_DATA, Intent::class.java)
            begin(prefs, internal, code, data)
        }
        return START_NOT_STICKY
    }

    private fun begin(prefs: Prefs, internal: Boolean, resultCode: Int, data: Intent?) {
        // اتصال را همین اول گرم می‌کنیم تا اولین جمله معطل TLS نشود
        scope.launch { Net.warmUp(prefs.baseUrl, prefs.apiKey) }

        val ov = OverlayController(this)
        ov.applySettings(prefs.uiSettings())
        ov.attach()
        overlay = ov

        val rec = try {
            if (internal) {
                require(resultCode == Activity.RESULT_OK && data != null) {
                    "اجازهٔ ضبط صدای دستگاه داده نشد"
                }
                val mpm = getSystemService(MediaProjectionManager::class.java)
                val p = mpm.getMediaProjection(resultCode, data)
                    ?: error("MediaProjection ساخته نشد")
                // در اندروید ۱۴ ثبت callback پیش از شروع ضبط الزامی است
                p.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        shutdown()
                        stopSelf()
                    }
                }, Handler(Looper.getMainLooper()))
                projection = p
                AudioCapture.forPlayback(p)
            } else {
                AudioCapture.forMic()
            }
        } catch (t: Throwable) {
            Bus.lastError.value = t.message ?: "شروع ضبط ناموفق بود"
            shutdown()
            stopSelf()
            return
        }
        record = rec

        val lang = langOf(prefs.sourceLang)
        pipeline = SubtitlePipeline(
            scope = scope,
            overlay = ov,
            sttCfg = SttClient.Config(
                baseUrl = prefs.baseUrl,
                apiKey = prefs.apiKey,
                model = prefs.sttModel,
                language = lang.code,
            ),
            chatCfg = Translator.Config(
                baseUrl = prefs.baseUrl,
                apiKey = prefs.apiKey,
                model = prefs.chatModel,
            ),
            sourceLanguageEnglish = lang.english,
        ).also { it.start() }

        Bus.running.value = true
        Bus.lastError.value = null
        Bus.status.value = "در حال گوش دادن…"

        scope.launch { Bus.settings.collectLatest { ov.applySettings(it) } }

        val preset = LATENCY_PRESETS[prefs.latencyPreset]

        captureJob = scope.launch(Dispatchers.IO) {
            val vad = VadSegmenter(chunkMs = preset.chunkMs, tailSilenceMs = preset.tailMs)
            val buf = ShortArray(AudioCapture.SAMPLE_RATE / 20)   // ۵۰ میلی‌ثانیه
            var lastVoiceAt = System.currentTimeMillis()
            var peakDb = -90f
            rec.startRecording()
            try {
                while (isActive) {
                    val n = rec.read(buf, 0, buf.size)
                    if (n < 0) break
                    if (n == 0) continue
                    vad.feed(buf, n) { seg ->
                        lastVoiceAt = System.currentTimeMillis()
                        pipeline?.offer(seg)
                    }
                    if (vad.lastFrameDb > peakDb) peakDb = vad.lastFrameDb

                    val now = System.currentTimeMillis()
                    if (now - lastVoiceAt > 25_000) {
                        Bus.status.value = if (peakDb < -60f) {
                            "صدایی نمی‌رسد. برنامهٔ پخش احتمالاً با DRM جلوی ضبط صدا را گرفته " +
                                "(نتفلیکس، اسپاتیفای و مانند آن). حالت میکروفون را امتحان کنید."
                        } else {
                            "در حال گوش دادن…"
                        }
                        lastVoiceAt = now
                        peakDb = -90f
                    }
                }
            } finally {
                runCatching { rec.stop() }
                vad.flush { seg -> pipeline?.offer(seg) }
            }
        }
    }

    private fun shutdown() {
        captureJob?.cancel()
        captureJob = null
        pipeline?.close()
        pipeline = null
        record?.let {
            runCatching { it.stop() }
            runCatching { it.release() }
        }
        record = null
        projection?.let { runCatching { it.stop() } }
        projection = null
        overlay?.detach()
        overlay = null
        Bus.running.value = false
        Bus.status.value = ""
    }

    override fun onDestroy() {
        shutdown()
        scope.cancel()
        super.onDestroy()
    }

    private fun createChannel() {
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, "زیرنویس زنده", NotificationManager.IMPORTANCE_LOW
                ).apply { setShowBadge(false) }
            )
        }
    }

    private fun notification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_sub)
        .setContentTitle("زیرنویس زنده روشن است")
        .setContentText("صدای دستگاه در حال ترجمه به فارسی است")
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setContentIntent(
            PendingIntent.getActivity(
                this, 0, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        )
        .addAction(
            R.drawable.ic_sub, "توقف",
            PendingIntent.getService(
                this, 1,
                Intent(this, CaptureService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        )
        .build()

    companion object {
        const val ACTION_START = "ir.livesub.action.START"
        const val ACTION_STOP = "ir.livesub.action.STOP"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        private const val CHANNEL_ID = "livesub_capture"
        private const val NOTIF_ID = 1001
    }
}
EOF_SERVICE

# ------------------------------------------------------------------ MainActivity.kt
cat > app/src/main/java/ir/livesub/MainActivity.kt <<'EOF_MAIN'
package ir.livesub

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.Typeface
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private lateinit var prefs: Prefs

    private val projectionLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
            if (res.resultCode == Activity.RESULT_OK && res.data != null) {
                launchService(res.resultCode, res.data)
            } else {
                Bus.lastError.value = "اجازهٔ ضبط صدای دستگاه داده نشد"
            }
        }

    private val permLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            Bus.uiTick.value = Bus.uiTick.value + 1
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)
        Bus.settings.value = prefs.uiSettings()

        setContent {
            val ctx = LocalContext.current
            val vazir = remember { FontFamily(Typeface(VazirFont.get(ctx))) }
            MaterialTheme(colorScheme = darkColorScheme(), typography = vazirTypography(vazir)) {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    Surface(color = MaterialTheme.colorScheme.background) { Screen() }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Bus.uiTick.value = Bus.uiTick.value + 1
    }

    // ------------------------------------------------------- شروع و توقف

    private fun tryStart() {
        if (prefs.apiKey.isBlank()) {
            Bus.lastError.value = "کلید API گروک را وارد کنید"
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            openOverlaySettings()
            return
        }
        val need = ArrayList<String>()
        need.add(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            need.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val missing = need.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            permLauncher.launch(missing.toTypedArray())
            return
        }
        if (prefs.audioSource == "internal") {
            val mpm = getSystemService(MediaProjectionManager::class.java)
            projectionLauncher.launch(mpm.createScreenCaptureIntent())
        } else {
            launchService(Activity.RESULT_CANCELED, null)
        }
    }

    private fun launchService(code: Int, data: Intent?) {
        val i = Intent(this, CaptureService::class.java).apply {
            action = CaptureService.ACTION_START
            putExtra(CaptureService.EXTRA_RESULT_CODE, code)
            if (data != null) putExtra(CaptureService.EXTRA_RESULT_DATA, data)
        }
        ContextCompat.startForegroundService(this, i)
        moveTaskToBack(true)   // برنامه کنار می‌رود تا فیلم دیده شود
    }

    private fun stopCapture() {
        ContextCompat.startForegroundService(
            this,
            Intent(this, CaptureService::class.java).setAction(CaptureService.ACTION_STOP)
        )
    }

    private fun testKey() {
        Bus.status.value = "در حال آزمایش کلید…"
        lifecycleScope.launch {
            Bus.status.value = Net.checkKey(
                prefs.baseUrl, prefs.apiKey, prefs.sttModel, prefs.chatModel
            )
        }
    }

    private fun openOverlaySettings() = startActivity(
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + packageName))
    )

    // ------------------------------------------------------- رابط کاربری

    @Composable
    private fun Screen() {
        val ctx = LocalContext.current
        val running by Bus.running.collectAsState()
        val status by Bus.status.collectAsState()
        val error by Bus.lastError.collectAsState()
        val tick by Bus.uiTick.collectAsState()

        val canOverlay = remember(tick) { Settings.canDrawOverlays(ctx) }
        val hasMic = remember(tick) {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        }

        var key by remember { mutableStateOf(prefs.apiKey) }
        var baseUrl by remember { mutableStateOf(prefs.baseUrl) }
        var sttModel by remember { mutableStateOf(prefs.sttModel) }
        var chatModel by remember { mutableStateOf(prefs.chatModel) }
        var lang by remember { mutableStateOf(prefs.sourceLang) }
        var audioSrc by remember { mutableStateOf(prefs.audioSource) }
        var latency by remember { mutableStateOf(prefs.latencyPreset) }
        var showSrc by remember { mutableStateOf(prefs.showSource) }
        var fontSize by remember { mutableStateOf(prefs.fontSize) }
        var bottomDp by remember { mutableStateOf(prefs.bottomDp.toFloat()) }
        var advanced by remember { mutableStateOf(false) }

        fun pushLive() {
            Bus.settings.value = UiSettings(fontSize, bottomDp.toInt(), showSrc)
        }

        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("زیرنویس زندهٔ فارسی", style = MaterialTheme.typography.titleLarge)
            Text(
                "صدای پخش‌شده در گوشی را می‌شنود و با گروک به فارسی روی صفحه نشان می‌دهد. " +
                    "فقط یک کلید لازم است.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (!VazirFont.loadedFromAssets) {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF3A2E12))) {
                    Text(
                        "فونت وزیرمتن در این نسخه جا نیفتاده و فونت پیش‌فرض استفاده می‌شود.",
                        Modifier.padding(12.dp),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            Section("کلید گروک")
            OutlinedTextField(
                value = key,
                onValueChange = { key = it; prefs.apiKey = it.trim() },
                label = { Text("کلید API گروک") },
                supportingText = { Text("از console.groq.com، با gsk_ شروع می‌شود") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedButton(onClick = { testKey() }, modifier = Modifier.fillMaxWidth()) {
                Text("آزمایش کلید و مدل‌ها")
            }

            Section("زبان صدا")
            Picker(
                label = "زبان مبدأ",
                options = LANGS.map { it.fa },
                selectedIndex = LANGS.indexOfFirst { it.code == lang }.coerceAtLeast(0),
                onSelect = { i -> lang = LANGS[i].code; prefs.sourceLang = lang },
            )

            Section("سرعت و کیفیت")
            Picker(
                label = "حالت تأخیر",
                options = LATENCY_PRESETS.map { it.label },
                selectedIndex = latency,
                onSelect = { i -> latency = i; prefs.latencyPreset = i },
            )
            Text(
                "تکهٔ کوتاه‌تر یعنی زیرنویس زودتر می‌آید ولی جمله‌ها بریده‌تر و ترجمه خام‌تر " +
                    "می‌شود، و تعداد درخواست‌ها بالا می‌رود.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Section("منبع صدا")
            RadioRow("صدای پخش‌شدهٔ گوشی (بدون DRM)", audioSrc == "internal") {
                audioSrc = "internal"; prefs.audioSource = "internal"
            }
            RadioRow("میکروفون (صدا از بلندگو)", audioSrc == "mic") {
                audioSrc = "mic"; prefs.audioSource = "mic"
            }

            Section("نمایش")
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(
                    checked = showSrc,
                    onCheckedChange = { showSrc = it; prefs.showSource = it; pushLive() },
                )
                Spacer(Modifier.width(8.dp))
                Text("نمایش متن اصلی بالای زیرنویس")
            }
            Text("اندازهٔ متن: " + fontSize.toInt())
            Slider(
                value = fontSize,
                valueRange = 14f..38f,
                onValueChange = { fontSize = it; prefs.fontSize = it; pushLive() },
            )
            Text("فاصله از پایین صفحه: " + bottomDp.toInt())
            Slider(
                value = bottomDp,
                valueRange = 8f..400f,
                onValueChange = { bottomDp = it; prefs.bottomDp = it.toInt(); pushLive() },
            )

            TextButton(onClick = { advanced = !advanced }) {
                Text(if (advanced) "بستن تنظیمات پیشرفته" else "تنظیمات پیشرفته")
            }
            if (advanced) {
                OutlinedTextField(
                    value = baseUrl,
                    onValueChange = { baseUrl = it; prefs.baseUrl = it.trim() },
                    label = { Text("آدرس پایهٔ سرویس") },
                    supportingText = { Text(Prefs.GROQ_URL) },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = sttModel,
                    onValueChange = { sttModel = it; prefs.sttModel = it.trim() },
                    label = { Text("مدل شنیدن") },
                    supportingText = { Text(Prefs.STT_MODEL) },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = chatModel,
                    onValueChange = { chatModel = it; prefs.chatModel = it.trim() },
                    label = { Text("مدل ترجمه") },
                    supportingText = {
                        Text("پیش‌فرض " + Prefs.CHAT_MODEL + " — برای سرعت بیشتر llama-3.1-8b-instant")
                    },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
            }

            Section("دسترسی‌ها")
            PermRow("نمایش روی برنامه‌های دیگر", canOverlay) { openOverlaySettings() }
            PermRow("ضبط صدا", hasMic) {
                permLauncher.launch(arrayOf(Manifest.permission.RECORD_AUDIO))
            }

            Button(
                onClick = { if (running) stopCapture() else tryStart() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                colors = if (running) {
                    ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                } else {
                    ButtonDefaults.buttonColors()
                },
            ) {
                Text(
                    if (running) "توقف زیرنویس" else "شروع زیرنویس",
                    style = MaterialTheme.typography.titleMedium,
                )
            }
            Text(
                "پس از هر تغییر تنظیمات، یک بار توقف و شروع کنید تا اعمال شود.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (status.isNotBlank()) {
                Text(
                    status,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val e = error
            if (e != null) {
                Text(
                    e,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            Text(
                "نکته: نتفلیکس، اسپاتیفای و پخش‌های DRM‌دار اجازهٔ ضبط صدای داخلی نمی‌دهند. " +
                    "برای آن‌ها حالت میکروفون را انتخاب کنید.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(24.dp))
        }
    }

    @Composable
    private fun Section(text: String) = Text(
        text,
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(top = 8.dp),
    )

    @Composable
    private fun RadioRow(text: String, selected: Boolean, onClick: () -> Unit) =
        Row(verticalAlignment = Alignment.CenterVertically) {
            RadioButton(selected = selected, onClick = onClick)
            Spacer(Modifier.width(4.dp))
            Text(text)
        }

    @Composable
    private fun PermRow(title: String, granted: Boolean, onGrant: () -> Unit) = Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(if (granted) "✓ " + title else "• " + title)
        if (!granted) TextButton(onClick = onGrant) { Text("اجازه بده") }
    }

    @Composable
    private fun Picker(
        label: String,
        options: List<String>,
        selectedIndex: Int,
        onSelect: (Int) -> Unit,
    ) {
        var expanded by remember { mutableStateOf(false) }
        Column(Modifier.fillMaxWidth()) {
            Text(
                label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
                Text(options.getOrElse(selectedIndex) { "" })
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEachIndexed { i, opt ->
                    DropdownMenuItem(
                        text = { Text(opt) },
                        onClick = { onSelect(i); expanded = false },
                    )
                }
            }
        }
    }

    private fun vazirTypography(f: FontFamily): Typography {
        val b = Typography()
        return Typography(
            titleLarge = b.titleLarge.copy(fontFamily = f),
            titleMedium = b.titleMedium.copy(fontFamily = f),
            bodyLarge = b.bodyLarge.copy(fontFamily = f),
            bodyMedium = b.bodyMedium.copy(fontFamily = f),
            bodySmall = b.bodySmall.copy(fontFamily = f),
            labelLarge = b.labelLarge.copy(fontFamily = f),
            labelMedium = b.labelMedium.copy(fontFamily = f),
            labelSmall = b.labelSmall.copy(fontFamily = f),
        )
    }
}
EOF_MAIN

echo "==> done"
