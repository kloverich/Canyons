# Canyons

## Curling canyon terrain demo

Run the project in Godot to open a sample scene containing three procedural
canyon chunks. The forms are generated at runtime by
`curled_terrain_generator.gd`; they are broad, extruded cliff ribbons following
a Bezier-to-hook centerline, which produces the breaking-wave / curled-frond
silhouette from the concept art. Every rock includes a `StaticBody3D` with a
triangle-mesh collision shape, so it is ready to serve as walkable level
geometry.

- `R` advances the seed and rebuilds the sample.
- `P` switches between unique infinite chunks and a repeating 28-unit chunk.
- `A`/`D`/`W`/`S` pan the camera; `Q`/`E` zoom.

To use it in a level, instantiate `CurledTerrainGenerator`, call
`build_chunk(chunk_index)`, and add the returned node to your world. In
`PERIODIC` mode, neighboring chunk indices use identical local geometry and
translate by `period`, so their visual pattern repeats exactly. In `INFINITE`
mode each integer index deterministically derives a different seed.
