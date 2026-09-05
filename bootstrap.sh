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
  "https://cdn.jsdelivr.net/npm/vazirmatn@33.0.3/fonts/ttf/Vazirmatn-Medium.ttf" \
  "https://cdn.jsdelivr.net/npm/vazirmatn@33.0.3/fonts/webfonts/Vazirmatn-Medium.woff2" ; do
  if curl -fsSL "$u" -o "$FONT" 2>/dev/null && [ "$(stat -c%s "$FONT")" -gt 20000 ]; then
    echo "    font from $u"
    break
  fi
  rm -f "$FONT"
done
[ -f "$FONT" ] || echo "    !! font not downloaded, app will fall back to sans-serif"

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
        versionCode = 1
        versionName = "1.0"
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

/**
 * کلیدهای API در EncryptedSharedPreferences ذخیره می‌شوند.
 * اگر Keystore دستگاه مشکل داشت، به حافظهٔ خصوصی رمزنگاری‌نشده برمی‌گردیم.
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

    var deepSeekKey: String
        get() = s("ds_key", "")
        set(v) { w("ds_key", v) }

    var deepSeekBaseUrl: String
        get() = s("ds_url", "https://api.deepseek.com")
        set(v) { w("ds_url", v) }

    var deepSeekModel: String
        get() = s("ds_model", "deepseek-chat")
        set(v) { w("ds_model", v) }

    var sttKey: String
        get() = s("stt_key", "")
        set(v) { w("stt_key", v) }

    var sttBaseUrl: String
        get() = s("stt_url", "https://api.groq.com/openai/v1")
        set(v) { w("stt_url", v) }

    var sttModel: String
        get() = s("stt_model", "whisper-large-v3-turbo")
        set(v) { w("stt_model", v) }

    /** کد ISO زبان مبدأ. "auto" یعنی تشخیص خودکار که کندتر است. */
    var sourceLang: String
        get() = s("src_lang", "en")
        set(v) { w("src_lang", v) }

    /** "internal" = صدای پخش‌شدهٔ گوشی، "mic" = میکروفون */
    var audioSource: String
        get() = s("audio_src", "internal")
        set(v) { w("audio_src", v) }

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

    /** PCM شانزده‌بیتی مونو را به فایل WAV در حافظه تبدیل می‌کند. */
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
     * ضبط صدای پخش‌شدهٔ خود دستگاه. برنامه‌های DRM‌دار یا آن‌هایی که
     * ALLOW_CAPTURE_BY_NONE گذاشته‌اند فقط سکوت می‌دهند.
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

    /** میکروفون، برای برنامه‌هایی که صدای داخلی‌شان قابل ضبط نیست. */
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
 * تشخیص گفتار بر پایهٔ انرژی با کف نویز تطبیقی.
 * جریان PCM را می‌گیرد و هر «جمله» را که تمام شد بیرون می‌دهد،
 * تا فقط تکه‌های معنادار به سرویس رونویسی بروند.
 */
class VadSegmenter(
    private val sampleRate: Int = AudioCapture.SAMPLE_RATE,
    private val frameMs: Int = 20,
    private val minSpeechMs: Int = 350,
    private val tailSilenceMs: Int = 400,
    private val maxSegmentMs: Int = 5_000,
    private val preRollMs: Int = 240,
    private val speechMarginDb: Float = 9f,
    private val absoluteFloorDb: Float = -50f,
) {
    class Segment(
        val pcm: ShortArray,
        val durationMs: Int,
        val avgDb: Float,
        /** true یعنی به سقف طول رسیده و وسط حرف بریده شده است. */
        val continued: Boolean,
    )

    private val frameSize = sampleRate * frameMs / 1000
    private val tailFrames = tailSilenceMs / frameMs
    private val maxFrames = maxSegmentMs / frameMs
    private val preRollFrames = preRollMs / frameMs

    private val partial = ShortArray(frameSize)
    private var partialLen = 0

    private val preRoll = ArrayDeque<ShortArray>()
    private var speech = ArrayList<ShortArray>()
    private var inSpeech = false
    private var silenceRun = 0
    private var dbSum = 0.0
    private var dbCount = 0
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
        if (inSpeech) emit(false, out)
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
            dbSum += db
            dbCount++
            silenceRun = if (isSpeech) 0 else silenceRun + 1
            if (silenceRun >= tailFrames) emit(false, out)
            else if (speech.size >= maxFrames) emit(true, out)
        } else {
            preRoll.addLast(frame)
            while (preRoll.size > preRollFrames) preRoll.removeFirst()
            if (isSpeech) {
                inSpeech = true
                silenceRun = 0
                dbSum = db.toDouble()
                dbCount = 1
                speech = ArrayList(preRoll)   // چند فریم قبل از شروع هم نگه داشته می‌شود
                preRoll.clear()
            }
        }
    }

    private fun emit(forceCut: Boolean, out: (Segment) -> Unit) {
        val frames = speech
        val total = frames.size
        val speechFrames = total - silenceRun
        val avgDb = if (dbCount > 0) (dbSum / dbCount).toFloat() else -90f

        if (forceCut) {
            val keep = minOf(preRollFrames, total)
            speech = ArrayList(frames.subList(total - keep, total))  // همپوشانی تا کلمه نصف نشود
            inSpeech = true
        } else {
            speech = ArrayList()
            inSpeech = false
            preRoll.clear()
        }
        silenceRun = 0
        dbSum = 0.0
        dbCount = 0

        if (speechFrames * frameMs < minSpeechMs) return
        val pcm = ShortArray(total * frameSize)
        var p = 0
        for (f in frames) {
            System.arraycopy(f, 0, pcm, p, frameSize)
            p += frameSize
        }
        out(Segment(pcm, total * frameMs, avgDb, forceCut))
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
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(20, TimeUnit.SECONDS)
        .readTimeout(35, TimeUnit.SECONDS)
        .callTimeout(60, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()
}

/**
 * هر سرویس سازگار با OpenAI که مسیر /audio/transcriptions دارد:
 * Groq (سریع‌ترین)، OpenAI، یا سرور whisper.cpp خودتان.
 * دیپ‌سیک API صوتی ندارد، پس رونویسی از اینجا می‌آید.
 */
class SttClient(private val http: OkHttpClient = Net.client) {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val language: String?,
    )

    suspend fun transcribe(wav: ByteArray, cfg: Config, prompt: String?): String =
        withContext(Dispatchers.IO) {
            val body = MultipartBody.Builder().setType(MultipartBody.FORM)
                .addFormDataPart("file", "audio.wav", wav.toRequestBody(WAV))
                .addFormDataPart("model", cfg.model)
                .addFormDataPart("response_format", "json")
                .addFormDataPart("temperature", "0")
                .also { b ->
                    // زبان از قبل مشخص است، پس مرحلهٔ تشخیص زبان حذف می‌شود
                    if (!cfg.language.isNullOrBlank() && cfg.language != "auto") {
                        b.addFormDataPart("language", cfg.language)
                    }
                    // متن قبلی به عنوان زمینه: دقت اسم‌ها و پیوستگی جمله بالا می‌رود
                    if (!prompt.isNullOrBlank()) b.addFormDataPart("prompt", prompt.take(400))
                }
                .build()

            val req = Request.Builder()
                .url(cfg.baseUrl.trimEnd('/') + "/audio/transcriptions")
                .addHeader("Authorization", "Bearer " + cfg.apiKey)
                .post(body)
                .build()

            http.newCall(req).execute().use { r ->
                val text = r.body?.string().orEmpty()
                if (!r.isSuccessful) throw IOException("STT " + r.code + ": " + text.take(220))
                runCatching { JSONObject(text).optString("text") }.getOrDefault("").trim()
            }
        }

    private companion object {
        val WAV = "audio/wav".toMediaType()
    }
}

/** ترجمه با دیپ‌سیک به صورت استریم تا متن فارسی کلمه‌به‌کلمه ظاهر شود. */
class DeepSeekTranslator(private val http: OkHttpClient = Net.client) {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val temperature: Double = 1.3,   // مقدار پیشنهادی خود دیپ‌سیک برای ترجمه
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
            // چند جملهٔ قبلی برای پیوستگی ضمیرها و لحن
            history.takeLast(3).forEach { pair ->
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
            put("max_tokens", 400)
            put("frequency_penalty", 0.2)
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
                    "DeepSeek " + resp.code + ": " + resp.body?.string()?.take(220).orEmpty()
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

    /** پرامپت ثابت است تا کش زمینهٔ دیپ‌سیک فعال شود و تأخیر اولین توکن کم بماند. */
    private fun systemPrompt(src: String) = """
        You translate live subtitles from $src into Persian (Farsi).
        Output ONLY the Persian translation of the last line: no source text, no quotes,
        no explanations, no transliteration, no romanization.
        Style: natural spoken Persian, short subtitle lines, keep names, numbers and units,
        keep the register of the original (formal, casual or slang).
        If the line is cut mid-sentence, translate the fragment as it is and never invent an ending.
        If there is nothing translatable, reply with a single hyphen: -
    """.trimIndent()

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}

// ======================================================= پاک‌سازی متن

/** ویسپر روی موسیقی و سکوت جملات خیالی می‌سازد؛ اینجا فیلتر می‌شوند. */
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

    fun normalize(s: String): String =
        s.replace('\n', ' ').replace(Regex("\\s+"), " ").trim()

    fun isNoise(text: String, durationMs: Int): Boolean {
        if (text.isBlank()) return true
        if (PUNCT_ONLY.matches(text)) return true
        if (BRACKETED.matches(text)) return true
        val key = text.lowercase().trim().trimEnd('.', '!', '?', ',', '\u060C')
        // فقط وقتی تکهٔ صدا کوتاه است حذف می‌کنیم تا دیالوگ واقعی قربانی نشود
        return key in ARTIFACTS && durationMs < 2_000
    }

    /** حلقهٔ تکرار ویسپر را می‌بندد. */
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

/**
 * فونت وزیرمتن از assets خوانده می‌شود تا اگر فایل نبود بیلد نشکند.
 * مسیر: app/src/main/assets/fonts/
 */
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
 * FLAG_NOT_TOUCHABLE دارد تا لمس‌ها به پلیر زیرش برسند؛
 * جای زیرنویس از داخل خود برنامه تنظیم می‌شود.
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

    /** متن مبدأ چند صد میلی‌ثانیه پیش از ترجمه دیده می‌شود. */
    fun beginLine(source: String) {
        main.post {
            show()
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
 * دو مرحلهٔ زنجیره‌وار: تا وقتی جملهٔ n ترجمه می‌شود، جملهٔ n+1 رونویسی می‌شود.
 * ترتیب حفظ می‌شود چون هر مرحله تک‌رشته‌ای است.
 * صف‌ها DROP_OLDEST هستند: اگر شبکه عقب بیفتد، زیرنویس «حال» را نشان می‌دهد نه گذشته را.
 */
class SubtitlePipeline(
    private val scope: CoroutineScope,
    private val overlay: OverlayController,
    private val sttCfg: SttClient.Config,
    private val dsCfg: DeepSeekTranslator.Config,
    private val sourceLanguageEnglish: String,
) {
    private val stt = SttClient()
    private val translator = DeepSeekTranslator()

    private val segments = Channel<VadSegmenter.Segment>(3, BufferOverflow.DROP_OLDEST)
    private val lines = Channel<String>(4, BufferOverflow.DROP_OLDEST)

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
            try {
                val wav = WavEncoder.encode(seg.pcm, seg.pcm.size, AudioCapture.SAMPLE_RATE)
                var text = TextClean.normalize(stt.transcribe(wav, sttCfg, previous.takeLast(300)))
                text = TextClean.collapseRepeats(text)
                if (TextClean.isNoise(text, seg.durationMs)) continue
                if (text.equals(previous, ignoreCase = true) && text.length < 30) continue
                previous = text
                Bus.status.value = "در حال ترجمه…"
                lines.trySend(text)
            } catch (c: CancellationException) {
                throw c
            } catch (t: Throwable) {
                Bus.lastError.value = "رونویسی: " + t.message
                delay(500)
            }
        }
    }

    private suspend fun translateLoop() {
        val history = ArrayDeque<Pair<String, String>>()
        for (src in lines) {
            try {
                overlay.beginLine(src)
                val fa = TextClean.normalize(
                    translator.translate(src, sourceLanguageEnglish, dsCfg, history.toList()) {
                        overlay.updateTranslation(it)
                    }
                )
                if (fa.isBlank() || fa == "-") {
                    overlay.finishLine()
                } else {
                    overlay.commitLine(fa)
                    history.addLast(src to fa)
                    while (history.size > 3) history.removeFirst()
                }
                Bus.status.value = "در حال گوش دادن…"
            } catch (c: CancellationException) {
                throw c
            } catch (t: Throwable) {
                Bus.lastError.value = "ترجمه: " + t.message
                overlay.finishLine()
                delay(500)
            }
        }
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
                baseUrl = prefs.sttBaseUrl,
                apiKey = prefs.sttKey,
                model = prefs.sttModel,
                language = lang.code,
            ),
            dsCfg = DeepSeekTranslator.Config(
                baseUrl = prefs.deepSeekBaseUrl,
                apiKey = prefs.deepSeekKey,
                model = prefs.deepSeekModel,
            ),
            sourceLanguageEnglish = lang.english,
        ).also { it.start() }

        Bus.running.value = true
        Bus.lastError.value = null
        Bus.status.value = "در حال گوش دادن…"

        scope.launch { Bus.settings.collectLatest { ov.applySettings(it) } }

        captureJob = scope.launch(Dispatchers.IO) {
            val vad = VadSegmenter()
            val buf = ShortArray(AudioCapture.SAMPLE_RATE / 10)   // ۱۰۰ میلی‌ثانیه
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
        if (prefs.deepSeekKey.isBlank()) {
            Bus.lastError.value = "کلید API دیپ‌سیک را وارد کنید"
            return
        }
        if (prefs.sttKey.isBlank() && prefs.sttBaseUrl.startsWith("https")) {
            Bus.lastError.value = "کلید سرویس تبدیل گفتار به متن را وارد کنید"
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
        moveTaskToBack(true)   // برنامه کنار می‌رود تا کاربر فیلمش را ببیند
    }

    private fun stopCapture() {
        ContextCompat.startForegroundService(
            this,
            Intent(this, CaptureService::class.java).setAction(CaptureService.ACTION_STOP)
        )
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

        var dsKey by remember { mutableStateOf(prefs.deepSeekKey) }
        var sttKey by remember { mutableStateOf(prefs.sttKey) }
        var sttUrl by remember { mutableStateOf(prefs.sttBaseUrl) }
        var sttModel by remember { mutableStateOf(prefs.sttModel) }
        var dsUrl by remember { mutableStateOf(prefs.deepSeekBaseUrl) }
        var dsModel by remember { mutableStateOf(prefs.deepSeekModel) }
        var lang by remember { mutableStateOf(prefs.sourceLang) }
        var audioSrc by remember { mutableStateOf(prefs.audioSource) }
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
                "صدای پخش‌شده در گوشی را می‌شنود، رونویسی می‌کند و با دیپ‌سیک " +
                    "به فارسی روی صفحه نشان می‌دهد.",
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

            Section("کلیدها")
            OutlinedTextField(
                value = dsKey,
                onValueChange = { dsKey = it; prefs.deepSeekKey = it.trim() },
                label = { Text("کلید API دیپ‌سیک") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = sttKey,
                onValueChange = { sttKey = it; prefs.sttKey = it.trim() },
                label = { Text("کلید گفتار به متن (Groq یا OpenAI)") },
                supportingText = {
                    Text("دیپ‌سیک API صوتی ندارد، پس رونویسی باید از سرویس دیگری بیاید.")
                },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )

            Section("زبان صدا")
            Picker(
                label = "زبان مبدأ",
                options = LANGS.map { it.fa },
                selectedIndex = LANGS.indexOfFirst { it.code == lang }.coerceAtLeast(0),
                onSelect = { i -> lang = LANGS[i].code; prefs.sourceLang = lang },
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
                    value = sttUrl,
                    onValueChange = { sttUrl = it; prefs.sttBaseUrl = it.trim() },
                    label = { Text("آدرس پایهٔ گفتار به متن") },
                    supportingText = { Text("Groq: https://api.groq.com/openai/v1") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = sttModel,
                    onValueChange = { sttModel = it; prefs.sttModel = it.trim() },
                    label = { Text("مدل گفتار به متن") },
                    supportingText = { Text("whisper-large-v3-turbo") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = dsUrl,
                    onValueChange = { dsUrl = it; prefs.deepSeekBaseUrl = it.trim() },
                    label = { Text("آدرس پایهٔ دیپ‌سیک") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = dsModel,
                    onValueChange = { dsModel = it; prefs.deepSeekModel = it.trim() },
                    label = { Text("مدل دیپ‌سیک") },
                    supportingText = { Text("deepseek-chat سریع است، deepseek-reasoner کند.") },
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

            if (status.isNotBlank()) {
                Text(
                    status,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val e = error
            if (e != null) {
                Text(e, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
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
find . -name "*.kt" -o -name "*.kts" -o -name "*.xml" | sort
