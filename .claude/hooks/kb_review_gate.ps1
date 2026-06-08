$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent $PSScriptRoot) "lib\TreeHash.ps1")

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$kbDir = Join-Path $projectRoot "kb"
$wikiDir = Join-Path $projectRoot "wiki"
$auditDir = Join-Path $kbDir ".audit"
$receiptDir = Join-Path $auditDir "receipts"
$externalReceiptDir = Join-Path $env:USERPROFILE ".kb-audit\receipts"
if (-not (Test-Path -LiteralPath $externalReceiptDir)) {
    New-Item -ItemType Directory -Path $externalReceiptDir -Force | Out-Null
}
$forceExternalMarker = Join-Path $auditDir "force_external_approval"
$logPath = Join-Path $kbDir "REVIEWER_LOG.md"



# ============================================================
# normalized project_root for receipt matching
# ============================================================
$normProjectRoot = $projectRoot.Replace('\', '/').TrimEnd('/')

# ============================================================
# Step 1: compute current tree hashes
# ============================================================
$currentKbHash = Get-TreeHashV1 `
    -ScanScope @("kb/**/*.md") `
    -ExcludedPaths @("kb/REVIEWER_LOG.md", "kb/.audit/**") `
    -ProjectRoot $projectRoot

$currentWikiHash = Get-TreeHashV1 `
    -ScanScope @("wiki/**/*.md") `
    -ExcludedPaths @() `
    -ProjectRoot $projectRoot

# ============================================================
# Step 2: determine required security mode
# ============================================================
$requiredMode = "workflow_integrity"
if (Test-Path -LiteralPath $forceExternalMarker) {
    $requiredMode = "external_approval"
}

# ============================================================
# Step 3: find matching PASS receipt
# ============================================================
$matchingReceipt = $null
$allReceipts = @()
$receiptDirs = @($receiptDir, $externalReceiptDir)
foreach ($dir in $receiptDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $receiptFiles = Get-ChildItem -LiteralPath $dir -Filter "*.json" -File -ErrorAction SilentlyContinue
    foreach ($rf in $receiptFiles) {
        try {
            $r = Get-Content -LiteralPath $rf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $allReceipts += $r
        } catch {
            # skip malformed receipt files
        }
    }
}

if ($allReceipts.Count -gt 0) {

    # exact-match predicate (shared between primary and fallback)
    $matchBase = {
        $_.schema_version -eq "kb_audit_receipt_v1" -and
        $_.tree_hash_algorithm -eq "tree_hash_v1_path_sorted_sha256" -and
        ($_.project_root -eq $normProjectRoot -or $_.project_root -eq $normProjectRoot.Replace('\', '/')) -and
        $_.verdict -eq "PASS" -and
        $_.kb_tree_hash -eq $currentKbHash -and
        $_.wiki_tree_hash -eq $currentWikiHash -and
        (-not $_.expires_at -or [DateTime]$_.expires_at -gt (Get-Date))
    }

    # primary: match required mode
    $matchingReceipt = $allReceipts | Where-Object {
        (& $matchBase) -and $_.security_mode -eq $requiredMode
    } | Sort-Object { [DateTime]$_.audited_at } -Descending | Select-Object -First 1

    # fallback for workflow_integrity: also accept external_approval receipts (higher trust)
    if (-not $matchingReceipt -and $requiredMode -eq "workflow_integrity") {
        $matchingReceipt = $allReceipts | Where-Object {
            (& $matchBase) -and $_.security_mode -eq "external_approval"
        } | Sort-Object { [DateTime]$_.audited_at } -Descending | Select-Object -First 1
    }
}

# ============================================================
# Step 4: REVIEWER_LOG.md format WARNING (aux only, never blocks)
# ============================================================
$logWarnings = @()
if (Test-Path -LiteralPath $logPath) {
    $logContent = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($logContent) {
        if ($logContent -notmatch "\| .*dimension.*\| .*verdict.*\|") {
            $logWarnings += "dimension table missing or format unrecognized"
        }
        if ($logContent -notmatch "CLAUDE\.md") {
            $logWarnings += "CLAUDE.md self-check missing"
        }
    }
}

# ============================================================
# Decision
# ============================================================
if ($matchingReceipt) {
    if ($logWarnings.Count -gt 0) {
        Write-Warning ("[kb_review_gate] REVIEWER_LOG.md WARNING (non-blocking): " + ($logWarnings -join "; "))
    }
    exit 0
}

# --- BLOCK ---
$reason = @()
$reason += "Current kb/wiki tree has no matching PASS audit receipt."
$reason += "  kb_tree_hash:  $currentKbHash"
$reason += "  wiki_tree_hash: $currentWikiHash"
$reason += "  required_mode:  $requiredMode"
$reason += ""
$reason += "REQUIRED BEFORE CONTINUING:"
$reason += "1. Spawn kb-independent-reviewer (sonnet, Read/Glob/Grep/Bash)"
$reason += "2. Reviewer outputs audit report (dimension table + fix list + verdict)"
$reason += "3. Fix all BLOCKING issues (max 3 review rounds)"
$reason += "4. Run: powershell .claude/scripts/New-AuditReceipt.ps1"
if ($requiredMode -eq "external_approval") {
    $reason += "5. [HIGH-SECURITY] Run approve_kb_audit.ps1 in external terminal"
}
$reason += "5. Append reviewer summary to kb/REVIEWER_LOG.md (human log only)"
$reason += "6. Receipt triggers re-scan; matching receipt hash -> gate PASS"

if ($logWarnings.Count -gt 0) {
    $reason += ""
    $reason += "REVIEWER_LOG.md format notes (non-blocking):"
    $reason += ($logWarnings -join "; ")
}

$reasonText = $reason -join [Environment]::NewLine

@{
    decision = "block"
    reason = $reasonText
} | ConvertTo-Json -Depth 4 -Compress
