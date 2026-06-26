# Squishing Over It

Real-time soft-body / rigid-body physics platformer, built on Godot 4.3.

A low-poly 3D puzzle-platformer where the player controls a deformable jelly sphere navigating physics-driven obstacles. Built as a testbed for real-time soft-body simulation interacting with rigid dynamics, targeting stability and playability over physical accuracy.

Authors: Baptiste Girardin, Colin Marmond, Elyes Jemel, Édouard Vivares — IGR course, Télécom Paris, June 2026.

## Physics engine

Both the soft- and rigid-body solvers use semi-implicit (symplectic) Euler integration, chosen for its stability/simplicity trade-off in real time.

**Soft body.** The character is a custom mass-spring system on a geodesic-sphere mesh, not a physically accurate solver. Each vertex is held in place by two springs: one pulling it back toward its rest position on an undeformed reference sphere (shape recovery), and one pulling it toward the object's center at a fixed radius (a rough stand-in for volume conservation). Global motion (the object moving through the world) and local motion (the mesh deforming on impact) are integrated separately and only reconciled during collisions — this separation is what keeps the simulation stable instead of diverging on impact. A few corrective terms are layered on top: one to cancel out the extra energy bounces would otherwise add, one to make wall collisions stiffer than ground collisions (so the player can't squeeze through gaps), and one that nudges the rest radius per-vertex to fake volume conservation under heavy deformation.

**Rigid body.** Limited to box shapes resting on infinite planes, which keeps the inertia tensor simple and avoids edge-on-edge collision cases entirely. Penetration is resolved with soft constraints — modeling the correction as a damped spring rather than snapping objects apart instantly — which removes the jittering typical of instant depenetration. Contact response otherwise follows the standard impulse-based approach (linear + angular velocity update from a single impulse at the contact point).

**Soft–rigid coupling.** The soft body bounces off rigid bodies as if they were momentarily static, while each contacting vertex pushes back on the rigid body with an impulse scaled by both masses. A small velocity-based offset is added to stop the soft body from passing through a rigid body that's moving toward it.

**Collision detection.** Each vertex's collision is found by tracing a line segment from its last position to its newly integrated position and checking it against the level's triangles. To avoid testing every vertex against every triangle in the scene, a single bounding sphere around the whole character (rather than a full spatial hierarchy like a BVH) is used as a cheap first filter — sufficient here since there's only one moving soft body.

Full derivations (force/impulse formulas, soft-constraint feedback terms, volume-correction math) are in `papers/Report.pdf`.

## Repository layout

```
squishy-game/   Godot 4.3 project (scenes, scripts, shaders)
assets/         models, textures
footage/        captures
papers/         Report.pdf (technical writeup)
```

## Core scripts

**`simple_squishy.gd`** — soft-body solver and character state. Public surface:

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

**`mesh_utils.gd`** — mesh utilities: `create_icosphere`, `compute_neighbors`, `set_vertices`, `smooth_mesh`.

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