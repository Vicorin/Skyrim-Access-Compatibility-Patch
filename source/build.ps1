# Builds AccessSpeech.dll, compiles the Papyrus scripts and assembles the FOMOD mod folder + zip.
# Usage:  powershell -ExecutionPolicy Bypass -File build.ps1 [-SkipNative] [-SkipPapyrus]
param(
    [switch]$SkipNative,
    [switch]$SkipPapyrus
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Game = "C:\Program Files (x86)\Steam\steamapps\common\Skyrim Special Edition"
$ModName = "Skyrim Access Compatibility Patches"
$Dist = Join-Path $Root "dist\$ModName"
$Pex = Join-Path $Root "build\papyrus"

# Which compiled script goes into which installer option (folder under Patches\).
# Anything not listed here is part of Core (always installed).
$Patches = @{
    "APDialoguePlayer"               = "AlternatePerspective"
    "b612_TraitsMenu"                = "BiggieTraits"
    "JayUI_Script"                   = "WhyICameToSkyrim"
    "LCO_Access"                     = "Lawbringer"
    "LCO_SimpleControllerBase"       = "Lawbringer"
    "LCO_ShorsWatchtowerController"  = "Lawbringer"
}

# ---- native plugin ----
if (-not $SkipNative) {
    $Build = Join-Path $Root "build"
    & cmake -S $Root -B $Build -G "Visual Studio 17 2022" -A x64
    if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
    & cmake --build $Build --config Release --parallel
    if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }
}

# ---- papyrus ----
if (-not $SkipPapyrus) {
    $Compiler = Join-Path $Game "Papyrus Compiler\PapyrusCompiler.exe"
    $Flags = Join-Path $Game "Data\Source\Scripts\TESV_Papyrus_Flags.flg"
    # SKSE's script sources (Data\Scripts\Source) must come before the vanilla/mod sources so
    # the SKSE versions of Form.psc, UI.psc etc. win.
    $Imports = "$Root\papyrus;$Game\Data\Scripts\Source;$Game\Data\Source\Scripts"
    New-Item -ItemType Directory -Force $Pex | Out-Null
    foreach ($psc in Get-ChildItem (Join-Path $Root "papyrus\*.psc")) {
        & $Compiler $psc.FullName -f="$Flags" -i="$Imports" -o="$Pex" -op
        if ($LASTEXITCODE -ne 0) { throw "Papyrus compile failed: $($psc.Name)" }
    }
}

# ---- assemble mod folder (FOMOD layout) ----
if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $Dist "fomod") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $Dist "Core\SKSE\Plugins") | Out-Null

Copy-Item (Join-Path $Root "fomod\*.xml") (Join-Path $Dist "fomod\") -Force
Copy-Item (Join-Path $Root "build\Release\AccessSpeech.dll") (Join-Path $Dist "Core\SKSE\Plugins\") -Force
Copy-Item (Join-Path $Root "AccessSpeech.ini") (Join-Path $Dist "Core\SKSE\Plugins\") -Force
Copy-Item (Join-Path $Root "README.md") (Join-Path $Dist "$ModName - README.md") -Force

foreach ($psc in Get-ChildItem (Join-Path $Root "papyrus\*.psc")) {
    $name = $psc.BaseName
    $pexFile = Join-Path $Pex "$name.pex"
    if (-not (Test-Path $pexFile)) { throw "missing compiled script: $pexFile" }
    if ($Patches.ContainsKey($name)) {
        $target = Join-Path $Dist "Patches\$($Patches[$name])"
    } else {
        $target = Join-Path $Dist "Core"
    }
    New-Item -ItemType Directory -Force (Join-Path $target "Scripts") | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $target "Source\Scripts") | Out-Null
    Copy-Item $pexFile (Join-Path $target "Scripts\") -Force
    Copy-Item $psc.FullName (Join-Path $target "Source\Scripts\") -Force
}

$Zip = Join-Path $Root "dist\$ModName.zip"
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path (Join-Path $Dist "*") -DestinationPath $Zip
# Keep the copy at the repository root (next to the source folder) in sync.
$RepoZip = Join-Path (Split-Path -Parent $Root) "$ModName.zip"
Copy-Item $Zip $RepoZip -Force
Write-Host "Done: $Zip (copied to $RepoZip)"
