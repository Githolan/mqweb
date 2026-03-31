<#
.SYNOPSIS
    MQL4-WEB Development Server Manager

.DESCRIPTION
    Manages TCP and HTTP servers for MT4 communication.

.PARAMETER Action
    start   - Start TCP server (port 8080) + HTTP dashboard (port 3030)
    stop    - Stop all servers
    status  - Check server health
    logs    - View recent logs
    install - Install dependencies with pnpm
    restart - Stop then start servers

.EXAMPLE
    .\Scripts\dev.ps1 start
    .\Scripts\dev.ps1 stop
    .\Scripts\dev.ps1 status
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "install", "help")]
    [string]$Action = "help"
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TcpServerPath = Join-Path $ProjectRoot "Examples\tcp-server.js"
$LogDir = Join-Path $ProjectRoot "logs"
$PidFile = Join-Path $LogDir "server.pid"
$TcpPort = 8080
$HttpPort = 3030

# Colors
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Yellow }
function Write-Status { param($msg) Write-Host $msg -ForegroundColor White }

function Write-Header {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "  MQL4-WEB Development Server Manager" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# Core Utilities
# ==============================================================================

function Get-ProcessesOnPort {
    param([int]$Port)
    $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if (-not $connections) { return @() }

    $pids = $connections | Select-Object -ExpandProperty OwningProcess -Unique | Where-Object { $_ -gt 0 }
    $processes = @()
    foreach ($procId in $pids) {
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) { $processes += $proc }
    }
    return $processes
}

function Stop-ProcessesOnPort {
    param([int]$Port, [string]$Label)

    $processes = Get-ProcessesOnPort -Port $Port
    if ($processes.Count -eq 0) { return $false }

    foreach ($proc in $processes) {
        Write-Info "  Stopping $Label (PID: $($proc.Id))..."
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        }
        catch {
            Write-Info "  Could not stop PID $($proc.Id): $_"
        }
    }
    return $true
}

function Wait-PortFree {
    param([int]$Port, [int]$MaxWaitSeconds = 10)

    $elapsed = 0
    while ($elapsed -lt $MaxWaitSeconds) {
        $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if (-not $connections) { return $true }
        Start-Sleep -Milliseconds 500
        $elapsed += 0.5
    }
    return $false
}

function Test-PortInUse {
    param([int]$Port)
    $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return ($null -ne $connections)
}

function Ensure-LogDir {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
}

# ==============================================================================
# Health Checks
# ==============================================================================

function Test-ServerHealth {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$HttpPort/health" -TimeoutSec 3 -ErrorAction Stop
        return $response.status -eq "running"
    }
    catch { return $false }
}

function Get-ServerHealth {
    try {
        return Invoke-RestMethod -Uri "http://localhost:$HttpPort/health" -TimeoutSec 3 -ErrorAction Stop
    }
    catch { return $null }
}

# ==============================================================================
# Stop All Servers
# ==============================================================================

function Stop-DevServers {
    Write-Header
    Write-Info "Stopping development servers..."
    Write-Host ""

    $stoppedAny = $false

    # Stop processes on TCP port
    if (Test-PortInUse $TcpPort) {
        $stoppedAny = (Stop-ProcessesOnPort -Port $TcpPort -Label "TCP Server") -or $stoppedAny
    }
    else {
        Write-Info "  TCP Server: Not running"
    }

    # Stop processes on HTTP port
    if (Test-PortInUse $HttpPort) {
        $stoppedAny = (Stop-ProcessesOnPort -Port $HttpPort -Label "HTTP Dashboard") -or $stoppedAny
    }
    else {
        Write-Info "  HTTP Dashboard: Not running"
    }

    # Kill orphan node processes from this project
    $projectPath = $ProjectRoot.ToLower()
    Get-Process -Name "node" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmdLine -and $cmdLine.ToLower().Contains("mql4-web")) {
                Write-Info "  Killing orphan Node (PID: $($_.Id))..."
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
                $stoppedAny = $true
            }
        }
        catch {}
    }

    # Wait for ports to be free
    Write-Host ""
    if ($stoppedAny) {
        Write-Info "  Waiting for ports to be released..."
        $tcpFree = Wait-PortFree -Port $TcpPort -MaxWaitSeconds 5
        $httpFree = Wait-PortFree -Port $HttpPort -MaxWaitSeconds 5

        if ($tcpFree -and $httpFree) {
            Write-Success "All servers stopped"
        }
        else {
            if (-not $tcpFree) { Write-Err "  Port $TcpPort still in use" }
            if (-not $httpFree) { Write-Err "  Port $HttpPort still in use" }
        }
    }
    else {
        Write-Info "No servers were running"
    }

    # Clean up PID file
    if (Test-Path $PidFile) {
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
}

# ==============================================================================
# Start All Servers
# ==============================================================================

function Start-DevServers {
    Write-Header
    Write-Info "Starting development servers..."
    Write-Host ""

    Ensure-LogDir

    # Validate path
    if (-not (Test-Path $TcpServerPath)) {
        Write-Err "Server not found: $TcpServerPath"
        return
    }

    # Check if already running
    $tcpInUse = Test-PortInUse $TcpPort
    $httpInUse = Test-PortInUse $HttpPort

    if ($tcpInUse -or $httpInUse) {
        Write-Info "Servers appear to be already running:"
        if ($tcpInUse) { Write-Status "  - TCP port $TcpPort is in use" }
        if ($httpInUse) { Write-Status "  - HTTP port $HttpPort is in use" }

        $response = Read-Host "Restart servers? (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            Stop-DevServers
            Start-Sleep -Seconds 2
        }
        else {
            return
        }
    }

    # Start TCP server
    Write-Info "Starting TCP server..."
    Write-Host "  TCP Port: $TcpPort"
    Write-Host "  HTTP Port: $HttpPort"
    Write-Host ""

    $logFile = Join-Path $LogDir "tcp-server.log"
    $errorLogFile = Join-Path $LogDir "tcp-server-error.log"

    $process = Start-Process -FilePath "node" `
        -ArgumentList "Examples/tcp-server.js" `
        -WorkingDirectory $ProjectRoot `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError $errorLogFile `
        -WindowStyle Hidden `
        -PassThru

    # Save PID
    $process.Id | Out-File $PidFile -Encoding utf8

    # Wait for startup
    Start-Sleep -Seconds 2

    # Verify
    $tcpRunning = Test-PortInUse $TcpPort
    $httpRunning = Test-PortInUse $HttpPort

    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "  SERVER STATUS:" -ForegroundColor White
    Write-Host ""

    if ($tcpRunning) {
        Write-Success "TCP Server: Running on port $TcpPort (PID: $($process.Id))"
    }
    else {
        Write-Err "TCP Server: Failed to start"
    }

    if ($httpRunning) {
        Write-Success "HTTP Dashboard: Running on port $HttpPort"
        Write-Status "  URL: http://localhost:$HttpPort"
    }
    else {
        Write-Err "HTTP Dashboard: Failed to start"
    }

    # Health check
    if ($httpRunning) {
        Start-Sleep -Seconds 1
        $health = Get-ServerHealth
        if ($health) {
            Write-Host ""
            Write-Status "MT4 Connected: $($health.mt4_connected)"
            Write-Status "Pending Commands: $($health.pending_commands)"
            Write-Status "Uptime: $([math]::Round($health.uptime))s"
        }
    }

    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# Status Check
# ==============================================================================

function Show-Status {
    Write-Header

    $tcpRunning = Test-PortInUse $TcpPort
    $httpRunning = Test-PortInUse $HttpPort

    Write-Status "SERVER STATUS:"
    Write-Host ""

    Write-Host "  TCP Server (port $TcpPort): " -NoNewline
    if ($tcpRunning) {
        $proc = Get-ProcessesOnPort -Port $TcpPort
        if ($proc) {
            Write-Success "Running (PID: $($proc[0].Id))"
        }
        else {
            Write-Success "Running"
        }
    }
    else {
        Write-Err "Stopped"
    }

    Write-Host "  HTTP Dashboard (port $HttpPort): " -NoNewline
    if ($httpRunning) {
        $proc = Get-ProcessesOnPort -Port $HttpPort
        if ($proc) {
            Write-Success "Running (PID: $($proc[0].Id))"
        }
        else {
            Write-Success "Running"
        }
        Write-Status "  URL: http://localhost:$HttpPort"
    }
    else {
        Write-Err "Stopped"
    }

    # Health check
    if ($httpRunning) {
        Write-Host ""
        Write-Status "HEALTH CHECK:"
        $health = Get-ServerHealth
        if ($health) {
            Write-Success "  Server: $($health.server)"
            Write-Status "  MT4 Connected: $($health.mt4_connected)"
            Write-Status "  Pending Commands: $($health.pending_commands)"
            Write-Status "  Uptime: $([math]::Round($health.uptime))s"
        }
        else {
            Write-Err "  Health endpoint not responding"
        }
    }

    # PID file
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Status "Saved PID: $pid"
    }

    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# Show Logs
# ==============================================================================

function Show-Logs {
    Write-Header

    $logFile = Join-Path $LogDir "tcp-server.log"
    $errorLog = Join-Path $LogDir "tcp-server-error.log"

    Write-Status "RECENT LOGS:"
    Write-Host ""

    if (Test-Path $logFile) {
        Write-Info "=== tcp-server.log (last 30 lines) ==="
        Get-Content $logFile -Tail 30 -ErrorAction SilentlyContinue
    }

    if (Test-Path $errorLog) {
        $errorContent = Get-Content $errorLog -ErrorAction SilentlyContinue
        if ($errorContent) {
            Write-Host ""
            Write-Err "=== tcp-server-error.log ==="
            Write-Err $errorContent
        }
    }

    if (-not (Test-Path $logFile) -and -not (Test-Path $errorLog)) {
        Write-Info "No logs available yet"
    }

    Write-Host ""
}

# ==============================================================================
# Install Dependencies
# ==============================================================================

function Install-Dependencies {
    Write-Header
    Write-Info "Installing dependencies..."
    Write-Host ""

    Push-Location $ProjectRoot

    # Check for pnpm
    $hasPnpm = Get-Command pnpm -ErrorAction SilentlyContinue

    if ($hasPnpm) {
        Write-Info "Using pnpm..."
        pnpm install
    }
    else {
        Write-Info "Using npm..."
        npm install
    }

    Pop-Location
    Write-Success "Dependencies installed!"
    Write-Host ""
}

# ==============================================================================
# Help
# ==============================================================================

function Show-Help {
    Write-Header
    Write-Host "  Usage: .\Scripts\dev.ps1 <action>" -ForegroundColor White
    Write-Host ""
    Write-Host "  Actions:" -ForegroundColor Yellow
    Write-Host "    start    - Start TCP server + HTTP dashboard"
    Write-Host "    stop     - Stop all servers"
    Write-Host "    restart  - Stop then start servers"
    Write-Host "    status   - Check server health"
    Write-Host "    logs     - View recent logs"
    Write-Host "    install  - Install dependencies (pnpm preferred)"
    Write-Host "    help     - Show this help"
    Write-Host ""
    Write-Host "  Config:" -ForegroundColor Yellow
    Write-Host "    TCP Server:  port $TcpPort"
    Write-Host "    HTTP Dashboard: port $HttpPort"
    Write-Host "    Dashboard URL: http://localhost:$HttpPort"
    Write-Host ""
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

switch ($Action) {
    "start" { Start-DevServers }
    "stop" { Stop-DevServers }
    "restart" {
        Stop-DevServers
        Write-Info "Waiting 2 seconds before starting..."
        Start-Sleep -Seconds 2
        Start-DevServers
    }
    "status" { Show-Status }
    "logs" { Show-Logs }
    "install" { Install-Dependencies }
    "help" { Show-Help }
    default { Show-Help }
}
