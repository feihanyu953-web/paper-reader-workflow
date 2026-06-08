<#
.SYNOPSIS
    鐢熸垚浣庡畨鍏ㄦā寮?(workflow-integrity) audit receipt銆?    鐢变富 AI 鍦?spawn reviewer 骞跺畬鎴愪慨澶嶅悗璋冪敤銆?
.PARAMETER Verdict
    PASS 鎴?FAIL锛岄粯璁?PASS銆?
.PARAMETER ReviewerReportDigest
    鍙€夈€俽eviewer 瀹¤鎶ュ憡鐨?SHA256 digest锛坕nformational only in workflow-integrity mode锛夈€?
.EXAMPLE
    powershell .claude/scripts/New-AuditReceipt.ps1
    powershell .claude/scripts/New-AuditReceipt.ps1 -Verdict FAIL
    powershell .claude/scripts/New-AuditReceipt.ps1 -ReviewerReportDigest "abc123..."
#>

param(
    [ValidateSet("PASS", "FAIL")]
    [string]$Verdict = "PASS",

    [string]$ReviewerReportDigest = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent $PSScriptRoot) "lib\TreeHash.ps1")

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$kbDir = Join-Path $projectRoot "kb"
$wikiDir = Join-Path $projectRoot "wiki"
$receiptDir = Join-Path $kbDir ".audit\receipts"
$normProjectRoot = $projectRoot.Replace('\', '/').TrimEnd('/')



# ============================================================
# Compute hashes
# ============================================================
$kbHash = Get-TreeHashV1 `
    -ScanScope @("kb/**/*.md") `
    -ExcludedPaths @("kb/REVIEWER_LOG.md", "kb/.audit/**") `
    -ProjectRoot $projectRoot

$wikiHash = Get-TreeHashV1 `
    -ScanScope @("wiki/**/*.md") `
    -ExcludedPaths @() `
    -ProjectRoot $projectRoot

# ============================================================
# Collect audited file list
# ============================================================
$auditedFiles = @()

Get-ChildItem -LiteralPath $kbDir -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/').Replace('\', '/')
    if ($rel -eq "kb/REVIEWER_LOG.md") { return }
    if ($rel.StartsWith("kb/.audit/", [StringComparison]::OrdinalIgnoreCase)) { return }
    $auditedFiles += $rel
}

if (Test-Path -LiteralPath $wikiDir) {
    Get-ChildItem -LiteralPath $wikiDir -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $rel = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/').Replace('\', '/')
        $auditedFiles += $rel
    }
}

# ============================================================
# Build receipt
# ============================================================
$receipt = @{
    schema_version           = "kb_audit_receipt_v1"
    project_root             = $normProjectRoot
    security_mode            = "workflow_integrity"
    reviewer                 = "kb-independent-reviewer"
    verdict                  = $Verdict
    audited_at               = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    expires_at               = $null
    scan_scope               = @("kb/**/*.md", "wiki/**/*.md")
    excluded_paths           = @("kb/REVIEWER_LOG.md", "kb/.audit/**")
    tree_hash_algorithm      = "tree_hash_v1_path_sorted_sha256"
    kb_tree_hash             = $kbHash
    wiki_tree_hash           = $wikiHash
    audited_files            = ($auditedFiles | Sort-Object)
    reviewer_report_digest   = if ($ReviewerReportDigest) { $ReviewerReportDigest } else { "" }
    reviewer_report_digest_note = "informational only in workflow-integrity mode"
    hook_version             = "kb_review_gate_v2"
    receipt_generator        = "New-AuditReceipt.ps1"
    created_by               = "main_ai"
}

# ============================================================
# Write receipt
# ============================================================
if (-not (Test-Path -LiteralPath $receiptDir)) {
    New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$filename = "receipt_${timestamp}_$($Verdict.ToLower()).json"
$filePath = Join-Path $receiptDir $filename

$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $filePath -Encoding UTF8

Write-Output "Receipt generated: $filePath"
Write-Output "  kb_tree_hash:  $kbHash"
Write-Output "  wiki_tree_hash: $wikiHash"
Write-Output "  verdict:       $Verdict"
Write-Output "  mode:          workflow_integrity"
Write-Output "  audited_files: $($auditedFiles.Count) files"
