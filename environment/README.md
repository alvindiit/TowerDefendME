# Environment asset replacements

Assign imported `.glb` scenes to the **Environment GLB Replacements** exports on the game root in the Inspector. Each scene replaces one procedural environment prop category while the map grid, cell coordinates, and placement positions stay unchanged.

| Export | Suggested asset |
| --- | --- |
| `environment_outcrop_asset` | Basalt cliff or rock outcrop |
| `environment_rock_cluster_asset` | Small rock and rubble cluster |
| `environment_vegetation_asset` | Bush, scrub, or low vegetation |
| `environment_grass_asset` | Grass tuft or ground plant |
| `environment_debris_asset` | Industrial wreckage or debris |

The visible ground is one continuous, higher-density terrain mesh, not the gameplay grid cells. Its vertex heights shape a shallow worn route, flatter build pads, rolling field contours, and an irregular perimeter cliff. Small terrain scatter and ground wear use `MultiMeshInstance3D` batches to limit draw calls.

Assign seamless textures in the **Terrain PBR Texture Maps** exports: grass, rock, dirt, and mud each have albedo, tangent-space normal, and ORM slots. ORM maps use red for ambient occlusion, green for roughness, and blue for metallic. The procedural shader blends the layers across the mesh's route, grass, and build-pad masks, with generated fine normal and roughness variation as a fallback when maps are not assigned.

The project does not include authored terrain texture sets or environment GLBs. Until production assets are assigned, procedural shader detail and low-poly fallback scatter keep the scene self-contained. Use tiling 2K or 4K albedo, normal, and ORM maps for the production grass, weathered soil, damp mud, and rock materials. Keep color maps in sRGB and normal/ORM maps linear; use seamless textures with consistent physical scale.

Desktop rendering is configured for Forward+ at 1920×1080, 4× MSAA, 16× anisotropic filtering, full-resolution SSAO/SSIL, and high-quality directional shadow filtering. Terrain samplers request mipmapped anisotropic filtering. Assign 2K textures to the game root's **Terrain PBR Texture Maps** fields; this project currently contains no terrain texture images, so the material uses its procedural fallback until those assets are added.

Prepare each GLB with its root at the center of its footprint, the bottom of the model at local `Y = 0`, and its main facing direction along `-Z`. Keep PBR albedo, normal, roughness, and metallic textures embedded or referenced by the GLB. The environment continues to build if an export is unassigned; the existing procedural prop is then used as a temporary fallback until a production asset is assigned.
