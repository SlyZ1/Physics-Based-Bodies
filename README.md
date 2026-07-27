

https://github.com/user-attachments/assets/a8ba13da-1c5e-4145-aed2-f90baff8921d

# Squishing Over It

Real-time soft-body / rigid-body physics platformer, built on Godot 4.3.

A low-poly 3D puzzle-platformer where the player controls a deformable jelly sphere navigating physics-driven obstacles. Built as a testbed for real-time soft-body simulation interacting with rigid dynamics, targeting stability and playability over physical accuracy.

Authors: Baptiste Girardin, Colin Marmond, Elyes Jemel, Édouard Vivares - IGR course, Télécom Paris, June 2026.

## Physics engine

Both the soft- and rigid-body solvers use semi-implicit Euler integration, chosen for its stability/simplicity trade-off in real time.

**Soft body.** The main character uses a custom mass-spring simulation rather than a full physics solver, tuned for stability and game-feel over accuracy. The mesh deforms on impact and springs back into shape, with a few tricks layered on top to keep it looking squishy and alive without exploding or losing its volume during hard collisions.

**Rigid body.** A simplified rigid body solver for box-shaped objects resting on flat ground. Collisions are resolved with soft-constraints, avoiding the jittering you'd normally get.

**Soft–rigid coupling.** Soft and rigid bodies push against each other: the soft body deforms and bounces off, while rigid bodies get knocked around based on the impact of each spring.

**Collision detection.** A lightweight system checks each part of the soft body against the level geometry, using a simple bounding volume around the whole character to keep things fast.

Full derivations (force/impulse formulas, soft-constraint feedback terms, volume-correction math) are in `Report.pdf`.

## Repository layout

```
squishy-game/   Godot 4.3 project (scenes, scripts, shaders)
assets/         models, textures
footage/        captures
papers/         references lookup at project beginning
```

## Core scripts

**`simple_squishy.gd`** - soft-body solver and character state. Public surface:

```gdscript
add_glob_acc(acc: Vector3) -> void
add_glob_vel(vel: Vector3) -> void
add_loc_acc(acc: Vector3, i: int) -> void
add_loc_vel(vel: Vector3, i: int) -> void
teleport(new_pos: Vector3, reset_vel_acc: bool = true) -> void
get_squeleton_center() -> Vector3
get_real_center() -> Vector3
get_vertex_in_dir(dir: Vector3) -> int
get_local_basis() -> Basis
```
Read-only state: `N`, `radius`, `is_colliding`, `glob_acc`, `glob_vel`.
Debug: `G` toggles gizmos, `P` pauses simulation.

**`mesh_utils.gd`** - mesh utilities: `create_icosphere`, `compute_neighbors`, `set_vertices`, `smooth_mesh`.

## Build

Requires Godot 4.3.

```bash
git clone https://github.com/SlyZ1/Physics-Based-Bodies.git
```
Open `squishy-game/` as a Godot project and run.

## Known limitations

- Dynamic-object collision occasionally tunnels under fast relative motion.
- Broad-phase / narrow-phase not optimized for low-end targets or low tick rates.
- Single-level prototype; no production content pipeline.
