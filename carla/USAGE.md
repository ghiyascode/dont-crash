# Using CARLA and ScenarioRunner

How to run the simulator, change the map and weather, pick a vehicle, add
traffic, and run graded scenarios. Everything you can pick from (maps, weather
presets, vehicles, scenarios) is listed in [ASSETS.md](ASSETS.md). To install,
see the [README](README.md).

## Contents

- [Before you start](#before-you-start)
- [Quick recipes](#quick-recipes)
- [Start the simulator](#start-the-simulator)
- [Maps and weather](#maps-and-weather)
- [Drive a vehicle](#drive-a-vehicle)
- [Traffic and pedestrians](#traffic-and-pedestrians)
- [Watch an AI driver](#watch-an-ai-driver)
- [Scenarios](#scenarios)
- [Other example scripts](#other-example-scripts)
- [Known limits](#known-limits)

## Before you start

CARLA is a server (the simulator window) plus Python scripts that connect to
it. Start the simulator in one terminal and run scripts in another. Every new
terminal needs the setup line first.

| | Linux | Windows (PowerShell) |
|---|---|---|
| Set up a new terminal | `source ~/carla-sim/setup_env.sh` | `. ~/carla-sim/setup_env.ps1` |
| Start the simulator | `~/carla-sim/launch_carla.sh` | `~/carla-sim/launch_carla.ps1` |

All other commands are the same on Linux and Windows. Run them from these
folders:

| Scripts | Folder |
|---|---|
| CARLA's scripts (`util/config.py`, `examples/manual_control.py`, ...) | `cd ~/carla-sim/CARLA_0.9.16/PythonAPI` |
| ScenarioRunner (`scenario_runner.py`, its own `manual_control.py`) | `cd ~/carla-sim/scenario_runner` |

If you installed somewhere other than `~/carla-sim`, use your folder instead.
Every script lists all of its options with `--help`.

## Quick recipes

Start the simulator and set up the terminal first.

### Town05 in a downpour, driving a bus

```
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python util/config.py --map Town05 --weather HardRainNoon
python util/environment.py --rain 100 --puddles 100 --wetness 100
python examples/manual_control.py --filter vehicle.mitsubishi.fusorosa
```

The Mitsubishi Fuso Rosa minibus is the only bus.

### Wind and dust in the countryside, in the smallest car

```
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python util/config.py --map Town07 --weather DustStorm
python examples/manual_control.py --filter vehicle.micro.microlino
```

Town07 is the rural map. The Microlino is the smallest car.

### Fog at sunset on the highway

```
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python util/config.py --map Town04
python util/environment.py --sun sunset --fog 90 --fogdist 10
python examples/manual_control.py
```

### Rainy night downtown, with traffic and pedestrians

Terminal 2:
```
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python util/config.py --map Town10HD_Opt --weather HardRainNight
python examples/generate_traffic.py -n 50 -w 40 --asynch
```

Terminal 3:
```
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python examples/manual_control.py
```

`Ctrl+C` in terminal 2 stops the traffic and removes the cars and pedestrians
it added.

### Watch CARLA's AI driver at stop signs

```
cd ~/carla-sim/CARLA_0.9.16/PythonAPI
python util/config.py --map Town05
python examples/automatic_control.py --agent Behavior --behavior cautious --loop
```

Town05 has the most stop signs of the small maps (33). CARLA's agents drive
through them (see [Known limits](#known-limits)).

### Grade a driver on a scenario

Terminal 2 starts the scenario:
```
cd ~/carla-sim/scenario_runner
python scenario_runner.py --scenario FollowLeadingVehicle_1 --reloadWorld --timeout 60 --output
```

Terminal 3 shows the scenario's car and drives it:
```
cd ~/carla-sim/scenario_runner
python manual_control.py
```

Press `P` in the window for autopilot, or drive with WASD. When the scenario
ends, terminal 2 prints a pass/fail table.

### Let an agent drive a route and save the results

```
cd ~/carla-sim/scenario_runner
mkdir results
python scenario_runner.py --route srunner/data/routes_town10.xml --route-id 0 --agent srunner/autoagents/npc_agent.py --timeout 60 --output --json --outputDir results
```

The agent drives by itself. The result table prints at the end, and a JSON
file with every criterion is saved in `results/`. The NPC agent ignores stop
signs, so this route ends in `FAILURE` on `RunningStopTest`.

## Start the simulator

| Mode | Linux | Windows (PowerShell) |
|---|---|---|
| Window (default) | `~/carla-sim/launch_carla.sh` | `~/carla-sim/launch_carla.ps1` |
| No window (still renders, so cameras work) | `~/carla-sim/launch_carla.sh --offscreen` | `~/carla-sim/launch_carla.ps1 -Mode offscreen` |
| No window, low quality (less GPU memory) | `~/carla-sim/launch_carla.sh --lowgfx` | `~/carla-sim/launch_carla.ps1 -Mode lowgfx` |

Options:

| Linux | Windows | Effect |
|---|---|---|
| `--port 2010` | `-Port 2010` | Use ports 2010–2012 instead of 2000–2002. Pass the same `--port` to every script. |
| `-quality-level=Low` | `-quality-level=Low` | Lower rendering quality in a window |
| `-ResX=1920 -ResY=1080` | `-ResX=1920 -ResY=1080` | Window size |
| | `-vulkan` | Use Vulkan instead of DirectX 12: needed for Town11–13, window mode only (see [Known limits](#known-limits)) |
| `--ros2` | | Publish to ROS 2 (see [INSTALL.md](INSTALL.md#ros-2-optional)) |

Anything else on the line is passed to CARLA unchanged.

To stop the simulator, close its window. Without a window, press `Ctrl+C` in
its terminal on Linux; on Windows, run `Get-Process CarlaUE4* | Stop-Process`.

### Running more than one simulator

Each simulator is one world, shared by every script connected to it. For
independent simulations on one machine, start one per port, 10 apart (each
uses three ports):

| Linux | Windows |
|---|---|
| `~/carla-sim/launch_carla.sh --offscreen --port 2000` | `~/carla-sim/launch_carla.ps1 -Mode offscreen -Port 2000` |
| `~/carla-sim/launch_carla.sh --lowgfx --port 2010` | `~/carla-sim/launch_carla.ps1 -Mode lowgfx -Port 2010` |

Scripts that use the Traffic Manager also need their own Traffic Manager port
per simulator, for example
`python examples/generate_traffic.py --port 2010 --tm-port 8010`.

On an RTX 5090 with Town10HD loaded:

| Per simulator | Default quality | Low quality |
|---|---|---|
| GPU memory | ~10 GB | ~6 GB |
| System RAM | ~4–5 GB (up to ~12 GB while a map loads) | same |

Larger maps and more sensors use more. A simulator without a window keeps the
GPU busy even when nothing is connected, so stop the ones you aren't using.

## Maps and weather

Run from `~/carla-sim/CARLA_0.9.16/PythonAPI`.

### `util/config.py`

| Command | Effect |
|---|---|
| `python util/config.py --list` | List maps and weather presets |
| `python util/config.py --map Town03` | Load a map |
| `python util/config.py --weather ClearSunset` | Set a weather preset |
| `python util/config.py --map Town03 --weather ClearSunset` | Both: the map loads first, then the weather |
| `python util/config.py -r` | Reload the current map, which removes every vehicle and pedestrian |
| `python util/config.py -i` | Show the current settings |
| `python util/config.py -b "vehicle.*"` | List blueprints matching a pattern |
| `python util/config.py --no-sync` | Turn off synchronous mode, which unfreezes the world after a script crashed |
| `python util/config.py --fps 20` | Fixed time step (`0` for variable) |
| `python util/config.py --no-rendering` | Stop rendering for faster runs without cameras (`--rendering` turns it back on) |

Loading a map resets the weather, so set the weather after the map. The maps
and presets are in [ASSETS.md](ASSETS.md#maps).

### `util/environment.py`

Sets individual weather values on the current map and leaves the rest alone.

| Command | Effect |
|---|---|
| `python util/environment.py --rain 100 --puddles 100 --wetness 100 --wind 100 --clouds 100` | Torrential rain |
| `python util/environment.py --fog 90 --fogdist 10` | Thick fog starting 10 m away |
| `python util/environment.py --dust_storm 100 --wind 100` | Dust storm |
| `python util/environment.py --sun night` | Night (`day`, `night`, or `sunset`) |
| `python util/environment.py --altitude 5` | Low sun, for glare |
| `python util/environment.py --weather overcast` | Its own presets: `clear`, `overcast`, `rain` |
| `python util/environment.py --cars Position LowBeam` | Lights on every vehicle (light names in [ASSETS.md](ASSETS.md#vehicles)) |

The full list of values and ranges is in
[ASSETS.md](ASSETS.md#individual-values).

### `examples/dynamic_weather.py`

`python examples/dynamic_weather.py --speed 5` cycles the weather and the sun
continuously; `--speed` sets how fast. `Ctrl+C` stops it.

## Drive a vehicle

`examples/manual_control.py` spawns a vehicle and opens a window with a chase
camera. Run from `~/carla-sim/CARLA_0.9.16/PythonAPI`:

```
python examples/manual_control.py --filter vehicle.tesla.model3
```

| Option | Effect | Default |
|---|---|---|
| `--filter <blueprint>` | Vehicle to spawn (list in [ASSETS.md](ASSETS.md#vehicles)) | random |
| `--filter "<pattern>" --generation All` | Random vehicle matching a pattern, for example `"vehicle.tesla.*"`. Without `--generation All`, a pattern picks only from generation 2 models. | |
| `-a`, `--autopilot` | Start on autopilot | off |
| `--res 1920x1080` | Window size | 1280x720 |
| `--rolename <name>` | Role name of the vehicle | `hero` |
| `--sync` | Synchronous mode. Leave it off when another script, such as `generate_traffic.py`, already runs the world synchronously. | off |

Keys:

| Key | Action |
|---|---|
| `W` / `S` | Throttle / brake |
| `A` / `D` | Steer |
| `Q` | Toggle reverse |
| `Space` | Hand brake |
| `P` | Toggle autopilot |
| `Ctrl+W` | Toggle constant 60 km/h |
| `M`, `,` / `.` | Manual gearbox, gear down / up |
| `L`, `Shift+L` | Next light mode, high beam |
| `Z` / `X` | Right / left blinker |
| `I` | Interior light |
| `O` | Open or close all doors |
| `Tab` | Move the camera |
| `` ` `` or `N`, `1`–`9` | Next sensor, choose sensor (depth, segmentation, lidar, ...) |
| `G` | Show radar |
| `C`, `Shift+C` | Next / previous weather preset |
| `Backspace` | Change to a random vehicle |
| `V`, `Shift+V`, `B`, `Shift+B` | Choose a map layer, load / unload it (`_Opt` maps) |
| `T` | Show telemetry |
| `R` | Save camera images to disk |
| `Ctrl+R`, `Ctrl+P` | Record the simulation, replay it |
| `F1` | Hide the on-screen info |
| `H` or `?` | Show all keys |
| `Esc` | Quit |

## Traffic and pedestrians

`examples/generate_traffic.py` adds cars and pedestrians that drive and walk by
themselves, and removes them on `Ctrl+C`. Run from
`~/carla-sim/CARLA_0.9.16/PythonAPI`:

```
python examples/generate_traffic.py -n 50 -w 40 --asynch
```

| Option | Effect | Default |
|---|---|---|
| `-n <N>` | Number of vehicles | 30 |
| `-w <N>` | Number of pedestrians | 10 |
| `--asynch` | Run at real-time speed. Without it, the script steps the world as fast as it can, so traffic moves several times faster than real time; that mode is repeatable and suits automated tests. | off |
| `--filterv "<pattern>"` | Vehicle types, for example `"vehicle.carlamotors.*"` for trucks | `vehicle.*` |
| `--filterw "<pattern>"` | Pedestrian types | `walker.pedestrian.*` |
| `--generationw All` | Use every pedestrian model, not only generation 2 | `2` |
| `--safe` | Leave out vehicle types prone to accidents | off |
| `-s <seed>`, `--seedw <seed>` | Seeds for repeatable traffic and pedestrians | random |
| `--car-lights-on` | Vehicles switch their lights on and off automatically | off |
| `--hero` | Make one of the vehicles the `hero` | off |
| `--hybrid` | Full physics only near the hero, for speed | off |
| `--respawn` | Respawn vehicles that go dormant (large maps) | off |
| `--tm-port <port>` | Traffic Manager port | 8000 |

## Watch an AI driver

`examples/automatic_control.py` spawns a car and lets one of CARLA's agents
drive it to random destinations, in a window like `manual_control.py`. Run
from `~/carla-sim/CARLA_0.9.16/PythonAPI`:

```
python examples/automatic_control.py --agent Behavior --behavior aggressive --loop
```

| Option | Effect | Default |
|---|---|---|
| `--agent Behavior`, `Basic`, or `Constant` | Which agent drives ([ASSETS.md](ASSETS.md#agents)) | `Behavior` |
| `--behavior cautious`, `normal`, or `aggressive` | Behavior agent profile | `normal` |
| `-l`, `--loop` | Pick a new destination on arrival instead of stopping | off |
| `--filter <blueprint>` | Vehicle | random generation 2 |
| `-s <seed>` | Seed for repeatable runs | none |

## Scenarios

ScenarioRunner sets up a situation (the ego vehicle plus scripted traffic or
pedestrians), watches how the ego vehicle handles it, and grades the result.
It opens no window of its own, and the ego vehicle only moves if something
drives it.

Run from `~/carla-sim/scenario_runner`, with the simulator running. Add
`--timeout 60` to every run: the default 10 seconds is often not enough for
the map to load.

### Named scenarios

```
python scenario_runner.py --list
python scenario_runner.py --scenario FollowLeadingVehicle_1 --reloadWorld --timeout 60 --output
python scenario_runner.py --scenario group:ControlLoss --timeout 60 --output
```

`group:<Type>` runs every scenario of one type in turn. ScenarioRunner loads
the scenario's own town. To see and drive the ego vehicle, run ScenarioRunner's
`manual_control.py` from the same folder in another terminal, then drive with
WASD or press `P` for autopilot. Agents (`--agent`) do not work with named
scenarios.

The town, ego vehicle, and weather of each named scenario are fixed in
`srunner/examples/*.xml`. To change them, copy the scenario's entry in its XML
file, give it a new name, edit it, and run it with `--scenario <new-name>`.
All 119 are listed in [ASSETS.md](ASSETS.md#named-scenarios).

### Routes with an agent

A route is a drive from A to B with scenarios along the way, and an agent
drives it:

```
python scenario_runner.py --route srunner/data/routes_town10.xml --route-id 0 --agent srunner/autoagents/npc_agent.py --timeout 60 --output
```

The result reports route completion, collisions, red lights, stop signs, lane
departures, and more. The run shows in the simulator window, but the camera
does not follow the car. The route files are listed in
[ASSETS.md](ASSETS.md#routes); `routes_town10.xml` is the short one.

### OpenSCENARIO

```
python scenario_runner.py --openscenario srunner/examples/FollowLeadingVehicle.xosc --timeout 60 --output
python scenario_runner.py --openscenario2 srunner/examples/change_lane.osc --timeout 60 --output
```

### Saving results and recordings

The output folder must exist before the run, or the results are lost when
ScenarioRunner tries to write them:

```
mkdir results
python scenario_runner.py --route srunner/data/routes_town10.xml --route-id 0 --agent srunner/autoagents/npc_agent.py --repetitions 3 --timeout 60 --json --outputDir results
```

Each run writes a JSON file with the scenario name, an overall `success`
value, and the result of every criterion.

### `scenario_runner.py` options

| Option | Effect |
|---|---|
| `--scenario <name>`, `--scenario group:<Type>` | Run a named scenario, or every scenario of a type |
| `--route <file> --route-id <id>` | Run a route |
| `--agent <file>`, `--agentConfig <file>` | Agent that drives a route, and its configuration file |
| `--openscenario <file.xosc>`, `--openscenario2 <file.osc>` | Run an OpenSCENARIO 1.x or 2.0 file |
| `--timeout <s>` | How long to wait for the simulator (default 10; use 60) |
| `--reloadWorld` | Reload the world before starting |
| `--repetitions <N>` | Run N times |
| `--randomize` | Randomize scenario parameters |
| `--sync`, `--frameRate <hz>` | Synchronous mode and its rate (default 20 Hz) |
| `--trafficManagerSeed <seed>` | Seed for background traffic |
| `--waitForEgo` | Use an existing ego vehicle instead of spawning one |
| `--output` | Print the result table |
| `--file`, `--json`, `--junit` | Save results as text, JSON, or JUnit |
| `--outputDir <folder>` | Folder for saved results (must exist) |
| `--record <folder>` | Save a CARLA recording and criteria data for replay |
| `--debug` | Verbose output |

ScenarioRunner's `manual_control.py` takes `-a` (start on autopilot), `--res`,
`--rolename`, `--keep_ego_vehicle`, and `--wait-for-repetitions` (keep the
window open across `--repetitions`).

## Other example scripts

Also in `~/carla-sim/CARLA_0.9.16/PythonAPI`. Some need extra Python packages.
Run each with `--help` for its options.

| Script | What it does |
|---|---|
| `examples/no_rendering_mode.py` | Top-down 2D view of the whole map and its traffic |
| `examples/visualize_multiple_sensors.py` | Several cameras and lidars in one window |
| `examples/lidar_to_camera.py` | Projects lidar points onto a camera image |
| `examples/bounding_boxes.py` | Draws 2D and 3D bounding boxes around objects |
| `examples/sensor_synchronization.py` | Reads several sensors in sync |
| `examples/start_recording.py`, `examples/start_replaying.py` | Record a simulation and replay it |
| `examples/show_recorder_file_info.py`, `show_recorder_collisions.py`, `show_recorder_actors_blocked.py` | Inspect a recording |
| `util/test_connection.py` | Wait until the simulator is ready |
| `util/extract_spawn_points.py` | Save a map's spawn points to a file |
| `util/vehicle_physics_tester.py` | Test acceleration, braking, and turning for a vehicle |
| `util/performance_benchmark.py` | Benchmark the simulator |

## Known limits

- **Windows: Town11–13 need `-vulkan`.** Under DirectX 12, the default, the
  simulator crashes while loading them. Start it with
  `~/carla-sim/launch_carla.ps1 -vulkan`. Vulkan only runs in a window, so the
  `offscreen` and `lowgfx` modes can't load these maps. Don't use `-dx11`:
  cameras freeze the simulator.

  | Windows | DirectX 12 (default) | `-vulkan` | `-dx11` |
  |---|---|---|---|
  | Town01–07, Town10HD, Town15 | Works | Works | Works |
  | Town11–13 | Crashes | Works | Loads |
  | Cameras, including `manual_control.py` | Work | Work | Freeze the simulator |
  | Without a window (`offscreen`, `lowgfx`) | Works | Does not start | |

- **Windows: Town03 crashes at low quality** (`-Mode lowgfx` or
  `-quality-level=Low`), which affects the 21 named scenarios set in Town03.
  Use default quality or `Town03_Opt`.
- **Windows: `util/environment.py --lights` crashes.** The street-light
  options end the script without an error message. The other options work.
- **CARLA's agents ignore stop signs.** The Basic and Behavior agents, and
  ScenarioRunner's NPC agent (built on the Basic agent), stop for red lights
  but drive through stop signs, so `RunningStopTest` fails them on maps with
  stop signs.
- **Most routes are on the large maps.** 112 of the 113 ScenarioRunner routes
  are in Town12 or Town13, and 28 scenario types appear only in routes. The one
  short route that runs everywhere is `routes_town10.xml` route 0.
- **HighwayCutIn_1 cannot run.** It needs a map called "Highway" that is not
  part of the release.
- **Named scenarios are fixed in their XML files.** Their town, vehicles, and
  weather can't be changed from the command line.
- **ScenarioRunner needs `--timeout 60`.** Its default of 10 seconds is often
  shorter than a map load.
- **Weather resets when a map loads.** Set the weather after the map.
