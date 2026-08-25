[CmdletBinding()]
param()

# Knowledge Evolution Protocol (KEP) - native Windows installer for opencode.
# Run from the repository with: powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
$ErrorActionPreference = "Stop"

$userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$opencodeDir = if ([string]::IsNullOrWhiteSpace($env:KEP_OPENCODE_DIR)) {
    Join-Path $userProfile ".config\opencode"
} else {
    $env:KEP_OPENCODE_DIR
}
$brainDir = if ([string]::IsNullOrWhiteSpace($env:KEP_BRAIN_DIR)) {
    Join-Path $opencodeDir "brain"
} else {
    $env:KEP_BRAIN_DIR
}
$repoDir = Split-Path -Parent $PSScriptRoot
$qmdIndexPath = if (-not [string]::IsNullOrWhiteSpace($env:QMD_CONFIG_DIR)) {
    Join-Path $env:QMD_CONFIG_DIR "index.yml"
} else {
    $qmdConfigHome = if ([string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
        Join-Path $userProfile ".config"
    } else {
        $env:XDG_CONFIG_HOME
    }
    Join-Path (Join-Path $qmdConfigHome "qmd") "index.yml"
}

function Write-KepLog {
    param([string]$Message)
    Write-Host "[KEP] $Message" -ForegroundColor Green
}

function Write-KepWarning {
    param([string]$Message)
    Write-Warning "[KEP] $Message"
}

function Resolve-CommandSource {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }
    return $command.Source
}

function Invoke-Qmd {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $invokeArguments = @($script:qmdPrefixArguments) + @($Arguments)
    & $script:qmdExecutable @invokeArguments
    if ($LASTEXITCODE -ne 0) {
        throw "qmd command failed with exit code $LASTEXITCODE"
    }
}

New-Item -ItemType Directory -Path $opencodeDir -Force | Out-Null

# --- 1. Ensure qmd -----------------------------------------------------------
$qmdExecutable = $null
$qmdPrefixArguments = @()
if (-not [string]::IsNullOrWhiteSpace($env:KEP_QMD_CMD)) {
    $qmdExecutable = Resolve-CommandSource $env:KEP_QMD_CMD
    if ($null -eq $qmdExecutable -and (Test-Path -LiteralPath $env:KEP_QMD_CMD)) {
        $qmdExecutable = $env:KEP_QMD_CMD
    }
} else {
    # Prefer the .cmd shim because it can be launched by Node-based MCP hosts.
    $qmdExecutable = Resolve-CommandSource "qmd.cmd"
    if ($null -eq $qmdExecutable) {
        $qmdExecutable = Resolve-CommandSource "qmd"
    }
}

if ($null -eq $qmdExecutable) {
    if ($env:KEP_NO_INSTALL -eq "1") {
        throw "qmd was not found and KEP_NO_INSTALL=1. Install it with: npm install --global qmd"
    }
    Write-KepLog "qmd not found - installing globally via npm..."
    & npm install --global qmd
    if ($LASTEXITCODE -ne 0) {
        throw "npm failed to install qmd with exit code $LASTEXITCODE"
    }
    $qmdExecutable = Resolve-CommandSource "qmd.cmd"
    if ($null -eq $qmdExecutable) {
        $qmdExecutable = Resolve-CommandSource "qmd"
    }
}

if ($null -eq $qmdExecutable) {
    throw "qmd could not be resolved after installation. Confirm npm's global bin directory is on PATH."
}

# An explicitly configured Bash wrapper remains supported when Git for Windows is installed.
if ($env:KEP_USE_WRAPPER -eq "1" -and [string]::IsNullOrWhiteSpace($env:KEP_QMD_CMD)) {
    $wrapper = Join-Path $userProfile ".openclaw\workspace\scripts\qmd-safe.sh"
    if (Test-Path -LiteralPath $wrapper) {
        $bash = Resolve-CommandSource "bash.exe"
        if ($null -eq $bash) {
            throw "KEP_USE_WRAPPER=1 found $wrapper, but bash.exe is not available. Install Git for Windows or set KEP_QMD_CMD."
        }
        $qmdExecutable = $bash
        $qmdPrefixArguments = @($wrapper)
        Write-KepLog "Using qmd wrapper: $wrapper"
    }
}

$script:qmdExecutable = $qmdExecutable
$script:qmdPrefixArguments = $qmdPrefixArguments
Write-KepLog "Using qmd: $qmdExecutable"

# --- 2. Create brain scaffold + primary collection ---------------------------
Write-KepLog "Creating brain scaffold at $brainDir"
foreach ($namespace in @("concepts", "issues", "patterns", "references", "toolbox", "memory")) {
    New-Item -ItemType Directory -Path (Join-Path $brainDir $namespace) -Force | Out-Null
}
$brainKeep = Join-Path $brainDir ".gitkeep"
if (-not (Test-Path -LiteralPath $brainKeep)) {
    New-Item -ItemType File -Path $brainKeep -Force | Out-Null
}

$collections = (Invoke-Qmd @("collection", "list") 2>$null | Out-String)
if ($collections -notmatch "(?m)^\s*opencode(?:\s|$)") {
    Invoke-Qmd @("collection", "add", $brainDir, "--name", "opencode")
    Write-KepLog "Registered collection 'opencode' -> $brainDir"
} else {
    Write-KepLog "Collection 'opencode' already registered."
}

# --- 3. Auto-detect OpenClaw brain as secondary collection -------------------
$openclawBrain = if ([string]::IsNullOrWhiteSpace($env:KEP_OPENCLAW_BRAIN)) {
    Join-Path $userProfile ".openclaw\workspace\brain"
} else {
    $env:KEP_OPENCLAW_BRAIN
}
if (Test-Path -LiteralPath $openclawBrain -PathType Container) {
    $openclawPathRegistered = $false
    if (Test-Path -LiteralPath $qmdIndexPath) {
        $openclawPathRegistered = (Get-Content -LiteralPath $qmdIndexPath -Raw).Contains($openclawBrain)
    }
    if ($openclawPathRegistered) {
        Write-KepLog "OpenClaw brain already registered ($openclawBrain) - reusing existing collection."
    } elseif ($collections -notmatch "(?m)^\s*openclaw(?:\s|$)") {
        Invoke-Qmd @("collection", "add", $openclawBrain, "--name", "openclaw")
        Write-KepLog "Auto-detected OpenClaw brain -> collection 'openclaw' ($openclawBrain)"
    } else {
        Write-KepLog "Collection 'openclaw' already registered."
    }
} else {
    Write-KepWarning "No OpenClaw brain found at $openclawBrain - skipping optional secondary collection."
}

# --- 4. Index the brain ------------------------------------------------------
Write-KepLog "Indexing brain (update + embed)..."
try {
    # qmd currently updates all collections; an unrelated broken collection must not block KEP setup.
    Invoke-Qmd @("update")
} catch {
    Write-KepWarning "update failed - the opencode collection can be reindexed with 'qmd update' after fixing any unrelated collection errors."
}
try {
    Invoke-Qmd @("embed", "-c", "opencode")
} catch {
    Write-KepWarning "embed failed - embeddings will generate on the next qmd embed."
}

# --- 5. AGENTS.md contract (merge, never clobber) ----------------------------
$agentsPath = Join-Path $opencodeDir "AGENTS.md"
$kepBlock = Get-Content -LiteralPath (Join-Path $repoDir "AGENTS.md.template") -Raw
if (Test-Path -LiteralPath $agentsPath) {
    $existingAgents = Get-Content -LiteralPath $agentsPath -Raw
    if ($existingAgents -match "Knowledge Evolution Protocol \(KEP\)") {
        Write-KepLog "AGENTS.md already contains KEP block - leaving it as-is."
    } else {
        Copy-Item -LiteralPath $agentsPath -Destination "$agentsPath.kep.bak" -Force
        $separator = [Environment]::NewLine + [Environment]::NewLine + "---" + [Environment]::NewLine + [Environment]::NewLine
        [IO.File]::AppendAllText($agentsPath, $separator + $kepBlock + [Environment]::NewLine)
        Write-KepLog "Appended KEP block to $agentsPath (backup: $agentsPath.kep.bak)"
    }
} else {
    Copy-Item -LiteralPath (Join-Path $repoDir "AGENTS.md.template") -Destination $agentsPath
    Write-KepLog "Created global contract at $agentsPath"
}

# --- 6. Skill + command ------------------------------------------------------
$skillDir = Join-Path $opencodeDir "skills\knowledge-evolution-protocol"
New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $opencodeDir "command") -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoDir "SKILL.md") -Destination (Join-Path $skillDir "SKILL.md") -Force
Copy-Item -LiteralPath (Join-Path $repoDir "command\remember.md") -Destination (Join-Path $opencodeDir "command\remember.md") -Force
Write-KepLog "Installed skill 'knowledge-evolution-protocol' and command '/remember'"

# --- 7. Register qmd MCP in opencode.json(c) -------------------------------
$jsonConfig = Join-Path $opencodeDir "opencode.json"
$jsoncConfig = Join-Path $opencodeDir "opencode.jsonc"
$configPath = if (Test-Path -LiteralPath $jsonConfig) { $jsonConfig } elseif (Test-Path -LiteralPath $jsoncConfig) { $jsoncConfig } else { $null }
$mcpExecutable = $script:qmdExecutable
if ([string]::IsNullOrWhiteSpace($env:KEP_QMD_CMD) -and $script:qmdPrefixArguments.Count -eq 0) {
    $qmdShim = Resolve-CommandSource "qmd.cmd"
    if ($null -ne $qmdShim) {
        # Keep the config independent of fnm's per-shell installation path.
        $mcpExecutable = "qmd.cmd"
    }
}
$mcpCommand = @($mcpExecutable) + @($script:qmdPrefixArguments) + @("mcp")

if ($null -eq $configPath) {
    Write-KepWarning "No opencode.json(c) found at $opencodeDir - add this manually:"
    Write-Host ('"mcp": { "qmd": { "type": "local", "command": ["' + ($mcpCommand -join '", "') + '"], "enabled": true } }')
} elseif ($configPath -like "*.jsonc") {
    Write-KepWarning "JSONC config cannot be edited safely by this installer. Add the qmd MCP entry manually to $configPath."
} else {
    $configText = Get-Content -LiteralPath $configPath -Raw
    try {
        $config = $configText | ConvertFrom-Json
    } catch {
        Write-KepWarning "Could not parse $configPath as strict JSON. Add the qmd MCP entry manually."
        $config = $null
    }

    if ($null -ne $config) {
        $mcpProperty = $config.PSObject.Properties["mcp"]
        if ($null -eq $mcpProperty) {
            $config | Add-Member -MemberType NoteProperty -Name "mcp" -Value ([pscustomobject]@{})
        }
        if ($null -eq $config.mcp.PSObject.Properties["qmd"]) {
            Copy-Item -LiteralPath $configPath -Destination "$configPath.kep.bak" -Force
            $qmdMcp = [pscustomobject]@{
                type = "local"
                command = $mcpCommand
                enabled = $true
            }
            $config.mcp | Add-Member -MemberType NoteProperty -Name "qmd" -Value $qmdMcp
            $config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $configPath -Encoding UTF8
            Write-KepLog "Added qmd MCP to $configPath (backup: $configPath.kep.bak)"
        } else {
            Write-KepLog "qmd MCP already present in $configPath"
        }
    }
}

Write-KepLog "Done. Restart opencode for changes to take effect."
Write-KepLog "Verify: qmd collection list; look for [brain] markers in a session."
