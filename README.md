# Physics-Based-Bodies

Platformer game on Godot 4.3 that plays with the physics of squishy bodies.

## `rigid_body.gd`
### Quick explanation
---

This script handles a simple rigid body simulation for a mesh, including linear and angular dynamics, collision response with a ground plane, and friction.

Collision response is computed per-vertex using **impulse-based resolution**, taking into account the inverse inertia tensor to correctly distribute forces between linear and angular velocities.

The inverse inertia tensor is computed from the mesh's local scale (assuming a box shape) and rotated into world space each frame.

### Controls for debug purposes
`Jump` (via `InputManager`) : Reset and restart the simulation with a random rotation

### How to use
---

#### Usage Example
```gdscript
class_name ThrowRigidBody
extends Node

@export var body: RigidBody # reference of rigid_body.gd in the scene

func _ready() -> void:
    body.add_vel(Vector3(5, 10, 0))
    body.add_angular_vel(Vector3(0, 2, 1))
```

> [!WARNING]
> Please do not modify any variable or use any function of the script that are not mentionned below, in order to prevent from unwanted behaviors

#### Public methods:

- `add_vel(vel: Vector3) -> void` : add a linear velocity to the body
- `add_acc(acc: Vector3) -> void` : add a linear acceleration to the body
- `add_angular_vel(vel: Vector3) -> void` : add an angular velocity to the body
- `add_angular_acc(acc: Vector3) -> void` : add an angular acceleration to the body
- `add_impact(origin: Vector3, force: Vector3) -> void` : apply an impulse force at a world-space `origin` point, affecting both linear and angular velocities accordingly

#### Public variables:

- `N` : RO, number of vertices
- `is_colliding` : RO, whether the body is currently colliding with the ground
- `glob_vel` : RO, current linear velocity of the body
- `glob_angular_vel` : RO, current angular velocity of the body
- `inverse_inertia_tensor` : RO, current inverse inertia tensor in world space