<#
===========================================================
Gitleaks Bulk Repo Scanner (Docker Version)
===========================================================

Description:
- Reads Git repository URLs from a text file
- Clones each repository locally
- Runs Gitleaks in Docker against the cloned repo
- Saves JSON reports per repository
- Deletes cloned repos after scanning

Requirements:
1. Git installed
2. Docker installed and running
3. Access to repositories (PAT or SSH if private)

-----------------------------------------------------------
Example repos.txt
-----------------------------------------------------------

https://github.com/org/repo1.git
https://github.com/org/repo2.git
git@github.com:org/private-repo.git

-----------------------------------------------------------
Usage
-----------------------------------------------------------

Run from PowerShell:

powershell -ExecutionPolicy Bypass -File .\scan-repos-docker.ps1 -RepoList .\repos.txt

OR

.\scan-repos-docker.ps1 -RepoList .\repos.txt

-----------------------------------------------------------
Output
-----------------------------------------------------------

Reports are saved to:

.\reports\

Example:

.\reports\repo1.json
.\reports\repo2.json

-----------------------------------------------------------
Optional
-----------------------------------------------------------

Pull latest Gitleaks image manually:

docker pull ghcr.io/gitleaks/gitleaks:latest

===========================================================
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoList
)

$WorkDir   = ".\gitleaks-scan"
$ReportDir = ".\reports"

if (!(Test-Path $RepoList)) {
    Write-Host "[!] Repo list file not found: $RepoList" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$repos = Get-Content $RepoList

foreach ($repo in $repos) {

    if ([string]::IsNullOrWhiteSpace($repo)) {
        continue
    }

    $repo = $repo.Trim()

    Write-Host "====================================="
    Write-Host "Processing: $repo"

    # Extract repository name from URL
    $repoName = [System.IO.Path]::GetFileNameWithoutExtension($repo)

    # Paths
    $clonePath  = Join-Path $WorkDir $repoName
    $reportPath = Join-Path $ReportDir "$repoName.json"

    # Remove previous clone if it exists
    if (Test-Path $clonePath) {
        Remove-Item -Recurse -Force $clonePath
    }

    Write-Host "[*] Cloning repository..."

    git clone --quiet $repo $clonePath

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Failed to clone $repo" -ForegroundColor Red
        continue
    }

    # Convert paths for Docker mount usage
    $fullClonePath  = (Resolve-Path $clonePath).Path
    $fullReportPath = (Resolve-Path $ReportDir).Path

    Write-Host "[*] Running Gitleaks scan..."

    docker run --rm `
        -v "${fullClonePath}:/repo" `
        -v "${fullReportPath}:/report" `
        ghcr.io/gitleaks/gitleaks:latest detect `
        --source="/repo" `
        --report-format=json `
        --report-path="/report/$repoName.json" `
        --redact

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] No leaks found: $repoName" -ForegroundColor Green
    }
    else {
        Write-Host "[!] Leaks detected: $repoName" -ForegroundColor Yellow
    }

    Write-Host "[*] Cleaning up cloned repository..."

    Remove-Item -Recurse -Force $clonePath
}

Write-Host "====================================="
Write-Host "Done."
Write-Host "Reports saved in: $ReportDir"
