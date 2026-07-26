# Serie

<img width="2560" height="1080" alt="serie banner" src="https://github.com/user-attachments/assets/60049c40-793d-4a7d-8fea-417b10494cce" />

Serie is the path-traced successor to allium and will serve as the base rewrite for allium's upcoming versions.

### IMPORTANT
> Serie is under active development. Expect settings, buffer layouts, and visual behavior to change between builds, as well as bugs!

## Requirements

- Minecraft Java Edition
- A recent version of [Iris Shaders](https://irisshaders.dev/)
- A GPU and driver with OpenGL 4.3 support
- Iris custom-image support (required by the voxel and irradiance-cache volumes)
- Distant Horizons is optional

Serie is developed for Iris. OptiFine is NOT supported.

## Current features
- Path-traced lighting
- Atmospheric scattering
- Volumetric light shafts
- Volumetric cumulus clouds
- A separate volumetric altocumulus layer
- Water parallax and vertex displacement
- Screen-space refraction and reflection
- Generated normals and refraction handling for glass and ice
- Distant Horizons Support (working on voxy soon)
- Integrated PBR (LabPBR not yet available)
- Temporal anti-aliasing and temporal upscaling
- Bloom
- Automatic exposure
- Multiple tone-mapping operators

## Installation

### Release build

1. Download a ZIP from the repository's [Releases page](https://github.com/clorece/Serie/releases).
2. Place the ZIP in your Minecraft `shaderpacks` directory.
3. Open Minecraft with Iris installed.
4. Select Serie from **Options → Video Settings → Shader Packs**.

Do not extract a release ZIP unless its outer archive contains another shaderpack folder or ZIP.

### Latest repository build

1. Select **Code → Download ZIP** on the [GitHub repository](https://github.com/clorece/Serie). (or git clone)
2. Extract the downloaded repository archive.
3. Place the folder containing `shaders/`, `README.md`, and `License.txt` in your `shaderpacks` directory.

Repository builds contain the newest changes and may be less stable than releases.

## Reporting bugs

Please open an issue on the [GitHub Issues page](https://github.com/clorece/Serie/issues) and include:

- A concise description of the problem
- Steps and a location/scene that reproduce it
- Minecraft, Iris, loader, and mod versions
- GPU model and driver version
- The active Serie settings or an exported shader configuration
- Screenshots or video when the issue is visual
- `latest.log` when the pack fails to load or reports a shader compilation error

Before reporting a visual artifact, test once with default settings and confirm whether Distant Horizons or another rendering mod is involved.

## Development status

The repository branch is the active development version. Stable builds, when available, are published through [GitHub Releases](https://github.com/clorece/Serie/releases).

Contributions and focused bug reports are welcome. When changing shader code, test at multiple render scales, during camera motion, at day/night transitions, underwater, and with Distant Horizons both enabled and disabled.

## Screenshots
<img width="2560" height="1440" alt="2026-06-19_13 55 20" src="https://github.com/user-attachments/assets/c5de53a7-d9fe-4a82-b652-b6dc1c2ca5c7" />
<img width="2560" height="1440" alt="2026-06-19_04 58 09" src="https://github.com/user-attachments/assets/37a48d60-00c4-444c-8c04-c11b16e80760" />
<img width="2560" height="1440" alt="2026-06-19_04 46 41" src="https://github.com/user-attachments/assets/4a92a336-9fc4-43b3-9897-d81013de431b" />
<img width="2560" height="1440" alt="2026-06-15_20 24 07" src="https://github.com/user-attachments/assets/11e3fe64-94a2-4df5-ab9c-6779996f429b" />
<img width="2560" height="1440" alt="2026-06-15_20 24 01" src="https://github.com/user-attachments/assets/7e4b3cda-d5a6-4fac-942b-923027e40ac3" />
<img width="2560" height="1440" alt="2026-06-15_20 23 25" src="https://github.com/user-attachments/assets/33f6534d-ae84-47de-8b7c-375bc73fbac8" />
<img width="2560" height="1440" alt="2026-06-15_20 22 57" src="https://github.com/user-attachments/assets/d4547eca-447c-4d3a-8f26-a443ae8ce56d" />
<img width="2560" height="1440" alt="2026-06-15_20 15 27" src="https://github.com/user-attachments/assets/0f248606-44e1-4a70-937e-2e266029b5c7" />
<img width="2560" height="1440" alt="2026-06-15_20 06 11" src="https://github.com/user-attachments/assets/f1fcd585-3402-4b2a-b2bb-2dfe5a52cadb" />
<img width="2560" height="1440" alt="2026-06-15_20 05 13" src="https://github.com/user-attachments/assets/0a594301-648f-49ef-ab48-20a544b7c61e" />
<img width="2560" height="1440" alt="2026-06-15_20 04 36" src="https://github.com/user-attachments/assets/a2e21c27-988f-443a-9305-c127d82f72ce" />
