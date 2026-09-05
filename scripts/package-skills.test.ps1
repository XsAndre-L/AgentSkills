#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('skill-packaging-test-' + [guid]::NewGuid().ToString('N'))
$packager = Join-Path $PSScriptRoot 'package-skills.ps1'
$source = Join-Path $fixture 'skills/demo'

function Invoke-Packager([switch]$Check) {
    $arguments = @('-NoProfile', '-File', $packager, '-RepositoryRoot', $fixture)
    if ($Check) { $arguments += '-Check' }
    & pwsh @arguments | Out-Host
    return $LASTEXITCODE
}

try {
    New-Item -ItemType Directory -Path (Join-Path $source 'assets') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'SKILL.md') -Value "---`nname: demo`ndescription: Test.`n---`n"
    $asset = Join-Path $source 'assets/binary.dat'
    [IO.File]::WriteAllBytes($asset, [byte[]]@(0, 255, 13, 10, 128))
    if ((Invoke-Packager) -ne 0 -or (Invoke-Packager -Check) -ne 0) { throw 'Fresh package failed' }
    $archivePath = Join-Path $fixture 'packages/demo.skill'
    $original = (Get-FileHash -LiteralPath $archivePath).Hash
    [IO.File]::WriteAllBytes($asset, [byte[]]@(1, 2, 3))
    if ((Invoke-Packager -Check) -ne 1) { throw 'Changed file was not detected' }
    if ((Get-FileHash -LiteralPath $archivePath).Hash -ne $original) { throw 'Check modified the archive' }
    Set-Content -LiteralPath (Join-Path $source 'added.md') -Value 'new source'
    Remove-Item -LiteralPath $asset
    if ((Invoke-Packager -Check) -ne 1) { throw 'Added/removed files were not detected' }
    if ((Invoke-Packager) -ne 0 -or (Invoke-Packager -Check) -ne 0) { throw 'Rebuild failed' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Update)
    try { $zip.CreateEntry('demo/SKILL.md') | Out-Null } finally { $zip.Dispose() }
    if ((Invoke-Packager -Check) -ne 1) { throw 'Duplicate ZIP entry was not detected' }
    Write-Host 'Package regression checks passed.'
} finally {
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath($fixture)
    if (!$target.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($target) -notlike 'skill-packaging-test-*') { throw 'Unsafe fixture cleanup path' }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
}
