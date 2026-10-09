# CARLA Simulation Environment

Setup and usage guide for the CARLA-based simulation environment used by the
Don't Crash autonomous-driving safety-testing platform. Covers Linux and
Windows, NVIDIA and AMD GPUs.

## Contents

- [Quick install](#quick-install)
- [Components](#components)
- [System requirements](#system-requirements)
- [Prerequisites](#prerequisites)
- [Installation — Linux](#installation--linux)
- [Installation — Windows](#installation--windows)
- [PyTorch (GPU)](#pytorch-gpu)
- [ROS 2 (optional)](#ros-2-optional)
- [Verifying the installation](#verifying-the-installation)
- [Running CARLA](#running-carla)
- [Running a scenario](#running-a-scenario)
- [Configuration](#configuration)
- [Module contents](#module-contents)
- [Troubleshooting](#troubleshooting)

## Quick install

`install.sh` (Linux) and `install.ps1` (Windows) perform the complete
installation described in the manual sections of this guide and finish with a
smoke test that renders one frame.

Before running the installer:

- Install the current NVIDIA or AMD GPU driver.
- Install git. Windows: `winget install Git.Git`. Linux: `curl`, `tar`, and the
  Vulkan loader are also required (Ubuntu: `sudo apt install git curl libvulkan1`).
- Ensure about 60 GB of free disk space (35 GB with `--no-maps`). About 22 GB of
  this is the downloaded archives, which can be deleted afterward.

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

The installer:

1. Checks the GPU, driver, Vulkan runtime, and free disk space.
2. Installs Miniforge if conda is not found.
3. Downloads CARLA 0.9.16 and the additional maps.
4. Extracts both archives.
5. Clones ScenarioRunner v0.9.16.
6. Creates the `carla` conda environment and installs the CARLA client and
   dependencies.
7. Installs PyTorch 2.8.0: the CUDA build on NVIDIA GPUs, the CPU build
   otherwise. For ROCm on AMD GPUs, see [PyTorch (GPU)](#pytorch-gpu).
8. Installs ROS 2 Humble, if requested (Linux).
9. Installs the helper scripts into the install folder.
10. Starts CARLA headless and runs the smoke test.

The download is about 22 GB and extraction takes several minutes per archive.
Re-running the installer is safe: completed steps are skipped and interrupted
downloads resume. Each run writes a log to `logs/` in the install folder.

When it finishes, start CARLA as described in [Running CARLA](#running-carla):
```bash
source ~/carla-sim/setup_env.sh        # Linux, in each new terminal
~/carla-sim/launch_carla.sh
```
```powershell
cd $env:USERPROFILE\carla-sim          # Windows, in each new PowerShell window
. .\setup_env.ps1
.\launch_carla.ps1
```

### Installer options

| Linux | Windows | Effect |
|---|---|---|
| `--dir PATH` | `-Dir PATH` | Install location. Default: `~/carla-sim` or `%USERPROFILE%\carla-sim`. |
| `--env NAME` | `-EnvName NAME` | Conda environment name. Default: `carla`. |
| `--no-maps` | `-NoMaps` | Skip the additional maps (Town06, Town07, Town11, Town12, TownBig). |
| `--torch MODE` | `-Torch MODE` | PyTorch build: `auto` (default), `cuda`, `cpu`, or `none`. |
| `--no-torch` | `-NoTorch` | Same as `--torch none`. |
| `--with-ros2` | — | Also install ROS 2 Humble in a separate environment (Linux only). |
| `--ros-env NAME` | — | ROS 2 environment name. Default: `ros_humble`. |
| `--no-smoketest` | `-NoSmokeTest` | Skip the final smoke test. |
| `--remove-archives` | `-RemoveArchives` | Delete the downloaded archives after extraction. |
| `--reuse-env` | `-ReuseEnv` | Install into an existing conda environment that the installer did not create. |
| `--help` | `-Help` | List the options. |

With `--dir` or `--env`, the installed helper scripts are configured for that
location and environment.

### Changes made to the system

- **Install folder.** CARLA, ScenarioRunner, downloads, logs, and the helper
  scripts are placed in the install folder. If a helper script there differs
  from the new version, the previous copy is kept as `<name>.bak`.
- **Conda environments.** The installer creates the `carla` environment (and
  `ros_humble` with `--with-ros2`). It does not install into an existing
  environment that it did not create unless `--reuse-env` is given, because
  doing so would change that environment's packages.
- **Miniforge.** Installed into `~/miniforge3` (`%USERPROFILE%\miniforge3`) only
  if conda is not found.
- **Windows only.** If the current user's PowerShell execution policy is
  `Undefined` or `Restricted`, it is set to `RemoteSigned`, and
  `conda init powershell` adds conda's activation block to the PowerShell
  profile. Both are required by `setup_env.ps1`.
- The installer never requests administrator or `sudo` rights, deletes nothing
  outside its own downloads, and stops only the CARLA server it starts for the
  smoke test.
- Downloads come only from `downloads.carlasim.com`, GitHub
  (`carla-simulator/scenario_runner`, `conda-forge/miniforge`), PyPI,
  `download.pytorch.org`, `pypi.nvidia.com` (Linux, NVIDIA), and the
  `conda-forge` and `robostack-humble` conda channels.
- During the smoke test, CARLA listens on TCP ports 2000–2001 for about 30
  seconds. If Windows Firewall asks whether to allow CarlaUE4, access is not
  required for local use.

## Components

| Component | Version | Purpose |
|---|---|---|
| CARLA simulator | 0.9.16 (Unreal Engine 4.26) | Driving simulator: roads, vehicles, pedestrians, sensors. |
| ScenarioRunner | 0.9.16 (`v0.9.16` tag) | Defines and grades driving scenarios. |
| CARLA Python API | 0.9.16 | Client library (`import carla`). |
| Python | 3.11 | Common runtime across CARLA, ScenarioRunner, PyTorch, and ROS 2. |
| PyTorch | 2.8.0 + CUDA 12.8 (cu128) | ML driving agent. Required for RTX 50-series (Blackwell) GPUs. |
| ROS 2 Humble | RoboStack build | Messaging layer; CARLA 0.9.16 integrates with it natively. |

CARLA 0.9.16 is used rather than 0.10.0 because 0.10.0 has no version-matched
ScenarioRunner and the project's research tooling (Scenic, VerifAI, Leaderboard)
targets the 0.9.x line. 0.9.16 is the final Unreal Engine 4 release and includes
native ROS 2 support in the server.

## System requirements

| | Minimum | Recommended |
|---|---|---|
| OS | Windows 10/11, or Ubuntu 20.04/22.04 (Fedora supported) | — |
| GPU | Dedicated NVIDIA or AMD GPU, 8 GB VRAM | NVIDIA RTX 2070+ / AMD RX 6000–7000 |
| Disk | 60 GB free during installation; 38 GB after the downloaded archives are deleted (35 GB and 27 GB without the additional maps) | SSD |
| RAM | 16 GB | 32 GB+ |
| Network | TCP ports 2000–2001 open (CARLA RPC) | Wired connection for the initial download |

CARLA renders through Vulkan and runs on both NVIDIA and AMD GPUs; a working GPU
driver and the Vulkan loader are required. The PyTorch/CUDA step is
NVIDIA-specific; AMD GPUs use the ROCm path described in
[PyTorch (GPU)](#pytorch-gpu). Integrated graphics are not supported.

## Prerequisites

The prerequisites and installation sections below document the steps the
[installer](#quick-install) performs, for manual installation and reference.

Python is managed with conda via Miniforge. An existing Anaconda or Miniconda
installation also works.

Linux:
```bash
curl -L -o Miniforge3.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3.sh -b -p "$HOME/miniforge3"
"$HOME/miniforge3/bin/conda" init bash   # or zsh; restart the shell afterward
```

Windows: run the `Miniforge3-Windows-x86_64.exe` installer from the
[Miniforge releases page](https://github.com/conda-forge/miniforge/releases/latest),
or `winget install CondaForge.Miniforge3`. The Windows instructions in this
guide use PowerShell. The "Miniforge Prompt" installed with Miniforge is a
`cmd.exe` prompt, so enable conda in PowerShell once:

1. Open PowerShell and allow local scripts (required for conda's PowerShell
   integration and the helper scripts):
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```
2. Open the Miniforge Prompt from the Start Menu and run:
   ```
   conda init powershell
   ```
3. Close it and open a new PowerShell window. Use PowerShell for all subsequent
   commands.

Verify with `conda --version`.

## Installation — Linux

The environment is installed under `~/carla-sim/`.

1. Create the workspace and download CARLA and the additional maps:
   ```bash
   mkdir -p ~/carla-sim/downloads ~/carla-sim/CARLA_0.9.16
   cd ~/carla-sim/downloads
   curl -L -O https://downloads.carlasim.com/Linux/CARLA_0.9.16.tar.gz
   curl -L -O https://downloads.carlasim.com/Linux/AdditionalMaps_0.9.16.tar.gz
   ```

2. Extract both archives into the CARLA directory:
   ```bash
   tar -xzf CARLA_0.9.16.tar.gz -C ~/carla-sim/CARLA_0.9.16
   tar -xzf AdditionalMaps_0.9.16.tar.gz -C ~/carla-sim/CARLA_0.9.16
   cat ~/carla-sim/CARLA_0.9.16/VERSION   # expect: 0.9.16
   ```

3. Install the Vulkan loader. Ubuntu: `sudo apt install libvulkan1`. Fedora: it
   is included with the NVIDIA driver.

4. Clone the version-matched ScenarioRunner:
   ```bash
   cd ~/carla-sim
   git clone -b v0.9.16 https://github.com/carla-simulator/scenario_runner.git
   ```

5. Clone this repository, then create the Python environment and install the
   client and dependencies:
   ```bash
   git clone https://github.com/ghiyascode/dont-crash.git
   cd dont-crash/carla

   conda create -y -n carla python=3.11
   conda activate carla

   pip install carla==0.9.16
   pip install -r setup/requirements-examples.txt
   pip install -r ~/carla-sim/scenario_runner/requirements.txt
   ```

6. Install the helper scripts:
   ```bash
   cp setup/linux/setup_env.sh setup/linux/launch_carla.sh ~/carla-sim/
   cp -r setup/smoketest ~/carla-sim/
   chmod +x ~/carla-sim/launch_carla.sh
   ```

7. Configure the shell. This must be run in each new terminal:
   ```bash
   source ~/carla-sim/setup_env.sh
   ```

Continue to [PyTorch (GPU)](#pytorch-gpu), then
[Verifying the installation](#verifying-the-installation).

## Installation — Windows

Run all commands in PowerShell, after completing the Windows steps in
[Prerequisites](#prerequisites). The environment is installed under
`%USERPROFILE%\carla-sim\` (`C:\Users\<you>\carla-sim`).

1. Download CARLA and the additional maps:
   ```powershell
   mkdir $env:USERPROFILE\carla-sim\downloads
   cd $env:USERPROFILE\carla-sim\downloads
   curl.exe -L -O https://downloads.carlasim.com/Windows/CARLA_0.9.16.zip
   curl.exe -L -O https://downloads.carlasim.com/Windows/AdditionalMaps_0.9.16.zip
   ```

2. Extract both archives into `C:\Users\<you>\carla-sim\CARLA_0.9.16\`. The maps
   archive merges into the same directory:
   ```powershell
   Expand-Archive CARLA_0.9.16.zip         -DestinationPath $env:USERPROFILE\carla-sim\CARLA_0.9.16
   Expand-Archive AdditionalMaps_0.9.16.zip -DestinationPath $env:USERPROFILE\carla-sim\CARLA_0.9.16
   ```
   Confirm that `CarlaUE4.exe` exists in that directory. The archives contain
   over 55,000 files combined; `Expand-Archive` can take a considerable time.

3. Clone the version-matched ScenarioRunner:
   ```powershell
   cd $env:USERPROFILE\carla-sim
   git clone -b v0.9.16 https://github.com/carla-simulator/scenario_runner.git
   ```

4. Clone this repository, then create the Python environment and install the
   client and dependencies:
   ```powershell
   git clone https://github.com/ghiyascode/dont-crash.git
   cd dont-crash\carla

   conda create -y -n carla python=3.11
   conda activate carla

   pip install carla==0.9.16
   pip install -r setup\requirements-examples.txt
   pip install -r $env:USERPROFILE\carla-sim\scenario_runner\requirements.txt
   ```

5. Install the helper scripts:
   ```powershell
   copy setup\windows\setup_env.ps1 $env:USERPROFILE\carla-sim\
   copy setup\windows\launch_carla.ps1 $env:USERPROFILE\carla-sim\
   xcopy /E /I setup\smoketest $env:USERPROFILE\carla-sim\smoketest
   ```

6. Configure the shell. This must be run in each new PowerShell window:
   ```powershell
   cd $env:USERPROFILE\carla-sim
   . .\setup_env.ps1
   ```

In PowerShell, environment variables are referenced as `$env:NAME`. Where this
guide shows `$CARLA_ROOT` or `$SCENARIO_RUNNER_ROOT`, use `$env:CARLA_ROOT` and
`$env:SCENARIO_RUNNER_ROOT`, and use `\` as the path separator.

Continue to [PyTorch (GPU)](#pytorch-gpu), then
[Verifying the installation](#verifying-the-installation).

## PyTorch (GPU)

### NVIDIA

With the `carla` environment active:
```bash
pip install torch==2.8.0 torchvision==0.23.0 --index-url https://download.pytorch.org/whl/cu128
```
RTX 50-series (Blackwell) GPUs require the cu128 build; it is also compatible
with older NVIDIA cards.

Verify:
```bash
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

If the install stalls while collecting the `nvidia-*` CUDA wheels, the network
cannot reach `pypi.nvidia.com`, which PyTorch's cu128 index links to. Install
the CUDA wheels from PyPI first, then torch
([pins in `setup/nvidia-cu12-reqs.txt`](setup/nvidia-cu12-reqs.txt)):
```bash
pip install -r setup/nvidia-cu12-reqs.txt --index-url https://pypi.org/simple
pip install torch==2.8.0 torchvision==0.23.0 \
    --index-url https://download.pytorch.org/whl/cu128 \
    --extra-index-url https://pypi.org/simple
```

### AMD

CARLA, ScenarioRunner, the example scripts, and ROS 2 run unchanged on AMD GPUs
through Vulkan. Only PyTorch differs: the cu128 build is CUDA (NVIDIA-only) and
reports `cuda.is_available() = False` on AMD hardware. AMD uses ROCm instead.
Options, in order of preference:

- **Linux + ROCm.** ROCm 7.x supports the RX 7000-series architecture
  (`gfx1101`). Install PyTorch from the ROCm wheel index per the
  [AMD PyTorch guide](https://rocm.docs.amd.com/projects/ai-ecosystem/en/latest/frameworks/pytorch/install.html);
  setting `HSA_OVERRIDE_GFX_VERSION=11.0.0` may be required. Confirm the card in
  the [ROCm compatibility matrix](https://rocm.docs.amd.com/en/docs-7.0.0/compatibility/compatibility-matrix.html).
- **Windows + ROCm.** Available as of ROCm 7.2.1 for `gfx1101`, Windows 11 only,
  with partial stack support. See the
  [Windows ROCm matrix](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/windows/windows_compatibility.html).
- **CPU-only PyTorch.** Functional but slow; suitable for development and
  testing of agent code:
  ```bash
  pip install torch==2.8.0 torchvision==0.23.0 --index-url https://download.pytorch.org/whl/cpu
  ```
  The CPU index is required on Linux; the default PyPI build for Linux includes
  several gigabytes of NVIDIA libraries that are unused on AMD hardware.
- **Remote training.** Run the simulator on the AMD machine and perform GPU
  training on an NVIDIA machine. The simulator and the training process do not
  need to run on the same host.

## ROS 2 (optional)

CARLA 0.9.16 includes native ROS 2 support (embedded Fast-DDS; launched with
`--ros2`), so a separate `carla-ros-bridge` process is not required. This path
is Linux-only in the prebuilt package.

The installer does this with `./install.sh --with-ros2`. To install manually,
create ROS 2 Humble in a separate conda environment via RoboStack, which keeps
its numpy requirement from conflicting with ScenarioRunner:
```bash
conda create -y -n ros_humble -c robostack-humble -c conda-forge python=3.11 ros-humble-desktop
conda activate ros_humble
ros2 topic list
```
Create the environment and install `ros-humble-desktop` in a single command, as
shown. Installing it into an existing environment fails in a package's
post-link step. To add ROS packages later, pass the same channels:
`conda install -n ros_humble -c robostack-humble -c conda-forge <package>`.

Usage with the native integration:
```bash
# Terminal 1: server with ROS 2 enabled
~/carla-sim/launch_carla.sh --offscreen --ros2
# Terminal 2 (carla env): spawn an ego, enable a camera for ROS, keep it alive
python ~/carla-sim/smoketest/ros2_publisher.py --secs 60
# Terminal 3 (ros_humble env): observe
conda activate ros_humble
ros2 topic list
ros2 topic hz /carla/hero/front_rgb/image
ros2 topic echo /clock --once
```

Topics published while `ros2_publisher.py` runs:

| Topic | Direction | Content |
|---|---|---|
| `/clock` | CARLA → ROS | Simulation time |
| `/tf` | CARLA → ROS | Actor transforms |
| `/carla/hero/front_rgb/image` | CARLA → ROS | Camera images (10 Hz) |
| `/carla/hero/front_rgb/camera_info` | CARLA → ROS | Camera intrinsics |
| `/carla/hero/vehicle_control_cmd` | ROS → CARLA | Throttle, steering, and brake commands for the ego vehicle |
| `/carla/hero/ackermann_control_cmd` | ROS → CARLA | Ackermann drive commands for the ego vehicle |

Topics are namespaced as `/carla/<vehicle>/<sensor>/...` only when the vehicle's
`role_name` and `ros_name` are `hero`; other names produce
`/carla//<sensor>/...`. Sensors are named by their `ros_name` attribute. CARLA's
own example, `$CARLA_ROOT/PythonAPI/examples/ros2/ros2_native.py`, spawns a
vehicle with multiple sensors from a JSON definition
(`ros2/stack.json`).

If `ros2 topic echo` reports that a topic "does not appear to be published
yet", the listener started before discovery completed; retry, or pass the type
explicitly, e.g. `ros2 topic echo /clock rosgraph_msgs/msg/Clock --once`.

## Verifying the installation

Start the server, then run the smoke test. It spawns a vehicle and camera and
saves one rendered frame, confirming the GPU render path and the Python API.

Terminal 1 — server:
```bash
~/carla-sim/launch_carla.sh                # Linux
```
```powershell
cd $env:USERPROFILE\carla-sim; . .\setup_env.ps1; .\launch_carla.ps1   # Windows
```
Allow 20–30 seconds for the map to load.

Terminal 2 — smoke test:
```bash
source ~/carla-sim/setup_env.sh
python ~/carla-sim/smoketest/carla_smoketest.py --town Town10HD_Opt --out /tmp/frame.png
```
```powershell
cd $env:USERPROFILE\carla-sim; . .\setup_env.ps1
python smoketest\carla_smoketest.py --town Town10HD_Opt --out frame.png
```
A successful run ends with `[smoke] PASS: render + API working`, and the saved
image shows the vehicle from a chase camera.

## Running CARLA

CARLA uses a client–server architecture. The server (`CarlaUE4`) hosts the
simulation; a client Python script connects over RPC port 2000 and controls it.
The server and a client typically run in separate terminals. Each terminal that
runs a client must have the environment configured first
(`source ~/carla-sim/setup_env.sh`, or `. .\setup_env.ps1` on Windows).

Start the server:

| Mode | Linux | Windows |
|---|---|---|
| Windowed (default) | `~/carla-sim/launch_carla.sh` | `.\launch_carla.ps1` |
| Headless (GPU render, no window) | `~/carla-sim/launch_carla.sh --offscreen` | `.\launch_carla.ps1 -Mode offscreen` |
| Headless, low quality | `~/carla-sim/launch_carla.sh --lowgfx` | `.\launch_carla.ps1 -Mode lowgfx` |

Run example clients (server running, environment configured):
```bash
python $CARLA_ROOT/PythonAPI/examples/manual_control.py       # drive manually (WASD; P toggles autopilot)
python $CARLA_ROOT/PythonAPI/examples/generate_traffic.py -n 60 -w 30   # AI traffic and pedestrians
python $CARLA_ROOT/PythonAPI/examples/dynamic_weather.py      # cycle weather and time of day
```

`generate_traffic.py` runs in synchronous mode by default and advances the
simulation as fast as the hardware allows, so traffic moves faster than real
time (about 5× on an RTX 5090). Add `--asynch` to run at real-time speed for
viewing. Synchronous mode is deterministic and suited to automated testing.
Spawn failures reported at startup ("collision at spawn position") mean a
randomly chosen spawn point was occupied; the script continues with the actors
that spawned. On exit it restores the world to asynchronous mode.

Change the map or weather:
```bash
python $CARLA_ROOT/PythonAPI/util/config.py --list
python $CARLA_ROOT/PythonAPI/util/config.py --map Town03
```
Installed maps: Town01–07, Town10HD (each with an `_Opt` layered variant), and
the large maps Town11, Town12, and TownBig.

## Running a scenario

ScenarioRunner spawns a scenario — the ego vehicle and any scripted actors — and
grades a driving agent against defined criteria. It does not open a display
window, and the ego vehicle does not move until an agent or manual controller
drives it. The `manual_control.py` client attaches a chase camera and HUD to the
ego vehicle and can either drive it manually or hand it to autopilot.

Run with three terminals, each with the environment configured. ScenarioRunner
commands run from `$SCENARIO_RUNNER_ROOT`:
```bash
# Terminal 1: simulator
~/carla-sim/launch_carla.sh

# Terminal 2: scenario
cd $SCENARIO_RUNNER_ROOT
python scenario_runner.py --scenario FollowLeadingVehicle_1 --reloadWorld

# Terminal 3: chase-camera view and control
cd $SCENARIO_RUNNER_ROOT
python manual_control.py
```
In the Terminal 3 window, press `P` to enable autopilot and observe the
scenario, or drive the ego vehicle manually with WASD. When a criterion is met,
Terminal 2 prints the result and the run ends.

List all scenarios with `python scenario_runner.py --list`. Available examples
include `FollowLeadingVehicle_1`, `ControlLoss_1`, `CutInFrom_left_Lane`, and
`ChangeLane_1`.

### Autonomous agent on a route

Driving agents are supported only for route-based scenarios (`--route`), not
for the named scenarios above. To have the built-in NPC agent drive a route and
be graded on it:
```bash
python scenario_runner.py --route srunner/data/routes_town10.xml --route-id 0 \
       --agent srunner/autoagents/npc_agent.py --output
```
ScenarioRunner prints a criteria table on completion (route completion,
collisions, red lights, stop signs, lane departures, and so on) with a global
pass/fail result. The run is visible in the server window; the spectator camera
does not follow the ego vehicle automatically.

Route files are in `srunner/data/`: `routes_town10.xml`, `routes_devtest.xml`,
`routes_training.xml`, and `routes_validation.xml`.

## Configuration

Every script runs with working defaults. Parameters are adjusted at three
levels: server launch arguments, client command-line flags, and values set in
the Python source. Run any client with `--help` for its complete flag list.

### Server

The launch scripts accept a mode flag and a port, and forward all remaining
arguments to the CARLA server:
```bash
~/carla-sim/launch_carla.sh --window --port 2000 -quality-level=Epic -ResX=1920 -ResY=1080
```
```powershell
.\launch_carla.ps1 -Mode window -Port 2000 -quality-level=Epic -ResX=1920 -ResY=1080
```

| Argument | Effect | Default in launch scripts |
|---|---|---|
| `--port N` / `-Port N` | RPC port. The server uses ports N, N+1, and N+2. | 2000 |
| `-quality-level=Low\|Epic` | Rendering quality. `Low` reduces GPU load. | Epic (`Low` with `--lowgfx`) |
| `-RenderOffScreen` | Render on the GPU without opening a window. | Set by `--offscreen` / `--lowgfx` |
| `-ResX=<px> -ResY=<px>` | Window resolution. | Engine default |
| `-nosound` | Disable audio. | Set |
| `--ros2` | Enable native ROS 2 publishing (Linux). | Off |

If the port is changed, pass the matching `--port` / `-p` to every client.

### Multiple instances

Each CARLA server is one simulated world; clients connected to the same server
share it. Independent simulations on one machine require separate server
instances on separate ports. Space the ports by 10, since each server uses
three consecutive ports:
```bash
~/carla-sim/launch_carla.sh --offscreen --port 2000
~/carla-sim/launch_carla.sh --lowgfx --port 2010
```
Clients on the same machine that use the Traffic Manager (for example
`generate_traffic.py`) also need a distinct Traffic Manager port per instance:
```bash
python $CARLA_ROOT/PythonAPI/examples/generate_traffic.py --port 2010 --tm-port 8010
```

Resource use measured on an RTX 5090 with Town10HD loaded:

| Per instance | Epic quality | Low quality |
|---|---|---|
| GPU memory | ~10 GB | ~6 GB |
| System RAM | ~4–5 GB (peaks ~12 GB while a map loads) | ~4–5 GB (same peak) |

Larger maps and additional sensors use more. A headless server renders
continuously and keeps the GPU busy even with no client connected, so stop
instances that are not in use.

### Simulation settings — `util/config.py`

Applies to a running server:

| Flag | Effect |
|---|---|
| `-m, --map <name>` | Load a map. |
| `-r, --reload-map` | Reload the current map. |
| `--weather <preset>` | Set a weather preset (e.g. `ClearNoon`, `HardRainSunset`). |
| `-l, --list` | List available maps and weather presets. |
| `--delta-seconds <s>` / `--fps <n>` | Fixed simulation timestep; `0` for variable. |
| `--no-rendering` / `--rendering` | Disable or enable rendering (faster headless runs). |
| `--no-sync` | Disable synchronous mode. |
| `-b, --list-blueprints <filter>` | List actor blueprints, e.g. `-b "vehicle.*"`. |
| `-i, --inspect` | Print current simulation settings. |

### Traffic — `generate_traffic.py`

| Flag | Effect | Default |
|---|---|---|
| `-n <N>` | Number of vehicles. | 30 |
| `-w <N>` | Number of pedestrians. | 10 |
| `--safe` | Exclude vehicle types prone to accidents. | Off |
| `--filterv <pattern>` | Vehicle model filter, e.g. `vehicle.tesla.*`. | `vehicle.*` |
| `-s <seed>` | Seed and deterministic Traffic Manager, for reproducible traffic. | Random |
| `--seedw <seed>` | Seed for pedestrian behavior. | Random |
| `--hybrid` | Physics only near the hero vehicle (better performance). | Off |
| `--asynch` | Asynchronous mode; the simulation runs at real-time speed. Without it, the script steps the simulation as fast as possible. | Synchronous |
| `--car-lights-on` | Automatic vehicle light management. | Off |
| `--tm-port <port>` | Traffic Manager port. | 8000 |

### Manual control — `manual_control.py`

| Flag | Effect | Default |
|---|---|---|
| `--res <W>x<H>` | Window resolution. | 1280x720 |
| `--filter <pattern>` | Vehicle model. | `vehicle.*` |
| `-a, --autopilot` | Start with autopilot enabled. | Off |
| `--rolename <name>` | Role name of the controlled vehicle. | `hero` |
| `--sync` | Synchronous mode. | Off |

### Weather — `dynamic_weather.py`

| Flag | Effect | Default |
|---|---|---|
| `-s, --speed <factor>` | Rate of weather and sun-position change. | 1.0 |

### Scenarios — `scenario_runner.py`

| Flag | Effect |
|---|---|
| `--scenario <name>` | Run a named scenario. `group:<Class>` runs every scenario in a class, e.g. `group:FollowLeadingVehicle`. |
| `--route <file> --route-id <id>` | Run a route-based scenario. |
| `--agent <file>` | Driving agent for route-based scenarios. |
| `--agentConfig <file>` | Configuration file passed to the agent. |
| `--openscenario <file.xosc>` | Run an OpenSCENARIO definition. |
| `--repetitions <N>` | Run the scenario N times. |
| `--randomize` | Randomize scenario parameters. |
| `--sync` / `--frameRate <hz>` | Synchronous mode and its rate (default 20 Hz). |
| `--trafficManagerSeed <seed>` | Seed for background traffic. |
| `--timeout <s>` | Client connection timeout. |
| `--reloadWorld` | Reload the world before starting (default behavior). |
| `--waitForEgo` | Attach to an existing ego vehicle instead of spawning one. |
| `--output` | Print the criteria results table to stdout. |
| `--file` / `--json` / `--junit` | Write results to a text, JSON, or JUnit file. |
| `--outputDir <dir>` | Directory for result files. Must already exist. |
| `--record <dir>` | Save a CARLA recording and criteria data for replay. |
| `--debug` | Verbose debug output. |

Results from repeated runs can be saved for later analysis. The output
directory must exist before the run; otherwise ScenarioRunner fails when
writing results at the end of the run and the results are lost:
```bash
mkdir -p results
python scenario_runner.py --route srunner/data/routes_town10.xml --route-id 0 \
       --agent srunner/autoagents/npc_agent.py --repetitions 3 --json --outputDir results/
```
Each run writes one JSON file containing the scenario name, a global `success`
value, and the result of every criterion.

### Parameters set in the Python source

Sensor and stepping parameters in the smoke-test scripts are defined in code.
Edit the script to change them.

| File | Parameter | Value |
|---|---|---|
| `smoketest/carla_smoketest.py` | Camera resolution | 800 × 600 |
| | Camera mount (relative to vehicle) | x = −6, z = 3, pitch = −15 |
| | Synchronous timestep (`fixed_delta_seconds`) | 0.05 s (20 Hz) |
| `smoketest/ros2_publisher.py` | Camera resolution | 640 × 480 |
| | Sensor tick (`sensor_tick`) | 0.1 s (10 Hz) |
| | Vehicle and camera ROS names | `hero`, `front_rgb` |

Both scripts also accept `--host` and `--port`; `carla_smoketest.py` accepts
`--town` and `--out`, and `ros2_publisher.py` accepts `--secs`.

## Module contents

```
carla/
├── install.sh                      # one-command installer (Linux)
├── install.ps1                     # one-command installer (Windows)
└── setup/
    ├── requirements-examples.txt   # pip dependencies for the CARLA example scripts
    ├── nvidia-cu12-reqs.txt        # pinned CUDA wheels (PyTorch fallback)
    ├── smoketest/
    │   ├── carla_smoketest.py      # spawn vehicle and camera, save a rendered frame
    │   └── ros2_publisher.py       # native ROS 2 check (Linux)
    ├── linux/
    │   ├── setup_env.sh            # source to activate the env and export CARLA paths
    │   └── launch_carla.sh         # start the server (window / offscreen / lowgfx)
    └── windows/
        ├── setup_env.ps1           # dot-source equivalent for PowerShell
        └── launch_carla.ps1        # start the server on Windows
```

The `setup_env` scripts export `CARLA_ROOT`, `SCENARIO_RUNNER_ROOT`, and
`PYTHONPATH`, so that `import carla`, the `agents` navigation package, and
`import srunner` resolve from any directory. They must be sourced (Linux) or
dot-sourced (Windows) in each new terminal, and are safe to run more than once.
They assume the `~/carla-sim` (Linux) or `%USERPROFILE%\carla-sim` (Windows)
layout and the `carla` conda environment used in this guide; to use another
location or environment, set `CARLA_SIM_DIR` or `CARLA_CONDA_ENV` before running
them. Copies installed by the installer with `--dir` or `--env` already use
those values.

`requirements-examples.txt` pins `numpy`, `networkx`, and `Shapely` to the same
versions as ScenarioRunner v0.9.16, so the two requirement files do not
conflict.

## Troubleshooting

| Symptom | Cause and resolution |
|---|---|
| Installer: "a conda environment named '…' already exists and was not created by this installer" | An environment with that name is used for something else. Run with `--env <new-name>` (`-EnvName`), or `--reuse-env` (`-ReuseEnv`) to install into it, which changes its packages. |
| Installer: a download is incomplete | The connection was interrupted. Re-run the installer; the download resumes. |
| Installer: smoke test failed | The CARLA server log is in `logs/smoketest-server.log` in the install folder (Linux). Check the GPU driver and Vulkan runtime, then run the [smoke test manually](#verifying-the-installation). |
| PowerShell will not run `install.ps1` | Start it with `powershell -ExecutionPolicy Bypass -File .\install.ps1`. |
| `can't open file '/PythonAPI/...'` | `$CARLA_ROOT` is unset; the environment was not sourced. The shell prompt should read `(carla)`. Source `setup_env`. |
| `ModuleNotFoundError: No module named 'pygame'` | Example dependencies not installed. Run `pip install -r setup/requirements-examples.txt`. |
| Client reports connection refused | The server is still starting (20–30 s). Check the port with `ss -ltn \| grep 2000` (Linux) or `netstat -an \| findstr 2000` (Windows) and retry once it is listening. |
| `conda` not recognized in PowerShell, or `setup_env.ps1` warns that conda is unavailable | Run `conda init powershell` once from the Miniforge Prompt, then open a new PowerShell window. |
| `torch.cuda.is_available()` returns `False` | GPU driver too old, or a CPU-only build was installed. Reinstall with the cu128 index. RTX 50-series requires cu128. On AMD, use the ROCm path. |
| PyTorch install stalls on `nvidia-*` wheels | `pypi.nvidia.com` is unreachable. Use the `nvidia-cu12-reqs.txt` procedure above. |
| `libvulkan.so.1: cannot open` (Linux) | Install the Vulkan loader: `sudo apt install libvulkan1`. |
| PowerShell will not run `.ps1` | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then dot-source again. |
| Scenario ego vehicle does not move | Expected without a controller. Run `manual_control.py` and press `P`, or use a route-based run with `--agent` (see [Autonomous agent on a route](#autonomous-agent-on-a-route)). |
| `--agent` has no effect with `--scenario` | Agents apply only to route-based scenarios. Use `--route <file> --route-id <id>`. |
| `FileNotFoundError` when ScenarioRunner writes results | The `--outputDir` directory does not exist. Create it before the run. |
| Traffic moves much faster than real time | `generate_traffic.py` runs in synchronous mode by default. Add `--asynch` for real-time speed. |
| `Spawn failed because of collision at spawn position` | A randomly chosen spawn point was occupied. Fewer actors than requested are spawned; no action is needed. |
| `failed to destroy actor ... not found` on exit | The actor was already removed by the server. Cleanup still completes; no action is needed. |
| ROS 2 topics appear as `/carla//<sensor>/...` | The ego vehicle's `role_name` and `ros_name` are not `hero`. Set both to `hero`. |
| No data on ROS 2 topics | The server was not launched with `--ros2`, or the world was left in synchronous mode with no client ticking it. Run `python $CARLA_ROOT/PythonAPI/util/config.py --no-sync`. |
