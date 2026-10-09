# ---------------------------------------------------------------------------
# Launch the CARLA 0.9.16 server on Windows (PowerShell).
#
#   .\launch_carla.ps1                 # normal window on the desktop (default), port 2000
#   .\launch_carla.ps1 -Mode offscreen # headless GPU render, no window
#   .\launch_carla.ps1 -Mode lowgfx    # offscreen + low quality (lighter GPU)
#   .\launch_carla.ps1 -Port 2010      # another instance; uses ports 2010-2012
#
# Extra args are passed straight to CarlaUE4.exe, e.g.:
#   .\launch_carla.ps1 -Mode window -quality-level=Epic
# ---------------------------------------------------------------------------
param(
    [ValidateSet("window", "offscreen", "lowgfx")]
    [string]$Mode = "window",
    [ValidateRange(1024, 65533)]
    [int]$Port = 2000,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra
)

$DefaultSimDir = Join-Path $env:USERPROFILE "carla-sim"
$SimDir = if ($env:CARLA_SIM_DIR) { $env:CARLA_SIM_DIR } else { $DefaultSimDir }
$CarlaRoot = if ($env:CARLA_ROOT) { $env:CARLA_ROOT } else { Join-Path $SimDir "CARLA_0.9.16" }

# Named $CarlaArgs, not $Args: $args is a PowerShell automatic variable.
# CARLA uses the first -carla-rpc-port it sees, so add the port only when the
# caller did not pass one.
$CarlaArgs = @("-nosound")
if (-not ($Extra -match '^-carla-rpc-port=')) { $CarlaArgs = @("-carla-rpc-port=$Port") + $CarlaArgs }
switch ($Mode) {
    "offscreen" { $CarlaArgs += "-RenderOffScreen" }
    "lowgfx"    { $CarlaArgs += @("-RenderOffScreen", "-quality-level=Low") }
    "window"    { }
}
if ($Extra) { $CarlaArgs += $Extra }

$Exe = Join-Path $CarlaRoot "CarlaUE4.exe"
if (-not (Test-Path $Exe)) {
    Write-Error "CarlaUE4.exe not found at $Exe. Set CARLA_ROOT or check the install path."
    exit 1
}

Write-Host "[launch] CARLA_ROOT=$CarlaRoot"
Write-Host "[launch] mode=$Mode  args: $($CarlaArgs -join ' ')"
& $Exe @CarlaArgs
