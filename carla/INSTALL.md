# Installing the CARLA Environment

What the installer does and changes, how to install by hand, PyTorch for each
GPU vendor, and optional ROS 2. To run CARLA, see [USAGE.md](USAGE.md).

## Contents

- [The installer](#the-installer)
- [Components](#components)
- [System requirements](#system-requirements)
- [Manual installation](#manual-installation)
- [PyTorch (GPU)](#pytorch-gpu)
- [ROS 2 (optional)](#ros-2-optional)
- [Verifying the installation](#verifying-the-installation)
- [Files in this folder](#files-in-this-folder)

## The installer

`install.sh` (Linux) and `install.ps1` (Windows) perform every step in
[Manual installation](#manual-installation) and finish with a smoke test that
renders one frame. Run them as shown in the [README](README.md#install).

The installer:

1. Checks the GPU, driver, Vulkan runtime, and free disk space.
2. Installs Miniforge if conda is not found.
3. Downloads CARLA 0.9.16 and the additional maps.
4. Extracts both archives.
5. Clones ScenarioRunner v0.9.16.
6. Creates the `carla` conda environment and installs the CARLA client and
   dependencies.
7. Installs PyTorch 2.8.0: the CUDA build on NVIDIA GPUs, the XPU build on
   Intel Arc GPUs (Windows), the CPU build otherwise. For ROCm on AMD GPUs, see
   [PyTorch (GPU)](#pytorch-gpu).
8. Installs ROS 2 Humble, if requested (Linux).
9. Installs the helper scripts into the install folder.
10. Starts CARLA headless and runs the smoke test.

The download is about 22 GB and extraction takes several minutes per archive.
Re-running the installer is safe: completed steps are skipped and interrupted
downloads resume. Each run writes a log to `logs/` in the install folder.

### Installer options

| Linux | Windows | Effect |
|---|---|---|
| `--dir PATH` | `-Dir PATH` | Install location. Default: `~/carla-sim` or `%USERPROFILE%\carla-sim`. |
| `--env NAME` | `-EnvName NAME` | Conda environment name. Default: `carla`. |
| `--no-maps` | `-NoMaps` | Skip the additional maps (Town06, Town07, Town11, Town12, Town13, Town15). |
| `--torch MODE` | `-Torch MODE` | PyTorch build: `auto` (default), `cuda`, `xpu` (Intel Arc; Windows only), `cpu`, or `none`. |
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

### Updating an existing install

After pulling a newer version of this repository, run the installer again to
pick up updated helper scripts such as `launch_carla.ps1`. Downloads,
extraction, and environments that are already in place are skipped; changed
helper scripts are replaced, and your previous copies are kept as `.bak`.

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
| GPU | Dedicated NVIDIA or AMD GPU, 8 GB VRAM (Intel Arc: untested with CARLA) | NVIDIA RTX 2070+ / AMD RX 6000–7000 |
| Disk | 60 GB free during installation; 38 GB after the downloaded archives are deleted (35 GB and 27 GB without the additional maps) | SSD |
| RAM | 16 GB | 32 GB+ |
| Network | TCP ports 2000–2001 open (CARLA RPC) | Wired connection for the initial download |

CARLA renders through Vulkan on Linux and through DirectX 12 on Windows
(`-dx11` or `-vulkan` on the launch line selects another; see
[Known limits](USAGE.md#known-limits) before using them). CARLA runs on both
NVIDIA and AMD GPUs. A working GPU driver
is required, and on Linux the Vulkan loader. Intel Arc GPUs have not been tested
with CARLA. The PyTorch/CUDA step is NVIDIA-specific; AMD GPUs use the ROCm path
and Intel Arc GPUs the XPU build described in [PyTorch (GPU)](#pytorch-gpu).
Integrated graphics are not supported.

## Manual installation

The same steps the [installer](#the-installer) performs, done by hand.

### Prerequisites

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

### Linux

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

### Windows

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
   . ~/carla-sim/setup_env.ps1
   ```

In PowerShell, environment variables are referenced as `$env:NAME`: where
other CARLA documentation shows `$CARLA_ROOT`, use `$env:CARLA_ROOT`.

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
pip install torch==2.8.0 torchvision==0.23.0 --index-url https://download.pytorch.org/whl/cu128 --extra-index-url https://pypi.org/simple
```

### AMD

CARLA, ScenarioRunner, the example scripts, and ROS 2 run unchanged on AMD GPUs.
Only PyTorch differs: the cu128 build is CUDA (NVIDIA-only) and
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

### Intel Arc (Windows)

CARLA has not been tested on Intel Arc GPUs. On an 8 GB card, reduce video
memory use with `~/carla-sim/launch_carla.ps1 -Mode lowgfx`, or add
`-quality-level=Low` to a windowed launch. At low quality, use `Town03_Opt`
instead of Town03 (see [Known limits](USAGE.md#known-limits)).

PyTorch provides XPU builds for Arc A- and B-series GPUs, validated on
Windows 11. The installer selects this build on Arc GPUs (`-Torch xpu`). To
install it manually, with the `carla` environment active:
```powershell
pip install torch==2.8.0+xpu torchvision==0.23.0+xpu --index-url https://download.pytorch.org/whl/xpu
```
The `+xpu` suffix is required when another 2.8.0 build is already installed;
without it, pip reports the requirement as already satisfied and changes
nothing.

Verify:
```powershell
python -c "import torch; print(torch.xpu.is_available(), torch.xpu.get_device_name(0))"
```
If `torch.xpu.is_available()` is `False`, update the Intel Arc driver; see
[Getting Started on Intel GPU](https://docs.pytorch.org/docs/2.8/notes/get_start_xpu.html).

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
The smoke-test scripts also accept `--host` and `--port`.

Terminal 1, server:

| Linux | Windows (PowerShell) |
|---|---|
| `~/carla-sim/launch_carla.sh` | `~/carla-sim/launch_carla.ps1` |

Allow 20–30 seconds for the map to load.

Terminal 2, smoke test. Set up the terminal (Linux:
`source ~/carla-sim/setup_env.sh`; Windows: `. ~/carla-sim/setup_env.ps1`),
then on either system:
```bash
cd ~/carla-sim
python smoketest/carla_smoketest.py --town Town10HD_Opt --out frame.png
```
A successful run ends with `[smoke] PASS: render + API working`, and the saved
image, `~/carla-sim/frame.png`, shows the vehicle from a chase camera.

## Files in this folder

```
carla/
├── README.md                       # start here: install, first run, troubleshooting
├── USAGE.md                        # commands and recipes
├── ASSETS.md                       # maps, weather, vehicles, scenarios, and more
├── INSTALL.md                      # this page
├── README_old.md                   # the original single-page guide (archived)
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
layout and the `carla` conda environment; to use another
location or environment, set `CARLA_SIM_DIR` or `CARLA_CONDA_ENV` before running
them. Copies installed by the installer with `--dir` or `--env` already use
those values.

`requirements-examples.txt` pins `numpy`, `networkx`, and `Shapely` to the same
versions as ScenarioRunner v0.9.16, so the two requirement files do not
conflict.
