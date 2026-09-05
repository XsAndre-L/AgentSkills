#Requires -Version 7.0
<#
.SYNOPSIS
Build independent .skill archives or check their exact contents against source.
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [string[]]$Skill,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$skillsRoot = Join-Path $repository 'skills'
$packagesRoot = Join-Path $repository 'packages'
$utf8 = [Text.UTF8Encoding]::new($false)

function Get-PackageEntries([string]$name) {
    $root = Join-Path $skillsRoot $name
    $entries = [Collections.Generic.Dictionary[string, byte[]]]::new([StringComparer]::Ordinal)
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($root)
    while ($pending.Count) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
            $relative = [IO.Path]::GetRelativePath($root, $item.FullName).Replace('\', '/')
            if ($item.Name -in @('node_modules', '__pycache__', '.git', '.DS_Store') -or
                $item.Name -like '*.pyc' -or $relative -eq 'evals') { continue }
            if ($name -eq 'archify' -and (
                $relative -in @('test', 'package-lock.json', 'DEVELOPMENT.md') -or
                ($relative.StartsWith('scripts/') -and $relative -notin @(
                    'scripts/check-update.mjs', 'scripts/update-contract.mjs',
                    'scripts/check-render-output.mjs', 'scripts/render-examples.mjs'
                ))
            )) { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Cannot package a symlink or junction: $($item.FullName)"
            }
            if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
            $bytes = [IO.File]::ReadAllBytes($item.FullName)
            if ($name -eq 'archify' -and $relative -eq 'package.json') {
                # Preserve upstream's dependency-free runtime package projection.
                $metadata = $utf8.GetString($bytes) | ConvertFrom-Json -AsHashtable
                $metadata.Remove('scripts') | Out-Null
                $metadata.Remove('devDependencies') | Out-Null
                $json = ($metadata | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"
                $bytes = $utf8.GetBytes($json)
            }
            $entries.Add("$name/$relative", $bytes)
        }
    }
    if (!$entries.ContainsKey("$name/SKILL.md")) { throw "Missing SKILL.md for $name" }
    return ,$entries
}

function Get-PackageDifferences([string]$archivePath, $expected) {
    $differences = [Collections.Generic.List[string]]::new()
    if (!(Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        $differences.Add("Missing package: $archivePath")
        return $differences.ToArray()
    }
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            if (!$seen.Add($entry.FullName)) { $differences.Add("Duplicate: $($entry.FullName)"); continue }
            if (!$expected.ContainsKey($entry.FullName)) { $differences.Add("Extra: $($entry.FullName)"); continue }
            $inputStream = $entry.Open()
            $memory = [IO.MemoryStream]::new()
            try {
                $inputStream.CopyTo($memory)
                if ([Convert]::ToBase64String($memory.ToArray()) -cne
                    [Convert]::ToBase64String($expected[$entry.FullName])) {
                    $differences.Add("Changed: $($entry.FullName)")
                }
            } finally { $inputStream.Dispose(); $memory.Dispose() }
        }
        foreach ($key in $expected.Keys) {
            if (!$seen.Contains($key)) { $differences.Add("Missing entry: $key") }
        }
    } finally { $archive.Dispose() }
    return $differences.ToArray()
}

$available = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf
} | Select-Object -ExpandProperty Name)
$names = if ($Skill) { $Skill } else { $available }
$failed = $false
foreach ($name in $names | Sort-Object -Unique) {
    if ($name -cnotin $available -or $name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Unknown skill: $name"
    }
    $expected = Get-PackageEntries $name
    $archivePath = Join-Path $packagesRoot "$name.skill"
    $differences = @(Get-PackageDifferences $archivePath $expected)
    if (!$differences.Count) { Write-Host "Current: $name ($($expected.Count) files)"; continue }
    if ($Check) {
        $failed = $true
        foreach ($difference in $differences) { Write-Host $difference }
        continue
    }
    New-Item -ItemType Directory -Path $packagesRoot -Force | Out-Null
    $temporary = Join-Path $packagesRoot ".$name.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $archive = [IO.Compression.ZipFile]::Open($temporary, [IO.Compression.ZipArchiveMode]::Create)
        try {
            [string[]]$keys = @($expected.Keys)
            [Array]::Sort($keys, [StringComparer]::Ordinal)
            foreach ($key in $keys) {
                $entry = $archive.CreateEntry($key, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $outputStream = $entry.Open()
                try { $outputStream.Write($expected[$key], 0, $expected[$key].Length) }
                finally { $outputStream.Dispose() }
            }
        } finally { $archive.Dispose() }
        $verification = @(Get-PackageDifferences $temporary $expected)
        if ($verification.Count) { throw "Package verification failed: $($verification -join ', ')" }
        [IO.File]::Move($temporary, $archivePath, $true)
        Write-Host "Built: $name ($($expected.Count) files)"
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}
if ($failed) { exit 1 }
