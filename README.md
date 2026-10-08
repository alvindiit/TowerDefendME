# TowerDefendME

A small low-poly, tile-based 3D tower-defense prototype built with Three.js.

## Open the Godot version

Install Godot 4, open the Project Manager, choose **Import**, and select this folder (the one containing `project.godot`). Open the project and press **F6** to run the main scene or **F5** to run the project. Choose Ranger, Cannon, Frost, or free Ankan, click a dark brown pad to place it, then press **Start Wave**. Rangers fire fast single shots, Cannons deal splash damage, Frost towers slow enemies, and Ankan bolts chain to nearby enemies.

### Camera controls

- Hold the **right mouse button** and drag to orbit the board.
- Hold the **middle mouse button** and drag to pan; movement is bounded around the board.
- Use the **mouse wheel** to zoom in and out.
- Press **R** to reset the camera to its default isometric view.

Orbit tilt and zoom are clamped so the camera remains in a practical view of the board.

Click a placed tower to open its actions. An upgrade costs 100 gold and increases damage, range, and firing speed. Removing a tower does not refund its build cost.

MiangBoss appears during wave 1 after a two-second warning. Regular enemies continue spawning while the boss warning counts down. Its “Boss appear!” and “MIANGBOSS ENTERS!” notices last about one second. Four seconds after entering, MiangBoss jumps, shakes the camera, and shouts “TUA PUI!” in a comic speech cloud beside its mouth.

Press **Skill Check** and then **Space** to stop the moving marker. The meter closes after each attempt and can be opened again. Green scores 100 points, shows a celebration burst, and empowers each current tower's next shot to deal 5× damage with a 5× larger projectile. Yellow scores 50, and red scores 0. Tower firing intervals are doubled to make attacks slower.

The Godot version is native GDScript and does not need the Three.js CDN.

## Remodel the tower scenes

The game already uses separate editable scenes: `towers/ranger_tower.tscn`, `towers/cannon_tower.tscn`, `towers/frost_tower.tscn`, and the imported `towers/Ankan_tower.glb`. Open a scene from the FileSystem dock and edit the meshes, colors, and parts in the Inspector. Save the scene, then run the game to see the change. You can also import a `.glb` from Blender. Keep the model's base at its root origin and its height around 1.3 world units.

The tower scenes control appearance. Range, cost, attack behavior, and projectile effects remain in `main.gd`.

The enemy is an editable scene at `enemies/basic_enemy.tscn`. Edit its meshes and materials the same way. Keep the main body as a `MeshInstance3D` named `Body` so hit flashes and Frost effects can recolor it. Enemy movement and health remain in `main.gd`.

The Ankan GLB model is assigned in the **Custom tower models** group on the `TowerDefendME` root node in `main.tscn`.

## Run it

Serve this folder over HTTP, then open the local address in a browser. For example, with Python installed, run `python -m http.server 8000` from this folder and open `http://localhost:8000`.

The page imports Three.js 0.186.1 from jsDelivr, so the browser needs an internet connection. The camera is orthographic and angled to create the isometric view. Click the light stone tiles to place towers, then start a wave.
