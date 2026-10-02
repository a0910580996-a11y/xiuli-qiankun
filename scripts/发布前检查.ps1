$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
# Run from a clean release checkout; internal design and planning files are not allowed.
# The checker is licensed under MIT; see LICENSE-CODE.
$publicFiles = @(
    'README.md',
    'AGENTS.md',
    'LICENSE',
    'LICENSE-CODE',
    'TRADEMARKS.md',
    'docs/使用指南.md',
    'docs/版权与贡献.md',
    'scripts/发布前检查.ps1',
    '锦囊/01 厘清问题/01 苏格拉底式提问.md',
    '锦囊/02 建立认知/01 双层解释法.md',
    '锦囊/02 建立认知/02 事实核查.md',
    '锦囊/02 建立认知/03 反向拆解.md',
    '锦囊/02 建立认知/04 横纵分析法.md',
    '锦囊/03 生成解法/01 第一性原理.md',
    '锦囊/03 生成解法/02 专家会诊.md',
    '锦囊/03 生成解法/03 跨领域借解.md',
    '锦囊/04 做出决策/01 双向钢人论证.md',
    '锦囊/05 行动验证/01 最小实验.md'
)
if ($publicFiles.Count -ne 18) {
    throw "The public file allowlist must contain exactly 18 paths; found $($publicFiles.Count)"
}
foreach ($relative in $publicFiles) {
    $path = Join-Path $root ($relative -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required public file missing: $relative"
    }
}

$allFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
$relativeFiles = @($allFiles | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') })
$unexpected = @($relativeFiles | Where-Object { $_ -notin $publicFiles })
if ($unexpected.Count -gt 0) {
    throw ('Files outside the approved release boundary: ' + ($unexpected -join ', '))
}

$promptFiles = @($relativeFiles | Where-Object { $_.StartsWith('锦囊/') })
if ($promptFiles.Count -ne 10) {
    throw "Expected 10 prompt files; found $($promptFiles.Count)"
}

$licensePath = Join-Path $root 'LICENSE'
$licenseText = Get-Content -Raw -Encoding UTF8 -LiteralPath $licensePath
foreach ($needle in @('CC BY 4.0', 'Copyright (c) 2026 袖里乾坤项目作者', 'https://creativecommons.org/licenses/by/4.0/')) {
    if ($licenseText -notlike "*$needle*") {
        throw "LICENSE is missing required notice: $needle"
    }
}
$codeLicense = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'LICENSE-CODE')
foreach ($needle in @('MIT License', 'Copyright (c) 2026 袖里乾坤项目作者', 'Permission is hereby granted')) {
    if ($codeLicense -notlike "*$needle*") {
        throw "LICENSE-CODE is missing required notice: $needle"
    }
}

$mediaExtensions = @('.mp4', '.mov', '.mkv', '.webm', '.wav', '.mp3', '.zip', '.7z', '.rar', '.jpg', '.jpeg', '.png', '.gif', '.pdf')
$publicFileObjects = @($allFiles | Where-Object { $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/'); $relative -in $publicFiles })
$unixPathRoots = '(?:home|Users|Volumes|mnt|tmp|var|opt|workspace|workspaces)'
$absolutePathPattern = '(?i)(?:\b[A-Z]:\\|\\\\[^\\\s]+\\[^\\\s]+|(?<![A-Za-z0-9])/' + $unixPathRoots + '/)'
foreach ($file in $publicFileObjects) {
    if ($file.Extension.ToLowerInvariant() -in $mediaExtensions -or $file.Name -eq '.env') {
        throw "Media, archive, or environment file is not approved: $($file.Name)"
    }
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if ($file.Name -ne '发布前检查.ps1' -and $content -match $absolutePathPattern) {
        throw "Personal absolute path found in: $($file.FullName.Substring($root.Length + 1))"
    }
    if ($content -match '(?im)\b(?:api[_-]?key|token|password|secret)\b\s*[:=]\s*["'']?[A-Za-z0-9._-]{16,}') {
        throw "Possible credential value found in: $($file.FullName.Substring($root.Length + 1))"
    }
    if ($content -match '(?im)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b') {
        throw "Email address found in: $($file.FullName.Substring($root.Length + 1))"
    }
}

Write-Output 'Release checks passed: 10 approved prompts; exact public file boundary, attribution, path, credential, email, and media checks passed.'
