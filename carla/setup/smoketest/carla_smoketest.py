#!/usr/bin/env python3
"""
CARLA 0.9.16 smoke test.

Connects to a running CARLA server, prints the client/server versions, loads a
town, spawns a vehicle with an attached RGB camera, ticks the world in
synchronous mode, and saves one rendered frame to disk. If the PNG lands and is
non-trivial in size, the GPU render path (Vulkan + NVIDIA) and the Python API
are both working end-to-end.

Usage (server must already be running):
    python carla_smoketest.py --host 127.0.0.1 --port 2000 --out frame.png
"""
import argparse
import os
import sys
import time

import carla


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=2000)
    ap.add_argument("--town", default="Town10HD_Opt")
    ap.add_argument("--out", default="frame.png")
    ap.add_argument("--timeout", type=float, default=60.0)
    args = ap.parse_args()

    client = carla.Client(args.host, args.port)
    client.set_timeout(args.timeout)

    print(f"[smoke] client API version: {client.get_client_version()}")
    print(f"[smoke] server API version: {client.get_server_version()}")

    print(f"[smoke] loading world: {args.town}")
    world = client.load_world(args.town)

    original = world.get_settings()
    settings = world.get_settings()
    settings.synchronous_mode = True
    settings.fixed_delta_seconds = 0.05
    world.apply_settings(settings)

    actors = []
    captured = {"image": None}
    try:
        bp = world.get_blueprint_library()
        vehicle_bp = bp.filter("vehicle.*")[0]
        # Use the first free spawn point; others may be occupied by traffic.
        vehicle = None
        for spawn in world.get_map().get_spawn_points():
            vehicle = world.try_spawn_actor(vehicle_bp, spawn)
            if vehicle is not None:
                break
        if vehicle is None:
            print("[smoke] FAIL: no free spawn point for the test vehicle")
            return 4
        actors.append(vehicle)
        print(f"[smoke] spawned vehicle: {vehicle.type_id}")

        cam_bp = bp.find("sensor.camera.rgb")
        cam_bp.set_attribute("image_size_x", "800")
        cam_bp.set_attribute("image_size_y", "600")
        cam_tf = carla.Transform(carla.Location(x=-6, z=3), carla.Rotation(pitch=-15))
        camera = world.spawn_actor(cam_bp, cam_tf, attach_to=vehicle)
        actors.append(camera)

        camera.listen(lambda img: captured.__setitem__("image", img))

        # Tick enough frames for the sensor to deliver and the scene to settle.
        for _ in range(30):
            world.tick()
            if captured["image"] is not None:
                break
            time.sleep(0.02)

        img = captured["image"]
        if img is None:
            print("[smoke] FAIL: no camera frame received")
            return 2

        img.save_to_disk(args.out)
        # save_to_disk is async-ish; give it a moment then verify.
        for _ in range(50):
            if os.path.exists(args.out) and os.path.getsize(args.out) > 10_000:
                break
            time.sleep(0.1)
        size = os.path.getsize(args.out) if os.path.exists(args.out) else 0
        print(f"[smoke] saved frame {args.out} ({size} bytes), "
              f"resolution {img.width}x{img.height}, frame {img.frame}")
        if size < 10_000:
            print("[smoke] FAIL: frame file suspiciously small")
            return 3
        print("[smoke] PASS: render + API working")
        return 0
    finally:
        for a in actors:
            try:
                a.destroy()
            except Exception:
                pass
        world.apply_settings(original)


if __name__ == "__main__":
    sys.exit(main())
