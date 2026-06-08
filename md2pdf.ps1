param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputFile,
    [Parameter(Position=1)]
    [string]$OutputFile
)

if (-not (Test-Path $InputFile)) {
    Write-Error "File not found: $InputFile"
    exit 1
}

$InputFile = (Resolve-Path $InputFile).Path
$WorkDir = Split-Path $InputFile -Parent
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)

if (-not $OutputFile) {
    $OutputFile = Join-Path $WorkDir "$BaseName.pdf"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile = Join-Path (Get-Location) $OutputFile
}

$HtmlFile = Join-Path $WorkDir "$BaseName.html"
$CssFile = Join-Path $PSScriptRoot "pdf_style.css"

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Error "pandoc not found. Install: winget install --id JohnMacFarlane.Pandoc"
    exit 1
}

$EdgePath = $null
if (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $EdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
} elseif (Test-Path "C:\Program Files\Microsoft\Edge\Application\msedge.exe") {
    $EdgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
} else {
    Write-Error "Edge not found"
    exit 1
}

Write-Host "[1/2] MD -> HTML (pandoc)..." -ForegroundColor Cyan

$pandocArgs = @($InputFile, "-f", "markdown", "-t", "html5", "-s", "--metadata", "title=$BaseName", "--embed-resources", "-o", $HtmlFile)
if (Test-Path $CssFile) {
    $pandocArgs += @("--css=$CssFile")
}
& pandoc @pandocArgs

if (-not (Test-Path $HtmlFile)) {
    Write-Error "HTML generation failed"
    exit 1
}

Write-Host ("      HTML: " + [Math]::Round((Get-Item $HtmlFile).Length / 1KB, 1) + " KB") -ForegroundColor Gray

Write-Host "[2/2] HTML -> PDF (Edge)..." -ForegroundColor Cyan

$OutDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue
}

$HtmlUrl = "file:///" + $HtmlFile.Replace('\', '/')

$oldEAP = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
Start-Process -FilePath $EdgePath -ArgumentList "--headless", "--disable-gpu", "--no-pdf-header-footer", "--print-to-pdf=$OutputFile", $HtmlUrl -Wait -NoNewWindow
$ErrorActionPreference = $oldEAP

Start-Sleep -Seconds 2

Remove-Item $HtmlFile -Force -ErrorAction SilentlyContinue

if (Test-Path $OutputFile) {
    $size = [Math]::Round((Get-Item $OutputFile).Length / 1KB, 1)
    Write-Host "Done: $OutputFile ($size KB)" -ForegroundColor Green
} else {
    Write-Error "PDF generation failed"
    exit 1
}
