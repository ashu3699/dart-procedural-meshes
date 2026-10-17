# dart-procedural-meshes

Procedural triangle meshes in pure Dart — the geometry layer behind the
[Rasterizer demo](https://portfolio.ashutoshkrdev.in/app/rasterizer) in my portfolio. Zero
dependencies, zero model assets: every shape is generated at runtime.

## What's inside

`MeshData` stores packed data — `Float32List` positions, `Uint32List`
indices, per-vertex and per-face normals — and offers three builders:

- **`icosphere(subdivisions)`** — recursive midpoint subdivision of an
  icosahedron with an edge-midpoint cache. Vertices are normalised to the unit
  sphere while subdividing, so smooth normals come for free.
- **`torus({major, minor, ...})`** — analytic normals straight from the
  parametric surface.
- **`torusKnot({steps, tube, ...})`** — a tube swept along a trefoil curve
  using **parallel-transport frames**, which avoids the twisting a naive
  Frenet frame produces at inflection points.

All builders funnel through **`fromParts`**, which welds raw lists into
packed arrays and **re-winds any triangle whose geometric normal disagrees
with the averaged vertex normal** — so hand-built geometry cannot silently
break backface culling.

## Run the checks

```
dart pub get
dart run bin/check.dart
```

For each builder the script asserts: finite vertices, unit-length normals,
winding agreement with outward normals, **closed-manifold edge parity**, and a
sane bounding radius — then pushes a sample point through a pinhole projection.
It prints `ok`/`FAIL` per assertion and exits non-zero on failure. The same
script runs in CI on every push.

## Honest scope

- The demo rasterises with a **painter's-algorithm sort — there is no depth
  buffer**, so intersecting triangles can pop.
- No texture coordinates or UV mapping.
- `fromParts` only fixes winding; it does not merge duplicate vertices or
  validate index ranges.

MIT © Ashutosh Kumar
