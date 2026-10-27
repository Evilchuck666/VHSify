<#
.SYNOPSIS
    VHSify — give any video a worn-out VHS look (video + audio) with FFmpeg and SoX.

.EXAMPLE
    .\vhsify.ps1 -InputPath "C:\Videos\clip.mp4"

.EXAMPLE
    .\vhsify.ps1 -JsonPath "C:\Videos\list.json" -OutputDir "D:\VHS"
#>
param (
    [string[]]$InputPath,
    [string]$JsonPath,
    [string]$OutputDir,
    [string]$Suffix = "_vhs",
    [switch]$Version
)

$script:VhsifyVersion = "1.0.0"


# === Global Constants === #

# 🔧 General Settings
$global:sampleRate      = 48000
$global:bitDepth        = 32
$global:channels        = 2
$global:lowPassFreq     = 4000
$global:inVol           = "1.0"
$global:outVol          = "0.077"
$global:db              = -22.75
$global:dbVolume        = ([math]::Pow(10, $db/20)).ToString([System.Globalization.CultureInfo]::InvariantCulture)

# 🎨 VHS Filter (ffmpeg)
$global:ffmpegFilter = @(
    "[0:v:0] format=yuv420p, split=3 [a][b][c]"
    "[a] extractplanes=y [y]"
    "[b] extractplanes=u [u]"
    "[c] extractplanes=v [v]"
    "[y] scale=768:1080, scale=1920:1080 [luma_scaled]"
    "[u] scale=120:540, scale=960:540 [u_scaled]"
    "[v] scale=120:540, scale=960:540 [v_scaled]"
    "[luma_scaled][u_scaled][v_scaled] mergeplanes=0x001020:yuv420p [merged]"
    "[merged] eq=saturation=0.75, noise=alls=5:allf=t, geq='lum(X+5.5*(random(floor(Y/96))-0.5),Y)':cb='cb(X,Y)':cr='cr(X,Y)' [outv]"
) -join "; "

# 📁 Files (temporary, inside a private work folder)
$global:workDir         = Join-Path ([System.IO.Path]::GetTempPath()) ("vhsify-" + [guid]::NewGuid().ToString("N"))
$global:vhsFile         = Join-Path $workDir "vhs.avi"
$global:wavFile         = Join-Path $workDir "audio.wav"
$global:wavFxFile       = Join-Path $workDir "vhs.wav"
$global:noise           = Join-Path $workDir "noise.wav"
$global:mix             = Join-Path $workDir "mix.wav"

# 🎞️ Codecs & formats
$global:vCodec          = "utvideo"
$global:aCodec          = "pcm_f32le"
$global:pixFmt          = "yuv420p"
$global:vidColorspace   = "bt709"


# === Global Variables === #
$global:InputVideoPath  = ""


# === Functions === #
function Fail {
    param ([string]$Message)

    Write-Host "Error: $Message" -ForegroundColor Red
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

function Invoke-Tool {
    param (
        [string]$Tool,
        [string[]]$ToolArgs
    )

    & $Tool @ToolArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "'$Tool' failed with exit code $LASTEXITCODE."
    }
}

function CheckDependencies {
    foreach ($tool in @("ffmpeg", "ffprobe", "sox")) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Fail "'$tool' not found in PATH. See the README for install instructions."
        }
    }
}

function ProcessJsonList {
    if (-not (Test-Path -LiteralPath $JsonPath)) {
        Fail "The JSON file '$JsonPath' does not exist."
    }

    $jsonContent = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($video in $jsonContent) {
        ProcessVideo -VideoPath "$video"
    }
}

function ProcessVideo {
    param (
        [string]$VideoPath
    )

    if (-not (Test-Path -LiteralPath $VideoPath -PathType Leaf)) {
        Fail "File '$VideoPath' does not exist."
    }

    $global:InputVideoPath = (Resolve-Path -LiteralPath $VideoPath).Path
    Write-Host "#### Processing: $global:InputVideoPath ####"

    $audioStreams = & ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$global:InputVideoPath"
    $hasAudio = [bool]$audioStreams

    Step0_VhsFx -HasAudio $hasAudio
    Step1_AudioFx -HasAudio $hasAudio
    Step2_MapInputs
    Step3_Clean
}

function GetInputVideoPath {
    Write-Host "Drag the video here or type the full path"
    $path = Read-Host "Video path"
    $path = $path.Trim().Trim('"').Trim("'")

    if (-not $path) {
        Fail "No video given."
    }

    return $path
}

function Step0_VhsFx {
    param ([bool]$HasAudio)

    Write-Host "#### Running Step 0: Applying VHS Effect to video ####"

    $ffArgs = @(
        '-hide_banner', '-loglevel', 'warning', '-stats', '-y',
        '-i', $global:InputVideoPath,
        '-filter_complex', $ffmpegFilter,
        '-map', '[outv]',
        '-c:v', $vCodec,
        '-pix_fmt', $pixFmt,
        '-colorspace', $vidColorspace,
        '-color_primaries', $vidColorspace,
        '-color_trc', $vidColorspace,
        $vhsFile
    )

    if ($HasAudio) {
        $ffArgs += @('-map', '0:a:0', '-c:a', $aCodec, '-ar', $sampleRate, '-ac', $channels, $wavFile)
    }

    Invoke-Tool "ffmpeg" $ffArgs
}

function Step1_AudioFx {
    param ([bool]$HasAudio)

    Write-Host "#### Running Step 1: Applying VHS Effect to audio ####"

    # === Get duration using ffprobe === #
    $duration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$global:InputVideoPath"
    $duration = "$duration".Trim()

    if (-not $duration -or $duration -eq "N/A") {
        Fail "Cannot get the duration from input file."
    }

    # 1. Brown noise
    Invoke-Tool "sox" @(
        "-n", "-r", $sampleRate, "-b", $bitDepth, "-e", "floating-point",
        "-c", $channels, $noise, "synth", $duration, "brownnoise", "vol", $dbVolume
    )

    if ($HasAudio) {
        # 2. Mix
        Invoke-Tool "sox" @("-m", "-v", $inVol, $wavFile, "-v", $outVol, $noise, $mix)
    } else {
        # No audio track: the tape hiss is all there is.
        Invoke-Tool "sox" @("-v", $outVol, $noise, $mix)
    }

    # 3. Low-pass filter
    Invoke-Tool "sox" @($mix, $wavFxFile, "lowpass", $lowPassFreq)
}

function Step2_MapInputs {
    Write-Host "#### Running Step 2: Mixing video and audio tracks into a single file ####"

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($global:InputVideoPath) -replace '[:*?"<>|]', '-'
    $targetDir = if ($OutputDir) { $OutputDir } else { Split-Path -Parent $global:InputVideoPath }
    $finalPath = Join-Path $targetDir "$baseName$Suffix.avi"

    Invoke-Tool "ffmpeg" @(
        "-hide_banner", "-loglevel", "error", "-y",
        "-i", $vhsFile,
        "-i", $wavFxFile,
        "-map", "0:v",
        "-map", "1:a",
        "-c", "copy",
        $finalPath
    )

    Write-Host "#### Done: $finalPath ####"
}

function Step3_Clean {
    Remove-Item @($noise, $mix, $vhsFile, $wavFxFile, $wavFile) -ErrorAction SilentlyContinue
}

function Main {
    if ($Version) {
        Write-Host "VHSify $script:VhsifyVersion"
        return
    }

    CheckDependencies

    if ($OutputDir) {
        New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
        $script:OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
    }

    New-Item -ItemType Directory -Force -Path $workDir | Out-Null

    try {
        if ($JsonPath) {
            ProcessJsonList
        } else {
            if (-not $InputPath) {
                $InputPath = @(GetInputVideoPath)
            }
            foreach ($video in $InputPath) {
                ProcessVideo -VideoPath $video.Trim('"')
            }
        }
    } finally {
        Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}


# === Main === #
Main
