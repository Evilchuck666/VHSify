# 📼 VHSify

[![Latest release](https://img.shields.io/github/v/release/Evilchuck666/VHSify?label=download&sort=semver)](https://github.com/Evilchuck666/VHSify/releases/latest)
[![Test and release](https://github.com/Evilchuck666/VHSify/actions/workflows/release.yml/badge.svg)](https://github.com/Evilchuck666/VHSify/actions/workflows/release.yml)

**Turn any video into a worn-out VHS tape**: chroma bleed, soft luma, film grain, tracking jitter and tape hiss. It's a small script that runs **FFmpeg** for the picture and **SoX** for the sound, then muxes both into a lossless AVI (UTVideo + PCM float) that you can transcode however you like.

Runs on **GNU/Linux**, **macOS** and **Windows**.

| Platform | Script | Shell |
|---|---|---|
| 🐧 GNU/Linux | `vhsify.sh` | bash 3.2+ |
| 🍎 macOS (Intel & Apple Silicon) | `vhsify.sh` | bash 3.2+ (the stock `/bin/bash` works) |
| 🪟 Windows 10/11 | `vhsify.ps1` | PowerShell 7+ (recommended) or Windows PowerShell 5.1 |

---

## ✨ Features
- VHS‑style **video**: YUV plane separation, heavy down/upscales for chroma bleed, desaturation, grain, and subtle horizontal jitter.
- VHS‑style **audio**: original audio mixed with **brown noise** and a **4 kHz low‑pass** to mimic tape bandwidth.
- Lossless intermediate: **UTVideo** (video) + **PCM float** (audio), easy to transcode later.
- **Single file**, **several files**, or **batch** mode via a JSON (or plain text) list.
- Works with any audio layout (mono, 5.1, 44.1 kHz…), and with **silent videos** too: they get the tape hiss alone.
- Never overwrites your source: output goes next to it as `<name>_vhs.avi` (or to `--output-dir`).
- Temporary files live in a private temp folder that is always cleaned up.

---

## 📦 Requirements
- **FFmpeg** (includes `ffprobe`) in your `PATH`.
- **SoX** in your `PATH`.
- Optional, Linux/macOS: **jq** or **python3** to read JSON lists (plain text lists need nothing).

| Platform | Install |
|---|---|
| Debian / Ubuntu | `sudo apt install ffmpeg sox jq` |
| Fedora | `sudo dnf install ffmpeg sox jq` (FFmpeg from RPM Fusion) |
| Arch Linux | `sudo pacman -S ffmpeg sox jq` |
| macOS ([Homebrew](https://brew.sh)) | `brew install ffmpeg sox jq` |
| Windows ([winget](https://learn.microsoft.com/windows/package-manager/)) | `winget install Gyan.FFmpeg ChrisBagwell.SoX` |
| Windows ([Chocolatey](https://chocolatey.org)) | `choco install ffmpeg sox.portable` |

Check them:
```sh
ffmpeg -version
ffprobe -version
sox --version
```

> **Windows:** use **PowerShell 7 (pwsh)** inside **Windows Terminal** for the best experience. Windows PowerShell 5.1 works too.

---

## ⬇️ Install

Download the latest version for your platform:

| Platform | Download | Contents |
|---|---|---|
| 🐧 GNU/Linux | [**VHSify-linux.tar.gz**](https://github.com/Evilchuck666/VHSify/releases/latest/download/VHSify-linux.tar.gz) | `vhsify.sh`, README, LICENSE |
| 🍎 macOS | [**VHSify-macos.tar.gz**](https://github.com/Evilchuck666/VHSify/releases/latest/download/VHSify-macos.tar.gz) | `vhsify.sh`, README, LICENSE |
| 🪟 Windows | [**VHSify-windows.zip**](https://github.com/Evilchuck666/VHSify/releases/latest/download/VHSify-windows.zip) | `vhsify.ps1`, README, LICENSE |
| 🔐 Checksums | [SHA256SUMS.txt](https://github.com/Evilchuck666/VHSify/releases/latest/download/SHA256SUMS.txt) | SHA‑256 of the packages above |

These links always point to the [latest release](https://github.com/Evilchuck666/VHSify/releases/latest). Older versions are on the [releases page](https://github.com/Evilchuck666/VHSify/releases).

Or install it from the terminal:

**🐧 GNU/Linux**
```sh
curl -fsSL https://github.com/Evilchuck666/VHSify/releases/latest/download/VHSify-linux.tar.gz | tar -xz
cd VHSify-linux
./vhsify.sh --help

# Optional: make it available everywhere as "vhsify"
sudo install -m 755 vhsify.sh /usr/local/bin/vhsify
```

**🍎 macOS**
```sh
curl -fsSL https://github.com/Evilchuck666/VHSify/releases/latest/download/VHSify-macos.tar.gz | tar -xz
cd VHSify-macos
./vhsify.sh --help

# Optional: make it available everywhere as "vhsify"
sudo install -m 755 vhsify.sh /usr/local/bin/vhsify
```

> If you downloaded the package with a browser and Gatekeeper complains, run `xattr -d com.apple.quarantine vhsify.sh`.

**🪟 Windows (PowerShell)**
```powershell
Invoke-WebRequest https://github.com/Evilchuck666/VHSify/releases/latest/download/VHSify-windows.zip -OutFile VHSify-windows.zip
Expand-Archive VHSify-windows.zip -DestinationPath . -Force
cd VHSify-windows
Unblock-File .\vhsify.ps1
.\vhsify.ps1 -Version
```

> If scripts are still blocked, allow local scripts with `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

**🔐 Verify the download (optional)**
```sh
curl -fsSLO https://github.com/Evilchuck666/VHSify/releases/latest/download/SHA256SUMS.txt
sha256sum -c --ignore-missing SHA256SUMS.txt        # GNU/Linux
shasum -a 256 -c --ignore-missing SHA256SUMS.txt    # macOS
```
```powershell
(Get-FileHash VHSify-windows.zip -Algorithm SHA256).Hash   # compare with SHA256SUMS.txt
```

You can also clone the repository and run the scripts from it.

---

## 🚀 Quick start

### GNU/Linux & macOS
```sh
# One or more files
./vhsify.sh ~/Videos/clip.mp4
./vhsify.sh clip1.mp4 clip2.mkv

# Choose where results go
./vhsify.sh -o ~/Videos/vhs clip.mp4

# Batch: JSON array or plain text (one path per line, # for comments)
./vhsify.sh --list list.json

# No arguments: you'll be asked for a path (drag & drop the file onto the terminal)
./vhsify.sh
```

| Option | Description |
|---|---|
| `-l, --list FILE` | Process every video in FILE: a JSON array of paths or a plain text file with one path per line. |
| `-o, --output-dir DIR` | Write results to DIR (created if needed). Default: next to each input. |
| `-s, --suffix TEXT` | Suffix for the output name. Default: `_vhs`. |
| `-h, --help` | Show help. |
| `-V, --version` | Show the version. |

### Windows (PowerShell)
```powershell
# One or more files
.\vhsify.ps1 -InputPath "C:\Videos\clip.mp4"
.\vhsify.ps1 -InputPath "C:\Videos\a.mp4", "C:\Videos\b.mkv"

# Choose where results go
.\vhsify.ps1 -InputPath "C:\Videos\clip.mp4" -OutputDir "D:\VHS"

# Batch: JSON list
.\vhsify.ps1 -JsonPath "C:\Videos\list.json"

# No arguments: you'll be asked for a path (drag & drop works)
.\vhsify.ps1
```

| Parameter | Description |
|---|---|
| `-InputPath <string[]>` | One or more input videos. |
| `-JsonPath <string>` | JSON file with an array of video paths. |
| `-OutputDir <string>` | Write results there (created if needed). Default: next to each input. |
| `-Suffix <string>` | Suffix for the output name. Default: `_vhs`. |
| `-Version` | Show the version. |

### JSON list format
An **array of paths**. Relative paths are resolved from the current folder.
```json
[
  "/home/me/Videos/clip1.mp4",
  "/Users/me/Movies/session.mkv",
  "C:\\Videos\\clip2.mp4"
]
```
> JSON on Windows uses doubled backslashes: `C:\\Videos\\clip.mp4`.

---

## 🧪 Processing pipeline

### Step 0: **VHS FX (video)**
`ffmpeg -filter_complex` pipeline:
- Split into **Y/U/V** with `extractplanes`.
- Luma (Y) down/up: `scale=768:1080` → `scale=1920:1080`.
- Chroma (U/V) down/up: `scale=120:540` → `scale=960:540`.
- Recombine to **yuv420p** via `mergeplanes`.
- Tone & texture: `eq=saturation=0.75`, `noise=alls=5`, and a mild **horizontal jitter** in luma with `geq` + `random()`.

The output is always **1920×1080**, whatever the source resolution.

**Outputs:** `vhs.avi` (video only, **UTVideo**, tagged as `bt709`) and `audio.wav` (source audio as 48 kHz stereo PCM float).

### Step 1: **VHS FX (audio)**
Using **SoX**:
1. Synthesize **brown noise** for the full duration (queried via `ffprobe`). 48 kHz / 32‑bit float / stereo.
2. Mix original audio + noise with gains `inVol` and `outVol` (noise only if the video is silent).
3. Apply a **low‑pass** at **4 kHz**.

**Output:** `vhs.wav`.

### Step 2: **Final mux**
Combine `vhs.avi` (video) + `vhs.wav` (audio) without re‑encoding (`-c copy`) into `<name>_vhs.avi`.

### Step 3: **Cleanup**
Temporaries (`noise.wav`, `mix.wav`, `vhs.avi`, `vhs.wav`, `audio.wav`) are deleted, and the temp folder is removed even if something fails.

---

## 🔧 Default constants

Defined at the top of both scripts (`UPPER_CASE` in `vhsify.sh`, `$global:camelCase` in `vhsify.ps1`).

| Variable          | Default     | Notes                                  |
|-------------------|-------------|----------------------------------------|
| `sampleRate`      | `48000`     | Audio sample rate (Hz)                 |
| `bitDepth`        | `32`        | Float processing depth                 |
| `channels`        | `2`         | Stereo                                 |
| `lowPassFreq`     | `4000`      | Low‑pass cutoff (Hz)                   |
| `inVol`           | `1.0`       | Gain for original track                |
| `outVol`          | `0.077`     | Gain for noise track                   |
| `db`              | `-22.75`    | For `dbVolume` computation             |
| `dbVolume`        | `10^(dB/20)`| Linear factor derived from `db`        |
| `vCodec`          | `utvideo`   | Lossless intermediate                  |
| `aCodec`          | `pcm_f32le` | Float PCM                              |
| `pixFmt`          | `yuv420p`   | Pixel format                           |
| `vidColorspace`   | `bt709`     | Colorimetry signaled on output         |

> Fine‑tune the look in `FFMPEG_FILTER` / `$global:ffmpegFilter` (saturation, noise amount, jitter magnitude, etc.).

---

## 🧰 Post‑processing (optional)
Lossless intermediates are **large** (easily several GB per minute of 1080p). Transcode after inspection:

**To H.264 (high quality):**
```sh
ffmpeg -i "clip_vhs.avi" -c:v libx264 -crf 16 -preset slow -c:a aac -b:a 192k "clip_vhs.mp4"
```
**To H.265/HEVC:**
```sh
ffmpeg -i "clip_vhs.avi" -c:v libx265 -crf 20 -preset slow -tag:v hvc1 -c:a aac -b:a 192k "clip_vhs_hevc.mp4"
```
**Remux to MKV (no re‑encode):**
```sh
ffmpeg -i "clip_vhs.avi" -c copy "clip_vhs.mkv"
```

> **macOS:** QuickTime can't play UTVideo AVI files. Use [IINA](https://iina.io) or [VLC](https://www.videolan.org), or transcode to H.264/HEVC as shown above.

---

## 🧯 Troubleshooting
- **`ffprobe` returns `N/A`** → the source file or container is problematic. Try `ffmpeg -i input -c copy fixed.mkv`, then run the script again.
- **`ffmpeg`/`sox` not found** → install them (see [Requirements](#-requirements)) and make sure they're in your `PATH`.
- **Paths with spaces** → always wrap them in quotes: `"My Videos/clip.mp4"`.
- **`Permission denied` on Linux/macOS** → `chmod +x vhsify.sh`, or run it as `bash vhsify.sh`.
- **"running scripts is disabled" on Windows** → `Unblock-File .\vhsify.ps1` or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- **Emoji/Unicode look broken on Windows** → use **PowerShell 7** in **Windows Terminal**.
- **`The "mapping" option is deprecated` warning** → harmless on recent FFmpeg; the old syntax is kept so the script also works with older FFmpeg versions.
- **Colorimetry looks off in some players** → remux to MKV: `ffmpeg -i clip_vhs.avi -c copy clip_vhs.mkv`.

---

## 🏗️ Releases (for maintainers)
The [Test and release](.github/workflows/release.yml) workflow runs both scripts on generated clips on **Ubuntu**, **macOS** (including the stock bash 3.2) and **Windows** (PowerShell 7 and 5.1) on every push and pull request.

To publish a release:
1. Bump `VERSION` in `vhsify.sh` and `$script:VhsifyVersion` in `vhsify.ps1`, then push to `main`.
2. Go to **Actions → Test and release → Run workflow** and enter the version (e.g. `1.0.1`, without the `v`).

The workflow tests everything, packages `VHSify-linux.tar.gz`, `VHSify-macos.tar.gz` and `VHSify-windows.zip`, generates `SHA256SUMS.txt`, and creates the `vX.Y.Z` tag and GitHub release with auto‑generated notes.

---

## 📜 License
**MIT License**: feel free to use, modify, and distribute. See [LICENSE](LICENSE).
