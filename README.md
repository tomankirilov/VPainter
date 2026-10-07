# VPainter for Godot 4.x

I made VPainter to paint vertex colors directly in Godot's 3D editor. This version focuses only on vertex colors: I've removed tablet support and mesh deformation, since they turned into scope creep more than something I actually needed.

Copy the `addons/vpainter` folder into your project and enable VPainter in **Project Settings > Plugins**. Select a mesh and click the VPainter icon to start.

What's here / what's new:
* Paint, fill and blur, with strength and separate R, G, B and A channels.
* Paint multiple meshes together, with automatic local copies and undo.
* A brush size preview, `[` / `]` to resize, and two colors you can swap with `X`.
* Copy/paste vertex colors, reload a mesh while keeping its colors, and rebuild LODs.

Color transfer and mesh reloading took me a while to figure out! I tried a bunch of versions comparing UVs and whatnot before realizing I could just compare positions and linearly blend colors across the closest triangles. This lets me carry the paint over even when the new mesh has different topology.

There are no shaders included with this version. Example images will come soon!
