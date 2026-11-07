# CARLA and ScenarioRunner Assets

Everything you can choose from in CARLA 0.9.16 and ScenarioRunner 0.9.16. For
the commands that use these, see [USAGE.md](USAGE.md).

## Contents

- [Maps](#maps)
- [Weather](#weather)
- [Vehicles](#vehicles)
- [Pedestrians](#pedestrians)
- [Props](#props)
- [Sensors](#sensors)
- [Scenarios](#scenarios)
  - [Named scenarios](#named-scenarios)
  - [Scenario types used only in routes](#scenario-types-used-only-in-routes)
  - [Routes](#routes)
  - [OpenSCENARIO files](#openscenario-files)
  - [Grading criteria](#grading-criteria)
  - [Agents](#agents)

## Maps

Load a map with `python util/config.py --map <name>` (see
[USAGE.md](USAGE.md#maps-and-weather)).

| Map | What it is | Size (m) | Spawn points | Lanes (km) | Junctions | Traffic lights | Stop signs | Yield signs | Speed limits (km/h) |
|---|---|---|---|---|---|---|---|---|---|
| Town01 | Small town with a river and bridges | 398 × 333 | 255 | 6.5 | 12 | 36 | 0 | 0 | 30, 60, 90 |
| Town02 | Small residential and commercial town | 201 × 201 | 101 | 3.0 | 8 | 24 | 0 | 0 | 30, 60, 90 |
| Town03 | Larger city with a roundabout and large junctions | 398 × 417 | 265 | 14.2 | 31 | 38 | 20 | 0 | 30, 60, 90 |
| Town04 | Mountain town with a looping highway | 929 × 832 | 372 | 33.8 | 27 | 43 | 8 | 4 | 30, 40, 60, 90 |
| Town05 | Grid city with multi-lane roads and a bridge | 487 × 417 | 302 | 24.4 | 21 | 54 | 33 | 0 | 30, 40, 60, 90 |
| Town06 | Long multi-lane highways with many on- and off-ramps | 1044 × 566 | 436 | 25.9 | 23 | 19 | 1 | 4 | 30, 40, 60, 90 |
| Town07 | Rural roads, narrow lanes, farms, few traffic lights | 290 × 373 | 116 | 7.4 | 31 | 17 | 19 | 20 | 30, 40 |
| Town10HD | Detailed downtown with high-rises and a waterfront | 225 × 210 | 155 | 6.1 | 9 | 15 | 3 | 1 | none posted |
| Town15 | Large, detailed map with many junctions and parked cars | 2138 × 1708 | 332 | 38.6 | 99 | 25 | 7 | 55 | 30, 50 |
| Town11 | Very large, sparse tiled map: long single-lane roads, no stop signs | 20050 × 21485 | 3166 | 719 | 174 | 547 | 0 | 0 | 30, 60, 90 |
| Town12 | Large tiled map: city, suburbs, and countryside, with highways | 9398 × 8265 | 10422 | 671 | 628 | 1101 | 609 | 13 | 30, 40, 50, 80, 90, 120 |
| Town13 | Large tiled map, a companion to Town12 for validation | 13066 × 9938 | 12478 | 909 | 774 | 1138 | 1064 | 22 | 30, 40, 50, 60, 80, 90, 120 |

Town01–07 and Town10HD each have an `_Opt` version (for example
`Town05_Opt`): the same town split into layers that can be removed while it
runs. Layers: `Buildings`, `Decals`, `Foliage`, `Ground`, `ParkedVehicles`,
`Particles`, `Props`, `StreetLights`, `Walls`. In `manual_control.py`, `V`
selects a layer and `B` loads it (`Shift+B` unloads). There is no Town08 or
Town09 in the public release.

Town11–13 take 6–45 seconds to load and run slower than the other maps. On
Windows they load only with `-vulkan`, and Town03 crashes at low quality (see
[Known limits](USAGE.md#known-limits)).

| To test… | Use |
|---|---|
| Stop signs | Town05 (33), Town03 (20), Town07 (19, plus 20 yield signs); Town12 and Town13 have hundreds. Town01, Town02, and Town11 have none. |
| Highways and lane changes | Town04 and Town06, with up to 6–7 lanes in one direction |
| Traffic lights | Town05 (54), Town04 (43), Town03 (38) |
| Quick runs | Town02 (200 × 200 m) |
| Rural driving | Town07 |
| Many junctions and parked cars | Town15 |

## Weather

### Presets

`python util/config.py --weather <preset>`. Values are 0–100, except sun
altitude, in degrees (negative is night).

| Preset | Clouds | Rain | Puddles | Wetness | Wind | Fog | Dust | Sun altitude |
|---|---|---|---|---|---|---|---|---|
| ClearNoon | 5 | 0 | 0 | 0 | 10 | 2 | 0 | 45 |
| ClearSunset | 5 | 0 | 0 | 0 | 10 | 2 | 0 | 15 |
| ClearNight | 5 | 0 | 0 | 0 | 10 | 60 | 0 | -90 |
| CloudyNoon | 60 | 0 | 0 | 0 | 10 | 3 | 0 | 45 |
| CloudySunset | 60 | 0 | 0 | 0 | 10 | 3 | 0 | 15 |
| CloudyNight | 60 | 0 | 0 | 0 | 10 | 60 | 0 | -90 |
| WetNoon | 5 | 0 | 50 | 0 | 10 | 3 | 0 | 45 |
| WetSunset | 5 | 0 | 50 | 0 | 10 | 2 | 0 | 15 |
| WetNight | 5 | 0 | 50 | 60 | 10 | 60 | 0 | -90 |
| WetCloudyNoon | 60 | 0 | 50 | 0 | 10 | 3 | 0 | 45 |
| WetCloudySunset | 60 | 0 | 50 | 0 | 10 | 2 | 0 | 15 |
| WetCloudyNight | 60 | 0 | 50 | 60 | 10 | 60 | 0 | -90 |
| SoftRainNoon | 20 | 30 | 50 | 0 | 30 | 3 | 0 | 45 |
| SoftRainSunset | 20 | 30 | 50 | 0 | 30 | 2 | 0 | 15 |
| SoftRainNight | 60 | 30 | 50 | 60 | 30 | 60 | 0 | -90 |
| MidRainyNoon | 60 | 60 | 60 | 0 | 60 | 3 | 0 | 45 |
| MidRainSunset | 60 | 60 | 60 | 0 | 60 | 3 | 0 | 15 |
| MidRainyNight | 80 | 60 | 60 | 80 | 60 | 60 | 0 | -90 |
| HardRainNoon | 100 | 100 | 90 | 0 | 100 | 7 | 0 | 45 |
| HardRainSunset | 100 | 100 | 90 | 0 | 100 | 7 | 0 | 15 |
| HardRainNight | 100 | 100 | 90 | 100 | 100 | 100 | 0 | -90 |
| DustStorm | 100 | 0 | 0 | 0 | 100 | 2 | 100 | 45 |

`Default` restores the map's own weather. Note the spellings `MidRainyNoon`
and `MidRainSunset`.

`util/environment.py` has three presets of its own, `--weather clear`,
`overcast`, and `rain`, and three sun positions, `--sun day`, `night`, and
`sunset`.

### Individual values

Set any of these with `util/environment.py`; values not given are left as they
are.

| Flag | Range | Effect |
|---|---|---|
| `--clouds` | 0–100 | Cloud cover |
| `--rain` | 0–100 | Rainfall |
| `--puddles` | 0–100 | Puddles on the road |
| `--wetness` | 0–100 | Wet surfaces (affects the camera image, not grip) |
| `--wind` | 0–100 | Wind: moves trees, rain, and dust |
| `--fog` | 0–100 | Fog density |
| `--fogdist` | 0 and up | Distance at which fog starts, in metres |
| `--fogfalloff` | 0 and up | How heavy the fog is; higher values keep it closer to the ground |
| `--dust_storm` | 0–100 | Dust storm strength |
| `--altitude` | -90 to 90 | Sun height in degrees; below 0 is night |
| `--azimuth` | 0–360 | Sun direction in degrees |
| `--scatteringintensity`, `--rayleighscatteringscale`, `--miescatteringscale` | see `--help` | Atmospheric light scattering |

## Vehicles

41 vehicles. Spawn one with `manual_control.py --filter <blueprint>` (see
[USAGE.md](USAGE.md#drive-a-vehicle)). Generation 2 models are the newer
ones, with opening doors and working lights on most.

### Cars

| Blueprint | Model | Gen | Notes |
|---|---|---|---|
| `vehicle.audi.a2` | Audi A2 | 1 | |
| `vehicle.audi.etron` | Audi e-tron | 1 | electric |
| `vehicle.audi.tt` | Audi TT | 1 | |
| `vehicle.bmw.grandtourer` | BMW 2 Series Gran Tourer | 1 | |
| `vehicle.chevrolet.impala` | Chevrolet Impala | 1 | |
| `vehicle.citroen.c3` | Citroën C3 | 1 | |
| `vehicle.dodge.charger_2020` | Dodge Charger | 2 | |
| `vehicle.dodge.charger_police` | Dodge Charger police car | 1 | emergency lights |
| `vehicle.dodge.charger_police_2020` | Dodge Charger police car | 2 | emergency lights |
| `vehicle.ford.crown` | Ford Crown Victoria taxi | 2 | taxi |
| `vehicle.ford.mustang` | Ford Mustang | 1 | |
| `vehicle.jeep.wrangler_rubicon` | Jeep Wrangler Rubicon | 1 | |
| `vehicle.lincoln.mkz_2017` | Lincoln MKZ | 1 | ScenarioRunner's default ego vehicle |
| `vehicle.lincoln.mkz_2020` | Lincoln MKZ | 2 | |
| `vehicle.mercedes.coupe` | Mercedes coupé | 1 | |
| `vehicle.mercedes.coupe_2020` | Mercedes coupé | 2 | |
| `vehicle.micro.microlino` | Microlino bubble car | 1 | electric; the smallest car |
| `vehicle.mini.cooper_s` | Mini Cooper S | 1 | |
| `vehicle.mini.cooper_s_2021` | Mini Cooper S | 2 | |
| `vehicle.nissan.micra` | Nissan Micra | 1 | |
| `vehicle.nissan.patrol` | Nissan Patrol | 1 | |
| `vehicle.nissan.patrol_2021` | Nissan Patrol | 2 | |
| `vehicle.seat.leon` | SEAT León | 1 | |
| `vehicle.tesla.model3` | Tesla Model 3 | 1 | electric |
| `vehicle.toyota.prius` | Toyota Prius | 1 | electric (hybrid) |

### Vans, trucks, and buses

| Blueprint | Model | Gen | Notes |
|---|---|---|---|
| `vehicle.ford.ambulance` | Ford ambulance | 2 | emergency lights |
| `vehicle.mercedes.sprinter` | Mercedes Sprinter van | 2 | |
| `vehicle.volkswagen.t2` | Volkswagen T2 van | 1 | |
| `vehicle.volkswagen.t2_2021` | Volkswagen T2 van | 2 | |
| `vehicle.tesla.cybertruck` | Tesla Cybertruck | 2 | electric |
| `vehicle.carlamotors.carlacola` | Delivery truck | 1 | |
| `vehicle.carlamotors.european_hgv` | Semi-truck cab (6 wheels) | 2 | |
| `vehicle.carlamotors.firetruck` | Fire truck | 2 | emergency lights |
| `vehicle.mitsubishi.fusorosa` | Mitsubishi Fuso Rosa minibus | 2 | the only bus |

### Motorcycles and bicycles

| Blueprint | Model | Gen |
|---|---|---|
| `vehicle.harley-davidson.low_rider` | Harley-Davidson Low Rider | 1 |
| `vehicle.kawasaki.ninja` | Kawasaki Ninja | 1 |
| `vehicle.vespa.zx125` | Vespa scooter | 1 |
| `vehicle.yamaha.yzf` | Yamaha YZF | 1 |
| `vehicle.bh.crossbike` | BH crossbike | 1 |
| `vehicle.diamondback.century` | Diamondback Century road bike | 1 |
| `vehicle.gazelle.omafiets` | Gazelle city bike | 1 |

Vehicle lights (`environment.py --cars`): `Position`, `LowBeam`, `HighBeam`,
`Brake`, `RightBlinker`, `LeftBlinker`, `Reverse`, `Fog`, `Interior`,
`Special1`, `Special2` (emergency lights), `All`, `None`.

## Pedestrians

52 pedestrians, spawned as `walker.pedestrian.<id>`. `generate_traffic.py`
uses generation 2 by default; add `--generationw All` for all of them.

| Group | Count | IDs (* can use a wheelchair) |
|---|---|---|
| Adult women | 21 | 0001* 0005* 0006* 0007* 0008* 0015* 0019* 0020* 0021* 0022* 0023* 0031* 0032 0035* 0036* 0037* 0040* 0041* 0042 0043 0044 |
| Adult men | 21 | 0002* 0003* 0004* 0016* 0017* 0018* 0024* 0025* 0026* 0027* 0028* 0029* 0030 0033* 0034* 0038* 0039* 0045* 0046* 0047* 0052 |
| Girls | 5 | 0009 0010 0011 0048 0049 |
| Boys | 3 | 0012 0013 0014 |
| Teenage girl | 1 | 0050 |
| Teenage boy | 1 | 0051 |

Walking speeds: 1.8 m/s (walk) and 4.0 m/s (run). Pedestrians are steered by
the `controller.ai.walker` controller.

## Props

99 static objects, spawned as `static.prop.<name>` from the Python API.

- **Tiny (13):** bikehelmet, brokentile01–04, colacan, garbage01–06, mobile
- **Small (49):** barbeque, barrel, box01–03, briefcase, calibrator,
  chainbarrierend, constructioncone, creasedbox01–03, dirtdebris01–03,
  doghouse, gardenlamp, gnome, guitarcase, ironplank, mailbox, motorhelmet,
  plantpot01–08, plasticbag, plasticchair, purse, shoppingbag,
  shoppingtrolley, streetbarrier, streetfountain, streetsign, streetsign04,
  trafficcone01, trafficcone02, trashbag, trashcan01–05, travelcase,
  wateringcan
- **Medium (25):** advertisement, atm, bench01–03, bin, chainbarrier,
  clothcontainer, container, foodcart, glasscontainer, haybale, haybalelb,
  kiosk_01, maptable, plastictable, platformgarbage01, shoppingcart,
  streetsign01, swing, swingcouch, table, vendingmachine, warningaccident,
  warningconstruction
- **Big (11):** aporosatree, busstop, busstoplb, clothesline, coconutpalm,
  cypresstree, fountain, pergola, slide, trafficwarning, trampoline
- **Other:** mesh (unsized), plus `static.trigger.friction` (a patch of road
  with different grip)

## Sensors

19 sensors, attached to a vehicle from the Python API. Cameras default to
800 × 600 with a 90° field of view.

| Sensor | What it gives |
|---|---|
| `sensor.camera.rgb` | Colour image |
| `sensor.camera.depth` | Distance per pixel |
| `sensor.camera.semantic_segmentation` | Object class per pixel |
| `sensor.camera.instance_segmentation` | Object class and instance per pixel |
| `sensor.camera.optical_flow` | Pixel motion between frames |
| `sensor.camera.normals` | Surface direction per pixel |
| `sensor.camera.dvs` | Event camera (brightness changes) |
| `sensor.camera.cosmos_visualization` | Combined visualization used by `carla_cosmos_gen.py` |
| `sensor.lidar.ray_cast` | 3D point cloud (default: 32 channels, 10 m range) |
| `sensor.lidar.ray_cast_semantic` | Point cloud with object classes |
| `sensor.other.radar` | Detections with velocity (default: 100 m range) |
| `sensor.other.gnss` | Latitude, longitude, altitude |
| `sensor.other.imu` | Acceleration, rotation, compass |
| `sensor.other.collision` | Collision events |
| `sensor.other.lane_invasion` | Lane-marking crossings |
| `sensor.other.obstacle` | Nearest obstacle ahead (default: 5 m) |
| `sensor.other.rss` | Responsibility-Sensitive Safety checks (may need a CARLA build with RSS enabled) |
| `sensor.other.v2x`, `sensor.other.v2x_custom` | Vehicle-to-everything messages |

## Scenarios

ScenarioRunner scenarios are run with `scenario_runner.py` (see
[USAGE.md](USAGE.md#scenarios)). Each scenario's town, ego vehicle, and
weather are set in its definition file, not on the command line.

### Named scenarios

119 scenarios, run with `--scenario <name>`, or every scenario of one type
with `--scenario group:<Type>`. Definitions are in
`scenario_runner/srunner/examples/*.xml`. The ego vehicle is the Lincoln MKZ
2017, except FreeRide and MultiEgo, which use the Tesla Model 3.

| Type | What happens | Scenarios (town) |
|---|---|---|
| ControlLoss | The ego vehicle loses control on a bad road surface and must recover | ControlLoss_1–3 (Town01), 4–6 (Town02), 7–9 (Town03), 10–12 (Town04), 13–15 (Town05) |
| FollowLeadingVehicle | A car ahead slows down and stops | FollowLeadingVehicle_1–2 (Town01), 3 and 11 (Town02), 4 (Town03), 5–7 (Town04), 8–10 (Town05) |
| FollowLeadingVehicleWithObstacle | The car ahead brakes for an obstacle | Same numbering and towns as FollowLeadingVehicle |
| OtherLeadingVehicle | Two cars ahead in neighbouring lanes; one slows down | OtherLeadingVehicle_1–7 (Town04), 8–10 (Town05) |
| ChangeLane | A fast car ahead changes lanes to pass a slow one, revealing it | ChangeLane_1 (Town04), ChangeLane_2 (Town01) |
| CutIn | A car cuts in front on a highway | CutInFrom_left_Lane, CutInFrom_right_Lane (Town04) |
| HighwayCutIn | A car cuts in from a highway on-ramp | HighwayCutIn_1 (needs a "Highway" map that is not installed, so it cannot run) |
| EnterActorFlow | Merge into a flow of traffic | EnterActorFlow_1 (Town04) |
| NoSignalJunctionCrossing | Cross a junction without signals as another car arrives | NoSignalJunctionCrossing (Town03) |
| OppositeVehicleRunningRedLight | A crossing car runs a red light | OppositeVehicleRunningRedLight_1–3 (Town03), 4–5 (Town04) |
| SignalizedJunctionLeftTurn | Turn left at a signalled junction with oncoming traffic | SignalizedJunctionLeftTurn_1 (Town03), 2–3 (Town04), 4–6 (Town05) |
| SignalizedJunctionRightTurn | Turn right at a signalled junction with crossing traffic | SignalizedJunctionRightTurn_1 (Town03), 2–3 (Town04), 4–7 (Town05) |
| VehicleTurningRight, VehicleTurningLeft | A cyclist appears just after the ego turns | _1–3 (Town01), 4–6 (Town02), 7 (Town03), 8 (Town04) |
| StationaryObjectCrossing | A stationary object blocks the lane | StationaryObjectCrossing_1–2 (Town02), 3–4 (Town03), 5 (Town04), 6–8 (Town05) |
| DynamicObjectCrossing | A pedestrian or cyclist crosses suddenly from behind an obstacle | DynamicObjectCrossing_1–2 (Town02), 3–4 and 9 (Town03), 5 (Town04), 6–8 (Town05) |
| ManeuverOppositeDirection | An oncoming car moves into the ego's lane to overtake | ManeuverOppositeDirection_1 (Town03), 2–3 (Town04), 4 (Town05) |
| ConstructionObstacle | A construction zone blocks the lane | ConstructionObstacle (Town02), Construction_1 (Town04) |
| Accident | An accident blocks the lane ahead | Accident_1 (Town04) |
| VehicleOpensDoorTwoWays | A parked car opens its door into the lane | VehicleOpensDoorTwoWays_1 (Town10HD_Opt) |
| FreeRide | Only the ego vehicle; free driving | FreeRide_1–4 (Town01–Town04) |
| MultiEgo | Two ego vehicles | MultiEgo_1 (Town01), MultiEgo_2 (Town03) |

Only ChangeLane_1, CutInFrom_left_Lane, CutInFrom_right_Lane, and
FollowLeadingVehicle_1 set their own weather; the rest use the map's.

### Scenario types used only in routes

These have no named example; they occur at points along a route (`--route`).

| Type | What happens |
|---|---|
| AccidentTwoWays | An accident blocks the lane; the ego must use the opposite lane |
| BlockedIntersection | After a turn, a stopped vehicle blocks the road |
| ConstructionObstacleTwoWays | A construction zone; the ego must use the opposite lane |
| CrossingBicycleFlow | Cross a stream of cyclists |
| EnterActorFlowV2 | Merge onto a highway from a dedicated entry lane |
| HardBreakRoute | Traffic ahead brakes hard |
| HazardAtSideLane | Cyclists on a road without sidewalks |
| HazardAtSideLaneTwoWays | Same, passing via the opposite lane |
| HighwayExit | Leave a highway across a flow of traffic |
| InterurbanActorFlow | Turn off a country road across traffic |
| InterurbanAdvancedActorFlow | Turn onto a country road across traffic |
| InvadingTurn | During a turn, an oncoming car drifts into the ego's lane |
| MergerIntoSlowTraffic, MergerIntoSlowTrafficV2 | Merge into slow traffic |
| NonSignalizedJunctionLeftTurn, NonSignalizedJunctionRightTurn | Turn at a junction without signals, with traffic |
| OppositeVehicleTakingPriority | Another car takes priority at a junction without signals |
| ParkedObstacle, ParkedObstacleTwoWays | A badly parked car blocks the lane |
| ParkingCrossingPedestrian | A pedestrian steps out from behind a parked car |
| ParkingCutIn | A parked car pulls out in front of the ego |
| ParkingExit | The ego starts in a parking spot and must pull out |
| PedestrianCrossing | A group of pedestrians crosses the road |
| PriorityAtJunction | Helper: turns the ego's light green so it keeps its speed |
| StaticCutIn | A car stopped in the next lane cuts in |
| VehicleTurningRoute | A cyclist appears after a turn |
| VehicleTurningRoutePedestrian | A pedestrian appears after a turn |
| YieldToEmergencyVehicle | An emergency vehicle comes up behind; the ego must give way |

Routes also use some named types (ControlLoss, DynamicObjectCrossing,
SignalizedJunctionLeftTurn, and others).

### Routes

Run with `--route srunner/data/<file> --route-id <id>`, and an agent with
`--agent`.

| File | Routes | Town | Length | What's on it |
|---|---|---|---|---|
| `routes_town10.xml` | 1 (id 0) | Town10HD_Opt | Spans 0.3 km | ControlLoss ×4, DynamicObjectCrossing ×2, HardBreakRoute ×2, BlockedIntersection ×1 |
| `routes_devtest.xml` | 2 | Town12 | Spans 6–7 km | 119 scenario events, 25 types |
| `routes_training.xml` | 90 | Town12 | Spans 5–10 km | 4,629 events, 38 types |
| `routes_validation.xml` | 20 | Town13 | Spans 6–11 km | 1,786 events, 36 types |

### OpenSCENARIO files

OpenSCENARIO 1.x, run with `--openscenario srunner/examples/<file>`:

| File | Town | What it shows |
|---|---|---|
| `FollowLeadingVehicle.xosc` | Town01 | Follow a car that slows down |
| `CyclistCrossing.xosc` | Town01 | A cyclist crosses |
| `PedestrianCrossingFront.xosc` | Town01 | A pedestrian crosses in front |
| `CatalogExample.xosc` | Town01 | Pedestrian crossing using a catalog |
| `IntersectionCollisionAvoidance.xosc` | Town01 | Two cars timed to meet at a junction |
| `SyncArrivalIntersection.xosc` | Town01 | Synchronized arrival at a junction |
| `VehicleLateralDistance.xosc` | Town01 | Lateral-distance condition |
| `Slalom.xosc` | Town01 | Slalom |
| `ChangingWeather.xosc` | Town01 | Weather changes during the run |
| `LaneChangeSimple.xosc` | Town04 | Lane change |
| `LaneOffsetActionExample.xosc` | Town01 | Lane offset action |
| `OscControllerExample.xosc` | Town01 | Custom controller |
| `InitAddEntityAction.xosc`, `InitDeleteEntityAction.xosc`, `StoryAddEntityAction.xosc`, `StoryDeleteEntityAction.xosc` | Town01 | Adding and removing vehicles |

OpenSCENARIO 2.0, run with `--openscenario2 srunner/examples/<file>`. Most are
in Town04: `acceleration.osc`, `change_lane.osc`, `change_speed.osc`,
`cut_in_and_slow_range.osc`, `cut_in_and_slow_right.osc`, `emit.osc`,
`force_over_signal.osc`, `keep_lane.osc`, `method_invocation.osc`,
`one_of.osc`, `overspeed.osc`, `overtake1.osc`, `overtake_concrete.osc`,
`wait.osc`, `wait_elapsed.osc`. The exceptions are
`cut_in_and_slow_single_over_junction.osc` (Town03) and
`follow_trajectory.osc` (Town10HD_Opt). `basic.osc` is a shared library, not
a scenario.

### Grading criteria

Each scenario grades the ego vehicle with some of these. Results print at the
end of a run with `--output`.

| Criterion | Fails when |
|---|---|
| `CollisionTest` | The vehicle collides with anything (or a given actor) |
| `RunningRedLightTest` | It runs a red light |
| `RunningStopTest` | It does not stop at a stop sign |
| `KeepLaneTest` | It leaves its lane |
| `WrongLaneTest` | It drives against traffic |
| `OnSidewalkTest` | It drives on the sidewalk |
| `OffRoadTest` | It spends too long off the road |
| `OutsideRouteLanesTest` | It drives outside the route's lanes (reported as a percentage) |
| `InRouteTest` | It strays too far from the route |
| `RouteCompletionTest` | It does not complete the route (reported as a percentage) |
| `MinimumSpeedRouteTest` (shown as `MinSpeedTest`) | It drives much slower than the traffic around it |
| `ActorBlockedTest` (shown as `AgentBlockedTest`) | It stays nearly stopped for too long |
| `ScenarioTimeoutTest` | It cannot get through a scenario in time |
| `YieldToEmergencyVehicleTest` | It does not give way to an emergency vehicle |
| `MaxVelocityTest` | It exceeds a speed |
| `AverageVelocityTest` | Its average speed misses a target |
| `DrivenDistanceTest` | It does not drive a given distance |
| `ReachedRegionTest` | It does not reach a given area |
| `InRadiusRegionTest` | It is not within a given radius of a point |
| `EndofRoadTest` | It leaves the road it started on |

### Agents

Agents drive the ego vehicle on routes (`--agent <file>`) or in
`automatic_control.py` (`--agent <name>`).

| Agent | Where | Behaviour |
|---|---|---|
| NPC agent | `srunner/autoagents/npc_agent.py` | Follows the route at 30 km/h using CARLA's BasicAgent, so it ignores stop signs |
| Human agent | `srunner/autoagents/human_agent.py` | You drive with the keyboard |
| Dummy agent | `srunner/autoagents/dummy_agent.py` | Sends zero throttle and steering: a template to start your own agent from |
| ROS agent | `srunner/autoagents/ros_agent.py` | Base class for a ROS driving stack |
| `Basic` | `automatic_control.py` | Respects traffic lights and other vehicles; **ignores stop signs** |
| `Behavior` | `automatic_control.py` | Adds lane changes, tailgating avoidance, and speed profiles; also ignores stop signs |
| `Constant` | `automatic_control.py` | Drives at a fixed speed |

Behavior agent profiles (`automatic_control.py --behavior <profile>`):

| Profile | Top speed (km/h) | Drives this far under the speed limit (km/h) | Emergency-brakes within (m) |
|---|---|---|---|
| `cautious` | 40 | 6 | 6 |
| `normal` (default) | 50 | 3 | 5 |
| `aggressive` | 70 | 1 | 4 |
