# TreeHash.ps1 — shared Get-TreeHashV1 implementation
# Dot-sourced by kb_review_gate.ps1, computer_kb_review_gate.ps1,
# New-AuditReceipt.ps1, New-ComputerKbAuditReceipt.ps1, approve_kb_audit.ps1
#
# Keep in sync across all consumers by editing ONLY this file.

function Get-TreeHashV1 {
    param(
        [string[]]$ScanScope,
        [string[]]$ExcludedPaths,
        [string]$ProjectRoot
    )

    $allFiles = @()
    $seen = @{}

    foreach ($scope in $ScanScope) {
        $scopeNorm = $scope.Replace('\', '/')
        $parts = $scopeNorm -split '/'
        $rootDir = $parts[0]
        $filePattern = $parts[-1]
        $isRecursive = ($parts -contains '**')
        $targetDir = Join-Path $ProjectRoot $rootDir

        if (-not (Test-Path -LiteralPath $targetDir)) { continue }

        $getArgs = @{
            LiteralPath = $targetDir
            Filter      = $filePattern
            File        = $true
            ErrorAction = [System.Management.Automation.ActionPreference]::SilentlyContinue
        }
        if ($isRecursive) { $getArgs['Recurse'] = $true }

        Get-ChildItem @getArgs | ForEach-Object {
            $absPath = $_.FullName
            if (-not $seen.ContainsKey($absPath)) {
                $seen[$absPath] = $true
                $allFiles += $_
            }
        }
    }

    if ($allFiles.Count -eq 0) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        return [BitConverter]::ToString($sha.ComputeHash([byte[]]@())).Replace("-", "").ToLower()
    }

    $normRoot = $ProjectRoot.Replace('\', '/').TrimEnd('/') + '/'

    $included = @()
    foreach ($f in $allFiles) {
        $relPath = $f.FullName.Replace('\', '/')
        if ($relPath.StartsWith($normRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $relPath = $relPath.Substring($normRoot.Length)
        }
        $relPath = $relPath.Replace('\', '/')

        $excluded = $false
        foreach ($ex in $ExcludedPaths) {
            $exNorm = $ex.Replace('\', '/')
            if ($exNorm.EndsWith('/**')) {
                $prefix = $exNorm.Substring(0, $exNorm.Length - 3)
                if ($relPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                    $excluded = $true
                    break
                }
            } elseif ($relPath -eq $exNorm) {
                $excluded = $true
                break
            } elseif ($relPath.StartsWith($exNorm, [StringComparison]::OrdinalIgnoreCase)) {
                $excluded = $true
                break
            }
        }
        if (-not $excluded) {
            $included += @{ Path = $f.FullName; RelPath = $relPath }
        }
    }

    if ($included.Count -eq 0) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        return [BitConverter]::ToString($sha.ComputeHash([byte[]]@())).Replace("-", "").ToLower()
    }

    $sorted = $included | Sort-Object { $_.RelPath } -Culture ''

    $manifestLines = @()
    foreach ($item in $sorted) {
        $bytes = [System.IO.File]::ReadAllBytes($item.Path)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fileHash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLower()
        $manifestLines += "$($item.RelPath)`n$fileHash`n"
    }

    $manifest = $manifestLines -join ""
    $manifestBytes = [System.Text.Encoding]::UTF8.GetBytes($manifest)
    $treeSha = [System.Security.Cryptography.SHA256]::Create()
    return [BitConverter]::ToString($treeSha.ComputeHash($manifestBytes)).Replace("-", "").ToLower()
}
