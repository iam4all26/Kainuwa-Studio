package com.kainuwa.encoder;

import com.k2fsa.sherpa.onnx.GeneratedAudio;
import com.k2fsa.sherpa.onnx.OfflineTts;
import com.k2fsa.sherpa.onnx.OfflineTtsConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsKokoroModelConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig;

import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Offline neural voice (Kokoro, English) made with sherpa-onnx. The voice files are downloaded
 * once from the public sherpa-onnx release and kept in the app's private folder.
 */
final class NeuralVoice {
    static final String NAME = "kokoro-int8-multi-lang-v1_0";
    static final String URL_TEXT =
            "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/" + NAME + ".tar.bz2";
    private static final long FALLBACK_SIZE = 132353410L;

    private final File root;
    private OfflineTts tts;
    private Set<String> lexicon;
    private volatile String state = "idle";
    private volatile int percent = 0;
    private volatile String message = "";
    private volatile boolean downloading = false;

    NeuralVoice(File filesDir) {
        this.root = new File(filesDir, "kainuwa_data/voices");
    }

    File modelDir() {
        return new File(root, NAME);
    }

    boolean installed() {
        return new File(modelDir(), "model.int8.onnx").length() > 0 && new File(modelDir(), ".ok").exists();
    }

    String state() {
        return installed() && !downloading ? "done" : state;
    }

    int percent() {
        return percent;
    }

    String message() {
        return message;
    }

    /** Downloads and unpacks the voice. Runs on the calling thread; call it from a worker. */
    void download() {
        run(null);
    }

    /** Unpacks a voice archive (.tar.bz2) the person downloaded by themselves. Call it from a worker. */
    void importFile(File archive) {
        run(archive);
    }

    private void run(File local) {
        if (downloading) return;
        downloading = true;
        state = "downloading";
        percent = 0;
        message = "";
        File tmp = new File(root, NAME + ".part");
        HttpURLConnection conn = null;
        try {
            deleteAll(tmp);
            tmp.mkdirs();
            InputStream source;
            long total;
            if (local != null) {
                if (!local.exists() || local.length() == 0) throw new IOException("That file is empty or missing.");
                source = new java.io.FileInputStream(local);
                total = local.length();
            } else {
                conn = (HttpURLConnection) new URL(URL_TEXT).openConnection();
                conn.setConnectTimeout(20000);
                conn.setReadTimeout(30000);
                conn.setInstanceFollowRedirects(true);
                if (conn.getResponseCode() != 200) {
                    throw new IOException("The download server answered " + conn.getResponseCode() + ".");
                }
                source = conn.getInputStream();
                total = conn.getContentLengthLong();
                if (total <= 0) total = FALLBACK_SIZE;
            }
            final long size = total;
            final long[] read = new long[] {0};
            InputStream raw = new FilterInputStream(new BufferedInputStream(source, 1 << 16)) {
                @Override
                public int read() throws IOException {
                    int b = super.read();
                    if (b >= 0) count(1);
                    return b;
                }

                @Override
                public int read(byte[] buf, int off, int len) throws IOException {
                    int n = super.read(buf, off, len);
                    if (n > 0) count(n);
                    return n;
                }

                private void count(int n) {
                    read[0] += n;
                    percent = (int) Math.min(99, read[0] * 100 / size);
                }
            };
            TarArchiveInputStream tar = new TarArchiveInputStream(new BZip2CompressorInputStream(raw));
            TarArchiveEntry e;
            byte[] buf = new byte[1 << 16];
            while ((e = tar.getNextTarEntry()) != null) {
                if (e.isDirectory()) continue;
                String name = e.getName();
                int slash = name.indexOf('/');
                String rel = slash >= 0 ? name.substring(slash + 1) : name;
                // Only the English files are needed; the Chinese dictionaries are large.
                if (!(rel.equals("model.int8.onnx") || rel.equals("voices.bin") || rel.equals("tokens.txt")
                        || rel.equals("lexicon-us-en.txt") || rel.equals("lexicon-gb-en.txt"))) {
                    continue;
                }
                OutputStream out = new FileOutputStream(new File(tmp, rel));
                try {
                    int n;
                    while ((n = tar.read(buf)) > 0) out.write(buf, 0, n);
                } finally {
                    out.close();
                }
            }
            tar.close();
            if (!new File(tmp, "model.int8.onnx").exists() || !new File(tmp, "voices.bin").exists()
                    || !new File(tmp, "lexicon-us-en.txt").exists()) {
                throw new IOException("The voice file is incomplete or is not the right one.");
            }
            new File(tmp, ".ok").createNewFile();
            File dir = modelDir();
            deleteAll(dir);
            if (!tmp.renameTo(dir)) throw new IOException("Could not save the voice files.");
            percent = 100;
            state = "done";
        } catch (Throwable t) {
            deleteAll(tmp);
            state = "error";
            String m = t.getMessage();
            message = (m == null || m.isEmpty()) ? t.getClass().getSimpleName() : m;
        } finally {
            if (conn != null) conn.disconnect();
            downloading = false;
        }
    }

    synchronized void delete() {
        try {
            if (tts != null) tts.release();
        } catch (Throwable ignored) {
        }
        tts = null;
        deleteAll(modelDir());
        lexicon = null;
        state = "idle";
        percent = 0;
        message = "";
    }

    private synchronized OfflineTts engine() {
        if (tts != null) return tts;
        String dir = modelDir().getAbsolutePath();
        OfflineTtsKokoroModelConfig kokoro = OfflineTtsKokoroModelConfig.builder()
                .setModel(dir + "/model.int8.onnx")
                .setVoices(dir + "/voices.bin")
                .setTokens(dir + "/tokens.txt")
                .setLexicon(dir + "/lexicon-us-en.txt")
                .setLang("en-us")
                .build();
        OfflineTtsModelConfig model = OfflineTtsModelConfig.builder()
                .setKokoro(kokoro)
                .setNumThreads(Math.max(2, Math.min(4, Runtime.getRuntime().availableProcessors())))
                .setDebug(false)
                .build();
        OfflineTtsConfig config = OfflineTtsConfig.builder().setModel(model).build();
        tts = new OfflineTts(config);
        return tts;
    }


    // ---- Words the voice does not know -------------------------------------------------------
    // The voice looks every word up in a word list and silently skips a word that is not in it.
    // So before speaking, numbers are written as words and unknown words are mended when possible
    // (plural or possessive of a known word, or two known words joined together).

    private synchronized Set<String> words() {
        if (lexicon != null) return lexicon;
        Set<String> set = new HashSet<>();
        for (String name : new String[] {"lexicon-us-en.txt", "lexicon-gb-en.txt"}) {
            File f = new File(modelDir(), name);
            if (!f.exists()) continue;
            try (java.io.BufferedReader r = new java.io.BufferedReader(new java.io.FileReader(f))) {
                String line;
                while ((line = r.readLine()) != null) {
                    int sp = line.indexOf(' ');
                    if (sp > 0) set.add(line.substring(0, sp).toLowerCase());
                }
            } catch (IOException ignored) {
            }
        }
        lexicon = set;
        return set;
    }

    private static final String[] ONES = {"zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
        "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
        "nineteen"};
    private static final String[] TENS = {"", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty",
        "ninety"};

    static String numberWords(long n) {
        if (n < 0) return "minus " + numberWords(-n);
        if (n < 20) return ONES[(int) n];
        if (n < 100) return TENS[(int) (n / 10)] + (n % 10 == 0 ? "" : " " + ONES[(int) (n % 10)]);
        if (n < 1000) return ONES[(int) (n / 100)] + " hundred" + (n % 100 == 0 ? "" : " " + numberWords(n % 100));
        if (n < 1000000) return numberWords(n / 1000) + " thousand" + (n % 1000 == 0 ? "" : " " + numberWords(n % 1000));
        if (n < 1000000000L) return numberWords(n / 1000000) + " million" + (n % 1000000 == 0 ? "" : " " + numberWords(n % 1000000));
        return Long.toString(n);
    }

    private String mend(String word, Set<String> known) {
        String w = word.toLowerCase();
        if (known.contains(w)) return word;
        String base = w;
        if (base.endsWith("'s")) base = base.substring(0, base.length() - 2);
        if (known.contains(base)) return base;
        if (base.endsWith("es") && known.contains(base.substring(0, base.length() - 2))) {
            return base.substring(0, base.length() - 2);
        }
        if (base.endsWith("s") && known.contains(base.substring(0, base.length() - 1))) {
            return base.substring(0, base.length() - 1);
        }
        for (int i = 3; i <= base.length() - 3; i++) {
            String a = base.substring(0, i);
            String b = base.substring(i);
            if (known.contains(a) && (known.contains(b) || (b.endsWith("s") && known.contains(b.substring(0, b.length() - 1))))) {
                return a + " " + b;
            }
        }
        return word;
    }

    String prepare(String text) {
        Set<String> known = words();
        // Whole numbers become words.
        Matcher nm = Pattern.compile("\\d+").matcher(text);
        StringBuffer sb = new StringBuffer();
        while (nm.find()) {
            String d = nm.group();
            String rep = d.length() > 9 ? d : numberWords(Long.parseLong(d));
            nm.appendReplacement(sb, Matcher.quoteReplacement(rep));
        }
        nm.appendTail(sb);
        String t = sb.toString();
        if (known.isEmpty()) return t;
        Matcher wm = Pattern.compile("[A-Za-z']+").matcher(t);
        StringBuffer out = new StringBuffer();
        while (wm.find()) {
            wm.appendReplacement(out, Matcher.quoteReplacement(mend(wm.group(), known)));
        }
        wm.appendTail(out);
        return out.toString();
    }

    /** Loads the voice into memory and runs one tiny sentence, so the first real voice is quicker. */
    synchronized void warmUp() {
        try {
            if (!installed()) return;
            OfflineTts t = engine();
            t.generate("Hello.", 0, 1.0f);
        } catch (Throwable ignored) {
        }
    }

    /** Speaks [text] into the WAV file at [path]. Throws with a readable message on failure. */
    synchronized String speak(String text, String path, int sid, float speed) throws Exception {
        if (!installed()) throw new IOException("The real voice is not downloaded yet.");
        OfflineTts t = engine();
        GeneratedAudio audio = t.generate(prepare(text), sid, speed);
        File out = new File(path);
        File parent = out.getParentFile();
        if (parent != null) parent.mkdirs();
        if (audio == null || audio.getSamples() == null || audio.getSamples().length == 0
                || !audio.save(path) || out.length() == 0) {
            throw new IOException("The real voice made no sound.");
        }
        return path;
    }

    private static void deleteAll(File f) {
        if (f == null || !f.exists()) return;
        File[] kids = f.listFiles();
        if (kids != null) for (File k : kids) deleteAll(k);
        f.delete();
    }
}
