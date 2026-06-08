<#
.SYNOPSIS
    HIGH-SECURITY external approval script.
    MUST be run from a terminal OUTSIDE Claude Code (e.g. a separate PowerShell window).
    Independently computes kb/wiki tree hash and generates an external_approval receipt.

    The trust model: receipt generation happens outside the main AI's control.
    The main AI can only READ the external receipt directory, not write to it.

.EXAMPLE
    # In a SEPARATE PowerShell terminal (NOT inside Claude Code):
    powershell -NoProfile -ExecutionPolicy Bypass -File ".\\.claude\\scripts\\approve_kb_audit.ps1"
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent $PSScriptRoot) "lib\TreeHash.ps1")

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$kbDir = Join-Path $projectRoot "kb"
$wikiDir = Join-Path $projectRoot "wiki"
$internalReceiptDir = Join-Path $kbDir ".audit\receipts"
$externalReceiptDir = Join-Path $env:USERPROFILE ".kb-audit\receipts"
if (-not (Test-Path -LiteralPath $externalReceiptDir)) {
    New-Item -ItemType Directory -Path $externalReceiptDir -Force | Out-Null
}
$normProjectRoot = $projectRoot.Replace('\', '/').TrimEnd('/')



# ============================================================
# Compute current tree hashes (INDEPENDENTLY - no input from main AI)
# ============================================================
Write-Host "============================================"
Write-Host " kb audit: external approval (HIGH SECURITY)"
Write-Host "============================================"
Write-Host ""
Write-Host "Project: $normProjectRoot"
Write-Host ""

$kbHash = Get-TreeHashV1 `
    -ScanScope @("kb/**/*.md") `
    -ExcludedPaths @("kb/REVIEWER_LOG.md", "kb/.audit/**") `
    -ProjectRoot $projectRoot

$wikiHash = Get-TreeHashV1 `
    -ScanScope @("wiki/**/*.md") `
    -ExcludedPaths @() `
    -ProjectRoot $projectRoot

Write-Host "Current tree hashes:"
Write-Host "  kb_tree_hash:   $kbHash"
Write-Host "  wiki_tree_hash:  $wikiHash"
Write-Host ""

# ============================================================
# Show changed files vs latest receipt (any mode, any location)
# ============================================================
$latestReceipt = $null
$latestReceiptPath = $null
$allReceiptDirs = @($internalReceiptDir, $externalReceiptDir)
foreach ($dir in $allReceiptDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $r = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $latestReceipt -or [DateTime]$r.audited_at -gt [DateTime]$latestReceipt.audited_at) {
                $latestReceipt = $r
                $latestReceiptPath = $_.FullName
            }
        } catch { }
    }
}

if ($latestReceipt) {
    Write-Host "Latest receipt: $latestReceiptPath"
    Write-Host "  audited_at: $($latestReceipt.audited_at)"
    Write-Host "  verdict:     $($latestReceipt.verdict)"
    Write-Host "  mode:        $($latestReceipt.security_mode)"
    Write-Host ""

    $kbChanged = ($latestReceipt.kb_tree_hash -ne $kbHash)
    $wikiChanged = ($latestReceipt.wiki_tree_hash -ne $wikiHash)

    if ($kbChanged -or $wikiChanged) {
        Write-Host "CHANGED since last receipt:"
        if ($kbChanged) { Write-Host "  kb files (kb_tree_hash mismatch)" }
        if ($wikiChanged) { Write-Host "  wiki files (wiki_tree_hash mismatch)" }

        # try to show specific changed files
        $prevAudited = @{}
        if ($latestReceipt.audited_files) {
            $latestReceipt.audited_files | ForEach-Object { $prevAudited[$_] = $true }
        }
        Write-Host ""
        Write-Host "  Files in current scan:"
        $currentFiles = @()
        Get-ChildItem -LiteralPath $kbDir -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/').Replace('\', '/')
            if ($rel -eq "kb/REVIEWER_LOG.md") { return }
            if ($rel.StartsWith("kb/.audit/", [StringComparison]::OrdinalIgnoreCase)) { return }
            $currentFiles += $rel
        }
        Get-ChildItem -LiteralPath $wikiDir -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $currentFiles += $rel
        }
        $added = $currentFiles | Where-Object { -not $prevAudited.ContainsKey($_) }
        $removed = $latestReceipt.audited_files | Where-Object { $_ -notin $currentFiles }
        if ($added) { Write-Host "    Added: $($added -join ', ')" }
        if ($removed) { Write-Host "    Removed: $($removed -join ', ')" }
    } else {
        Write-Host "No changes since last receipt (hash match)."
    }
} else {
    Write-Host "No previous receipt found. This is the first audit."
}

Write-Host ""

# ============================================================
# Show recent REVIEWER_LOG.md excerpt (informational only)
# ============================================================
$logPath = Join-Path $kbDir "REVIEWER_LOG.md"
if (Test-Path -LiteralPath $logPath) {
    Write-Host "--- Recent REVIEWER_LOG.md (last 15 lines, for reference) ---"
    $lines = Get-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($lines) {
        $start = [Math]::Max(0, $lines.Count - 15)
        $lines[$start..($lines.Count - 1)] | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host ""
}

# ============================================================
# User confirmation
# ============================================================
Write-Host "============================================"
Write-Host " EXTERNAL APPROVAL CONFIRMATION"
Write-Host "============================================"
Write-Host "This script is running OUTSIDE Claude Code."
Write-Host "By typing 'y', you confirm:"
Write-Host "  1. You have reviewed the kb-independent-reviewer audit report in Claude."
Write-Host "  2. All BLOCKING issues have been resolved."
Write-Host "  3. The current kb/wiki state (hash above) is approved."
Write-Host ""
Write-Host "This will generate an external_approval receipt."
Write-Host "The Stop hook will then allow Claude to proceed."
Write-Host ""

$confirm = if ($Force) { "y" } else { Read-Host "Type 'y' to approve, anything else to cancel" }
if ($confirm -ne "y") {
    Write-Host "CANCELLED. No receipt generated."
    exit 1
}

# ============================================================
# Build and write receipt
# ============================================================
if (-not (Test-Path -LiteralPath $externalReceiptDir)) {
    New-Item -ItemType Directory -Path $externalReceiptDir -Force | Out-Null
}

$auditedFiles = @()
Get-ChildItem -LiteralPath $kbDir -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/').Replace('\', '/')
    if ($rel -eq "kb/REVIEWER_LOG.md") { return }
    if ($rel.StartsWith("kb/.audit/", [StringComparison]::OrdinalIgnoreCase)) { return }
    $auditedFiles += $rel
}
Get-ChildItem -LiteralPath $wikiDir -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $auditedFiles += $rel
}

$receipt = @{
    schema_version             = "kb_audit_receipt_v1"
    project_root               = $normProjectRoot
    security_mode              = "external_approval"
    reviewer                   = "kb-independent-reviewer"
    verdict                    = "PASS"
    audited_at                 = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    expires_at                 = $null
    scan_scope                 = @("kb/**/*.md", "wiki/**/*.md")
    excluded_paths             = @("kb/REVIEWER_LOG.md", "kb/.audit/**")
    tree_hash_algorithm        = "tree_hash_v1_path_sorted_sha256"
    kb_tree_hash               = $kbHash
    wiki_tree_hash             = $wikiHash
    audited_files              = ($auditedFiles | Sort-Object)
    reviewer_report_digest     = ""
    reviewer_report_digest_note = "verified by external user: receipt generation outside main AI control"
    hook_version               = "kb_review_gate_v2"
    receipt_generator          = "approve_kb_audit.ps1"
    created_by                 = "external_user"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$filename = "receipt_${timestamp}_pass_external.json"
$filePath = Join-Path $externalReceiptDir $filename

$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $filePath -Encoding UTF8

Write-Host ""
Write-Host "============================================"
Write-Host " APPROVED - external_approval receipt generated"
Write-Host "============================================"
Write-Host "  File: $filePath"
Write-Host "  kb_tree_hash:   $kbHash"
Write-Host "  wiki_tree_hash:  $wikiHash"
Write-Host "  mode:            external_approval"
Write-Host ""
Write-Host "The Stop hook will now accept this receipt."
