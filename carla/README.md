# CARLA Simulation Environment

The CARLA driving simulator and ScenarioRunner, set up for the Don't Crash
autonomous-driving safety-testing platform. Works on Linux and Windows, with
NVIDIA and AMD GPUs.

| Guide | What's in it |
|---|---|
| This page | Install, first run, and fixes for common problems |
| [USAGE.md](USAGE.md) | Commands: maps, weather, vehicles, traffic, scenarios, quick recipes |
| [ASSETS.md](ASSETS.md) | Everything you can choose from: maps, weather, vehicles, pedestrians, props, sensors, scenarios |
| [INSTALL.md](INSTALL.md) | Installer details, manual installation, PyTorch on AMD and Intel GPUs, ROS 2 |
| [README_old.md](README_old.md) | The original single-page guide, archived |

## Install

You need:

- The current NVIDIA or AMD GPU driver.
- git. Windows: `winget install Git.Git`. Linux also needs curl and the Vulkan
  loader (Ubuntu: `sudo apt install git curl libvulkan1`).
- About 60 GB of free disk space.

Linux:
```bash
git clone https://github.com/ghiyascode/dont-crash.git
cd dont-crash/carla
./install.sh
```

Windows (PowerShell):
```powershell
git clone https://github.com/ghiyascode/dont-crash.git
cd dont-crash\carla
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer downloads about 22 GB and takes a while. If it stops partway,
run it again: finished steps are skipped and downloads resume. It ends with a
test that renders one frame and prints `[smoke] PASS`.

For installer options, what it changes on your system, and the manual steps,
see [INSTALL.md](INSTALL.md).

## First run

CARLA runs as a server (the simulator window) plus scripts that connect to it,
so use two terminals.

**Terminal 1: start the simulator.** A window opens with a town; the first
load takes 20–30 seconds.

| Linux | Windows (PowerShell) |
|---|---|
| `~/carla-sim/launch_carla.sh` | `~/carla-sim/launch_carla.ps1` |

**Terminal 2: set up the terminal, then drive.**

Linux:
```bash
source ~/carla-sim/setup_env.sh
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python examples/manual_control.py
```

Windows (PowerShell):
```powershell
. ~/carla-sim/setup_env.ps1
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python examples/manual_control.py
```

Drive with WASD. `P` turns autopilot on and off, `H` lists every key, and `Esc`
quits. After the setup line, the prompt starts with `(carla)`. If it shows
`(base)` or nothing, the setup line did not run.

The setup line is needed once in every new terminal. To change the town,
weather, or vehicle, start with the recipes in
[USAGE.md](USAGE.md#quick-recipes).

## Troubleshooting

### Installing

| Problem | Fix |
|---|---|
| PowerShell will not run `install.ps1` | Start it with `powershell -ExecutionPolicy Bypass -File .\install.ps1`. |
| "a conda environment named '…' already exists and was not created by this installer" | That name is in use. Run with `-EnvName <new-name>` (Linux: `--env`), or `-ReuseEnv` (`--reuse-env`) to install into it, which changes its packages. |
| A download is incomplete | The connection dropped. Run the installer again; the download resumes. |
| Smoke test failed | Check the GPU driver (and on Linux the Vulkan loader), then run the [smoke test by hand](INSTALL.md#verifying-the-installation). On Linux the server log is `logs/smoketest-server.log` in the install folder. |
| `pip` says `... is not a supported wheel on this platform` | You are in the wrong Python (often `(base)`, or Python 3.12+). Use the `carla` environment the installer made: run the setup line from [First run](#first-run). The CARLA package is already installed there. |
| PyTorch install stalls on `nvidia-*` packages | `pypi.nvidia.com` is unreachable. Use the [fallback in INSTALL.md](INSTALL.md#nvidia). |
| `libvulkan.so.1: cannot open` (Linux) | `sudo apt install libvulkan1`. |

### Running

| Problem | Fix |
|---|---|
| `can't open file '/PythonAPI/...'` or `'C:\PythonAPI\...'` | The path variable was empty. On Windows, `$CARLA_ROOT` is bash syntax and PowerShell needs `$env:CARLA_ROOT`. The `~/carla-sim/...` paths in [USAGE.md](USAGE.md) work in both. On Linux, run `source ~/carla-sim/setup_env.sh` first. |
| `conda` is not recognized, or `setup_env.ps1` warns that conda is unavailable | Run `conda init powershell` once from the Miniforge Prompt, then open a new PowerShell window. |
| PowerShell will not run a `.ps1` file | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once. |
| `ModuleNotFoundError: No module named 'pygame'` | Run the setup line first. If it still fails: `pip install -r setup/requirements-examples.txt` from this folder. |
| Connection refused, or `time-out ... while waiting for the simulator` | The simulator is still starting (20–30 s), or it is not running. Wait, then retry. For ScenarioRunner, add `--timeout 60`. |
| Windows: the simulator closes with `EXCEPTION_ACCESS_VIOLATION` while loading Town11, Town12, or Town13 | CARLA crashes on these maps under DirectX 12, its Windows default. Start it with `~/carla-sim/launch_carla.ps1 -vulkan`. See [Known limits](USAGE.md#known-limits). |
| Windows: the simulator crashes while loading Town03 at low quality | Use default quality, or `Town03_Opt`. |
| Windows: the simulator fails to start with `-vulkan` and `-Mode offscreen` or `lowgfx` | Vulkan only runs in a window on Windows. Use a window, or leave out `-vulkan`. |
| Windows: the simulator stops responding a few seconds after a script with a camera starts, such as `manual_control.py` | It was started with `-dx11`; under DirectX 11, cameras freeze it. Close it and start it without `-dx11`. |
| The simulator looks frozen after a script crashed | The script left the world in synchronous mode. Run `python util/config.py --no-sync` from `~/carla-sim/CARLA_0.9.16/PythonAPI`. |
| Cars from an earlier run are still in the world | The script was closed without cleaning up (for example, its terminal was closed). Run `python util/config.py -r` from `~/carla-sim/CARLA_0.9.16/PythonAPI` to reload the map. |
| Traffic moves much faster than real time | `generate_traffic.py` runs as fast as it can by default. Add `--asynch`. |
| `Spawn failed because of collision at spawn position` | A spawn point was occupied, so fewer actors spawned. No action needed. |
| `failed to destroy actor ... not found` on exit | The actor was already gone. No action needed. |
| `torch.cuda.is_available()` returns `False` | Old GPU driver or a CPU-only build. See [PyTorch in INSTALL.md](INSTALL.md#pytorch-gpu). On AMD, use the ROCm path. |

### Scenarios

| Problem | Fix |
|---|---|
| The scenario's car does not move | Something has to drive it. Run ScenarioRunner's `manual_control.py` and press `P`, or use a route with `--agent`. See [Scenarios](USAGE.md#scenarios). |
| `--agent` has no effect with `--scenario` | Agents only drive routes (`--route`). |
| `FileNotFoundError` when results are written | The `--outputDir` folder must exist before the run. |

### ROS 2 (Linux)

| Problem | Fix |
|---|---|
| Topics appear as `/carla//<sensor>/...` | Set the vehicle's `role_name` and `ros_name` to `hero`. |
| No data on the topics | Start the server with `--ros2`. If a script left the world in synchronous mode, run `python util/config.py --no-sync`. |
