# make-preview.ps1
# Genere un clip preview leger (sans son, accelere, en boucle) a partir d'une video source.
# Usage :
#   .\make-preview.ps1 -InputFile "C:\videos\ai-viator-source.mp4" -OutputFile "PREVIEWS\ai-viator.mp4"
#
# Parametres optionnels :
#   -Segments         nombre de bouts extraits (defaut 5)
#   -SegmentDuration   duree de chaque bout en secondes (defaut 0.7)
#   -Speed             facteur d'acceleration (defaut 1.5 = 1.5x plus rapide)
#   -Width             largeur de sortie en pixels (defaut 480, suffisant pour une vignette)

param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [Parameter(Mandatory=$true)][string]$OutputFile,
    [int]$Segments = 5,
    [double]$SegmentDuration = 0.7,
    [double]$Speed = 1.5,
    [int]$Width = 480
)

if (!(Test-Path $InputFile)) {
    Write-Host "ERREUR : fichier source introuvable -> $InputFile" -ForegroundColor Red
    exit 1
}

$durationStr = ffprobe -v error -show_entries format=duration -of csv=p=0 $InputFile
$duration = [double]$durationStr
Write-Host "Duree source : $([math]::Round($duration,2))s"

if ($duration -lt 3) {
    Write-Host "Video courte (<3s) : on prend toute la duree, accelere x$Speed, sans decoupe." -ForegroundColor Yellow
    ffmpeg -y -i $InputFile -vf "setpts=PTS/$Speed,scale=${Width}:-2" -an -c:v libx264 -profile:v high -pix_fmt yuv420p -movflags +faststart -crf 26 -preset slow $OutputFile
    Write-Host "Cree : $OutputFile" -ForegroundColor Green
    exit 0
}

$tempDir = Join-Path $env:TEMP "preview_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$listFile = Join-Path $tempDir "list.txt"
Remove-Item $listFile -ErrorAction SilentlyContinue

$margin = $duration * 0.05
$usable = $duration - (2 * $margin)
$step = $usable / $Segments

for ($i = 0; $i -lt $Segments; $i++) {
    $start = $margin + ($i * $step) + (($step - $SegmentDuration) / 2)
    if ($start -lt 0) { $start = 0.1 }
    $segFile = Join-Path $tempDir "seg$i.mp4"
    Write-Host "Segment $($i+1)/$Segments a partir de $([math]::Round($start,2))s..."
    ffmpeg -y -ss $start -i $InputFile -t $SegmentDuration -vf "setpts=PTS/$Speed,scale=${Width}:-2" -an -c:v libx264 -pix_fmt yuv420p -preset fast $segFile 2>$null
    "file '$($segFile -replace "\\","/")'" | Add-Content $listFile
}

ffmpeg -y -f concat -safe 0 -i $listFile -c:v libx264 -profile:v high -pix_fmt yuv420p -movflags +faststart -crf 26 -preset slow -an $OutputFile

Remove-Item $tempDir -Recurse -Force
Write-Host "Cree : $OutputFile" -ForegroundColor Green
$outDuration = ffprobe -v error -show_entries format=duration -of csv=p=0 $OutputFile
Write-Host "Duree finale : $([math]::Round([double]$outDuration,2))s"
