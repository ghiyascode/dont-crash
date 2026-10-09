# ---------------------------------------------------------------------------
# CARLA 0.9.16 environment setup for Windows (PowerShell).
# Dot-source this file so the variables persist in the current shell:
#
#     . .\setup_env.ps1
#
# Activates the `carla` conda env and sets CARLA_ROOT, SCENARIO_RUNNER_ROOT,
# and PYTHONPATH (CARLA `agents` package + ScenarioRunner). Safe to run more
# than once. Requires `conda init powershell` to have been run once.
# Defaults: %USERPROFILE%\carla-sim and conda env `carla`
# (override with $env:CARLA_SIM_DIR and $env:CARLA_CONDA_ENV)
# ---------------------------------------------------------------------------

$DefaultSimDir = Join-Path $env:USERPROFILE "carla-sim"
$DefaultCondaEnv = "carla"

$CarlaSim = if ($env:CARLA_SIM_DIR) { $env:CARLA_SIM_DIR } else { $DefaultSimDir }
$CondaEnv = if ($env:CARLA_CONDA_ENV) { $env:CARLA_CONDA_ENV } else { $DefaultCondaEnv }
$env:CARLA_ROOT = Join-Path $CarlaSim "CARLA_0.9.16"
$env:SCENARIO_RUNNER_ROOT = Join-Path $CarlaSim "scenario_runner"

if (-not (Test-Path (Join-Path $env:CARLA_ROOT "CarlaUE4.exe"))) {
    Write-Warning "CarlaUE4.exe not found in $env:CARLA_ROOT"
}

# Prepend each path once (';' is the Windows separator).
$paths = @((Join-Path $env:CARLA_ROOT "PythonAPI\carla"), $env:SCENARIO_RUNNER_ROOT)
$existing = if ($env:PYTHONPATH) { $env:PYTHONPATH -split ';' } else { @() }
$env:PYTHONPATH = (@($paths) + @($existing | Where-Object { $_ -and ($paths -notcontains $_) })) -join ';'

if (Get-Command conda -ErrorAction SilentlyContinue) {
    conda activate $CondaEnv
} else {
    Write-Warning "conda is not available in this shell. Run 'conda init powershell' once from the Miniforge Prompt, then open a new PowerShell window."
}

Write-Host "[carla-env] conda env : $CondaEnv"
Write-Host "[carla-env] CARLA_ROOT: $env:CARLA_ROOT"
Write-Host "[carla-env] SR_ROOT   : $env:SCENARIO_RUNNER_ROOT"
Write-Host "[carla-env] Start the simulator with: $(Join-Path $CarlaSim 'launch_carla.ps1')"
