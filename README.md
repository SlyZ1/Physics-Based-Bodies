# Physics-Based-Bodies

Platformer game on Godot 4.3 that plays with the physics of squishy bodies.

## `simple_squishy.gd`
### Quick explanation
---

This script is responsible for handling all the forces applied to the main character.

To make the body look "squishy", we used a spring based soft body along with an Euler integrator. For each vertices, 2 springs are assigned:
- <b>One linked to a default position</b>, to make sure the shape is relatively conserved 
- <b>One linked to the center</b>, to make sure a certain radius is maintained, ensuring a simple volume conservation

The real positions of the vertices are separated from the positions of the "squeleton" (the default positions mentionned above). \
_The squeleton is in fact just a normal sphere whitout deformations_

The positions of the squeleton are only affected by the real positions during collisions to recalculate the center of the mesh.

### Controls
---

`WASD` _(or ZQSD for EU)_ : Move \
`Space` : Jump \

#### For debug purposes
`G` : Toggle gizmos \
`P` : Pause the simulation and switch to free cam

### How to use
---

> [!WARNING]
> Please do not modify any variable or use any function of the script that are not mentionned below, in order to prevent from unwanted behaviors

#### Public methods:

`add_glob_acc(acc: Vector3)` : add an acceleration to the squeleton \
`add_glob_vel(vel: Vector3)` : add a velocity to the squeleton \
`add_loc_acc(acc: Vector3, i: int)` : add an acceleration to the number `i` vertex \
`add_loc_vel(vel: Vector3, i: int)` : add a velocity to the number `i` vertex \
`teleport(new_pos: Vector3, reset_vel_acc: bool = true)` : teleport the center of the squeleton <b>and</b> real positions `new_pos`. Resets all the velocities and accelerations if `reset_vel_acc` is `true`

#### Public variables:

`N` : number of vertices \
`radius` : radius of the sphere \
`is_colliding` : whether the body collides with something or not