#!/usr/bin/env python3
"""
CARLA 0.9.16 native ROS 2 check.

The server must be launched with `--ros2`. Spawns an ego vehicle named `hero`
with an RGB camera, enables the camera for ROS, and keeps both alive
(asynchronous mode) so a ROS 2 node can observe the topics:

    /clock, /tf
    /carla/hero/front_rgb/image, /carla/hero/front_rgb/camera_info
    /carla/hero/vehicle_control_cmd, /carla/hero/ackermann_control_cmd  (inputs)

CARLA only namespaces topics under the vehicle when its role/ROS name is
`hero`; other names produce `/carla//<sensor>/...`.

Usage (server already running):
    python ros2_publisher.py --secs 60
"""
import argparse
import sys
import time

import carla

EGO_NAME = "hero"
CAMERA_NAME = "front_rgb"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=2000)
    ap.add_argument("--secs", type=float, default=45.0)
    args = ap.parse_args()

    client = carla.Client(args.host, args.port)
    client.set_timeout(30.0)
    world = client.get_world()
    print("server version:", client.get_server_version(), flush=True)
    if world.get_settings().synchronous_mode:
        print("WARNING: world is in synchronous mode and this script does not tick it; "
              "no data will be published. Run `python $CARLA_ROOT/PythonAPI/util/config.py "
              "--no-sync` first.", flush=True)

    actors = []
    try:
        bp = world.get_blueprint_library()

        vbp = bp.filter("vehicle.*")[0]
        vbp.set_attribute("role_name", EGO_NAME)
        vbp.set_attribute("ros_name", EGO_NAME)
        # Use the first free spawn point; others may be occupied by traffic.
        vehicle = None
        for spawn in world.get_map().get_spawn_points():
            vehicle = world.try_spawn_actor(vbp, spawn)
            if vehicle is not None:
                break
        if vehicle is None:
            print("ERROR: no free spawn point for the ego vehicle", flush=True)
            return 1
        actors.append(vehicle)
        print("spawned ego:", vehicle.type_id, flush=True)

        cam_bp = bp.find("sensor.camera.rgb")
        cam_bp.set_attribute("image_size_x", "640")
        cam_bp.set_attribute("image_size_y", "480")
        cam_bp.set_attribute("sensor_tick", "0.1")
        cam_bp.set_attribute("role_name", CAMERA_NAME)
        cam_bp.set_attribute("ros_name", CAMERA_NAME)
        cam = world.spawn_actor(cam_bp, carla.Transform(carla.Location(x=1.5, z=2.0)),
                                attach_to=vehicle)
        actors.append(cam)
        cam.enable_for_ros()
        print(f"camera enabled for ROS: /carla/{EGO_NAME}/{CAMERA_NAME}/image", flush=True)

        print(f"publishing for {args.secs}s (async mode)...", flush=True)
        time.sleep(args.secs)
        print("done", flush=True)
        return 0
    finally:
        for a in reversed(actors):
            try:
                a.destroy()
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())
