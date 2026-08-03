# Studio–Engine Effect Runtime v0.1

## Fixed architecture principle

The studio exports an **effect program**: assets, ordered operator nodes and parameters.
The Android engine executes that program in real time.

A new filter must not require a new Kotlin enum or an APK rebuild. Kotlin changes are
only required when the engine gains a completely new reusable operator capability,
for example `lip_makeup`, `face_reshape` or `particles`.

## Scope of step 01

This step establishes the package contract and parser. Only the `sticker_2d` operator
is accepted at runtime in schema 0.1.0. The graph container is already present so
future operators can be added without redesigning the package lifecycle.

## Package layout

```text
my_effect/
├── effect.json
└── textures/
    └── glasses.png
```

All asset paths in `effect.json` are relative to the package root. Absolute paths,
`..` traversal and non-PNG sticker assets are rejected in v0.1.

## Planned reusable operators

1. `sticker_2d` — first implementation.
2. `screen_overlay`.
3. `beauty` — maps to the existing live beauty pipeline.
4. `face_reshape` — maps to the existing nose/shape/eyes/mouth warp controls.
5. `lip_makeup`, `eye_makeup`, `blush_contour`.
6. `color_adjust` and `lut`.
7. `model_3d`, `particles`, `trigger` later.

The studio will create many filter combinations by changing node parameters. The
engine implements each operator once.

## Step 01 acceptance criteria

- A valid `effect.json` becomes an `EffectManifest`.
- Invalid JSON returns structured errors.
- Unsupported schema/node types are rejected.
- Node ids are unique.
- Sticker paths are safe and relative.
- Landmark, opacity and transform values are validated.
- No renderer or camera code is modified in this step.
