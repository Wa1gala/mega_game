# Генератор сцены art/levels/office_corridor.tscn
# Закольцованный прямоугольный коридор с проёмами под будущие комнаты.

UID_PLAYER = "uid://5sgy0k2htp7b"
UID_PAUSE = "uid://dgaitm8l3pp6"
UID_WALL = "uid://dj3jdv1nwt0f6"     # cubicle_fabric_grey_trim_albedo.png
UID_FLOOR = "uid://b8orc4bpj20uh"    # carpet_pattern_burgundy_albedo.png
UID_CEIL = "uid://3av4u04ik1gc"      # light_panel_prismatic_albedo.png

# ---------- геометрия ----------
OX0, OX1 = -18.0, 18.0        # внешний контур
OZ0, OZ1 = -14.0, 14.0
IX0, IX1 = -14.0, 14.0        # внутренний остров (коридор 4 м шириной)
IZ0, IZ1 = -10.0, 10.0

WALL_H = 5.0
WALL_CY = 1.5                 # стена от -1 до 4
CEIL_Y = 3.9
T = 0.3                       # толщина стен

OPEN_W = 5.0                  # ширина проёма
OPEN_H = 3.2                  # высота проёма от пола

LANDING = 4.0                 # выступ пола наружу от проёма

ext, sub, nodes = [], [], []
_rid = [0]


def rid():
    _rid[0] += 1
    return "r%d" % _rid[0]


def ext_res(typ, uid, path):
    r = rid()
    ext.append('[ext_resource type="%s" uid="%s" path="%s" id="%s"]' % (typ, uid, path, r))
    return r


def node(t):
    nodes.append(t)


def box_mesh(mid, sx, sy, sz):
    sub.append('[sub_resource type="BoxMesh" id="%s"]\nsize = Vector3(%g, %g, %g)' % (mid, sx, sy, sz))


def box_shape(mid, sx, sy, sz):
    sub.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = Vector3(%g, %g, %g)' % (mid, sx, sy, sz))


E_WALL_TEX = ext_res("Texture2D", UID_WALL, "res://art/levels/office/textures/walls/cubicle_fabric_grey_trim/cubicle_fabric_grey_trim_albedo.png")
E_FLOOR_TEX = ext_res("Texture2D", UID_FLOOR, "res://art/levels/office/textures/floors/carpet_corridor/carpet_pattern_burgundy_albedo.png")
E_CEIL_TEX = ext_res("Texture2D", UID_CEIL, "res://art/levels/office/textures/ceilings/light_panel_prismatic/light_panel_prismatic_albedo.png")
E_PLAYER = ext_res("PackedScene", UID_PLAYER, "res://player.tscn")
E_PAUSE = ext_res("PackedScene", UID_PAUSE, "res://scenes/pause_menu.tscn")

# ---------- материалы ----------
sub.append('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.012, 0.014, 0.016, 1)
ambient_light_source = 2
ambient_light_color = Color(0.05, 0.06, 0.07, 1)
ambient_light_energy = 0.18
tonemap_mode = 3
tonemap_exposure = 0.9
ssao_enabled = true
ssao_radius = 1.4
ssao_intensity = 1.8
ssao_power = 2.0
glow_enabled = true
glow_intensity = 0.5
glow_bloom = 0.2
glow_hdr_threshold = 0.7
volumetric_fog_enabled = true
volumetric_fog_density = 0.09
volumetric_fog_albedo = Color(0.62, 0.66, 0.6, 1)
volumetric_fog_emission = Color(0.04, 0.05, 0.04, 1)
volumetric_fog_emission_energy = 0.15
volumetric_fog_gi_inject = 0.0
volumetric_fog_anisotropy = 0.45
volumetric_fog_length = 24.0''')

sub.append('''[sub_resource type="StandardMaterial3D" id="mat_corridor_floor"]
cull_mode = 2
albedo_texture = ExtResource("%s")
roughness = 0.95
uv1_scale = Vector3(52, 40, 1)
texture_filter = 2''' % E_FLOOR_TEX)

sub.append('''[sub_resource type="StandardMaterial3D" id="mat_corridor_wall"]
cull_mode = 2
albedo_texture = ExtResource("%s")
roughness = 0.9
uv1_scale = Vector3(22, 1.7, 1)
texture_filter = 2''' % E_WALL_TEX)

sub.append('''[sub_resource type="StandardMaterial3D" id="mat_corridor_ceil"]
cull_mode = 2
albedo_texture = ExtResource("%s")
roughness = 0.85
uv1_scale = Vector3(70, 55, 1)
texture_filter = 2''' % E_CEIL_TEX)

# ---------- пол и потолок ----------
FW = OX1 - OX0 + LANDING * 2
FD = OZ1 - OZ0 + LANDING * 2
box_mesh("mesh_floor", FW, 0.2, FD)
box_shape("shape_floor", FW, 0.2, FD)

node('[node name="Corridor" type="Node3D"]')
node('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')

node('[node name="Floor" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)')
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]\nmaterial_override = SubResource("mat_corridor_floor")\nmesh = SubResource("mesh_floor")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]\nshape = SubResource("shape_floor")')

node('[node name="Ceiling" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %g, 0)' % CEIL_Y)
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Ceiling"]\nmaterial_override = SubResource("mat_corridor_ceil")\nmesh = SubResource("mesh_floor")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Ceiling"]\nshape = SubResource("shape_floor")')

# ---------- внутренний остров (глухой блок) ----------
IW = IX1 - IX0
ID = IZ1 - IZ0
box_mesh("mesh_island", IW, WALL_H, ID)
box_shape("shape_island", IW, WALL_H, ID)
node('[node name="Island" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % ((IX0 + IX1) / 2, WALL_CY, (IZ0 + IZ1) / 2))
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Island"]\nmaterial_override = SubResource("mat_corridor_wall")\nmesh = SubResource("mesh_island")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Island"]\nshape = SubResource("shape_island")')

# ---------- стены ----------
_w = [0]


def wall_box(name, cx, cy, cz, sx, sy, sz, parent="."):
    _w[0] += 1
    n = _w[0]
    box_mesh("wm%d" % n, sx, sy, sz)
    box_shape("ws%d" % n, sx, sy, sz)
    node('[node name="%s" type="StaticBody3D" parent="%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % (name, parent, cx, cy, cz))
    node('[node name="MeshInstance3D" type="MeshInstance3D" parent="%s/%s"]\nmaterial_override = SubResource("mat_corridor_wall")\nmesh = SubResource("wm%d")' % (parent, name, n))
    node('[node name="CollisionShape3D" type="CollisionShape3D" parent="%s/%s"]\nshape = SubResource("ws%d")' % (parent, name, n))


def wall_x_with_gap(name, z, gap_cx, gap_w):
    """Стена вдоль X с проёмом посередине по X."""
    half = gap_w / 2
    lw = (gap_cx - half) - OX0
    if lw > 0.01:
        wall_box(name + "L", OX0 + lw / 2, WALL_CY, z, lw, WALL_H, T)
    rw = OX1 - (gap_cx + half)
    if rw > 0.01:
        wall_box(name + "R", OX1 - rw / 2, WALL_CY, z, rw, WALL_H, T)
    # перемычка над проёмом: от высоты проёма до верха стены
    top = WALL_CY + WALL_H / 2
    lintel_h = top - OPEN_H
    wall_box(name + "Lintel", gap_cx, OPEN_H + lintel_h / 2, z,
             gap_w + T * 2, lintel_h, T)


def wall_z_with_gap(name, x, gap_cz, gap_w):
    """Стена вдоль Z с проёмом посередине по Z."""
    half = gap_w / 2
    lw = (gap_cz - half) - OZ0
    if lw > 0.01:
        wall_box(name + "N", x, WALL_CY, OZ0 + lw / 2, T, WALL_H, lw)
    rw = OZ1 - (gap_cz + half)
    if rw > 0.01:
        wall_box(name + "S", x, WALL_CY, OZ1 - rw / 2, T, WALL_H, rw)
    top = WALL_CY + WALL_H / 2
    lintel_h = top - OPEN_H
    wall_box(name + "Lintel", x, OPEN_H + lintel_h / 2, gap_cz,
             T, lintel_h, gap_w + T * 2)


wall_x_with_gap("WallNorth", OZ0, 0.0, OPEN_W)
wall_x_with_gap("WallSouth", OZ1, 0.0, OPEN_W)
wall_z_with_gap("WallWest", OX0, 0.0, OPEN_W)
wall_z_with_gap("WallEast", OX1, 0.0, OPEN_W)

# ---------- площадки перед проёмами (под будущие комнаты) ----------
node('[node name="Landings" type="Node3D" parent="."]')
# уже покрыты общим полом/потолком; здесь только маркеры, куда вешать комнаты

# ================= СВЕТ =================
node('[node name="Lighting" type="Node3D" parent="."]')


def spot(nm, x, z, energy, color="0.84, 0.88, 0.94", rng=11.0, angle=70.0,
         fog=1.5, shadow=True):
    node(f'''[node name="{nm}" type="SpotLight3D" parent="Lighting"]
transform = Transform3D(1, 0, 0, 0, 0, 1, 0, -1, 0, {x}, {CEIL_Y - 0.15}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
light_volumetric_fog_energy = {fog}
shadow_enabled = {str(shadow).lower()}
shadow_bias = 0.05
spot_range = {rng}
spot_attenuation = 0.9
spot_angle = {angle}''')


def fill(nm, x, z, energy, color="0.80, 0.84, 0.90", rng=10.0):
    node(f'''[node name="{nm}" type="OmniLight3D" parent="Lighting"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {CEIL_Y - 0.8}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
light_volumetric_fog_energy = 0.0
shadow_enabled = true
omni_range = {rng}
omni_attenuation = 1.6''')


CZ_N = (OZ0 + IZ0) / 2    # -12
CZ_S = (OZ1 + IZ1) / 2    # +12
CX_W = (OX0 + IX0) / 2    # -16
CX_E = (OX1 + IX1) / 2    # +16

RING = [
    ("North", CZ_N, [CX_W, -10.0, -5.0, 0.0, 5.0, 10.0, CX_E]),
    ("South", CZ_S, [CX_W, -10.0, -5.0, 0.0, 5.0, 10.0, CX_E]),
]
# часть ламп рабочая, часть тусклая, часть мёртвая — заброшенный вид
PATTERN = [4.8, 0.0, 3.4, 1.2, 0.0, 4.2, 2.0, 0.0, 3.0, 1.4]

n = 0
for side, z, xs in RING:
    for x in xs:
        e = PATTERN[n % len(PATTERN)]
        n += 1
        spot("Ceil%s%d" % (side, n), x, z, e,
             rng=11.0, angle=72.0, fog=(1.8 if e > 3.0 else 0.6), shadow=True)

for side, x in (("West", CX_W), ("East", CX_E)):
    for z in (-6.0, 0.0, 6.0):
        e = PATTERN[n % len(PATTERN)]
        n += 1
        spot("Ceil%s%d" % (side, n), x, z, e,
             rng=11.0, angle=72.0, fog=(1.8 if e > 3.0 else 0.6), shadow=True)

# лампы прямо у проёмов — чтобы входы читались
spot("CeilOpeningN", 0.0, CZ_N, 3.6, rng=10.0, angle=74.0, fog=1.6)
spot("CeilOpeningS", 0.0, CZ_S, 3.6, rng=10.0, angle=74.0, fog=1.6)
spot("CeilOpeningW", CX_W, 0.0, 3.6, rng=10.0, angle=74.0, fog=1.6)
spot("CeilOpeningE", CX_E, 0.0, 3.6, rng=10.0, angle=74.0, fog=1.6)

fill("FillNW", -15.0, -11.0, 0.7)
fill("FillNE", 15.0, -11.0, 0.7)
fill("FillSW", -15.0, 11.0, 0.7)
fill("FillSE", 15.0, 11.0, 0.7)

# ---------- игрок ----------
node('[node name="Player" parent="." instance=ExtResource("%s")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -13.5, 0.006, -12.0)' % E_PLAYER)
node('[node name="PauseMenu" parent="." instance=ExtResource("%s")]' % E_PAUSE)

# ================= запись =================
header = '[gd_scene load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
out = header + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n\n".join(nodes) + "\n"
path = r"c:\Users\dany\Downloads\vibeprojects\game\mega_game\art\levels\office_corridor.tscn"
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(out)
print("written", path, len(out.splitlines()), "lines")
