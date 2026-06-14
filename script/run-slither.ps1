param(
    [string]$Target = "src/Vault.sol",
    [switch]$AllSource
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$openzeppelinPath = (Join-Path $projectRoot "lib/openzeppelin-contracts/contracts").Replace("\", "/")
$runFrom = Split-Path $projectRoot -Parent

if (-not (Get-Command slither -ErrorAction SilentlyContinue)) {
    throw "Slither is not installed or not in PATH. Run: python -m pip install slither-analyzer"
}

if ($AllSource) {
    $sourceRoot = Join-Path $projectRoot "src"
    $targets = Get-ChildItem $sourceRoot -Recurse -Filter "*.sol" | ForEach-Object {
        $_.FullName
    }
    if ($targets.Count -eq 0) {
        throw "No Solidity files found under $sourceRoot"
    }
}
else {
    $targetPath = Join-Path $projectRoot $Target
    if (-not (Test-Path $targetPath)) {
        throw "Target not found: $targetPath"
    }
    $targets = @($targetPath)
}

Write-Host "Running Slither analysis ..."
Push-Location $runFrom
try {
    foreach ($t in $targets) {
        $targetUnixPath = $t.Replace("\", "/")
        Write-Host " -> $targetUnixPath"

        $args = @(
            $targetUnixPath
            "--compile-force-framework", "solc"
            "--solc-remaps", "@openzeppelin/contracts=$openzeppelinPath/"
            "--exclude-low"
            "--exclude-informational"
            "--exclude-optimization"
        )

        slither @args
    }
}
finally {
    Pop-Location
}
