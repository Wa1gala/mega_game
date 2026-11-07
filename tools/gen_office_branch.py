# Генератор сцены art/levels/office_branch.tscn
# Второе офисное помещение: кухня, переговорка, приёмная, санузел,
# два кабинета, опенспейс, лаунж и тупиковый проход «в никуда».

UID = {
    "player":     "uid://5sgy0k2htp7b",
    "pause":      "uid://dgaitm8l3pp6",
    "desk":       "uid://c2g4n05y1bn2u",
    "cluster":    "uid://31fpq5bpra0w",
    "confdesk":   "uid://cxeyiju6qe4lq",
    "confdesk2":  "uid://b0blx0eel5pbo",
    "confdesk2a": "uid://m6qrki0irb6s",
    "confchair":  "uid://cntv22y05m6vk",
    "whiteboard": "uid://dxynib1acdx02",
    "couchL":     "uid://djgla4xd17edu",
    "armchair":   "uid://ykhqgskglwyd",
    "armchairG":  "uid://yjjumxvmij7s",
    "coffee":     "uid://cjan0c3e3l8hd",
    "cooler":     "uid://bi0ro6e5b8kkt",
    "cabLarger":  "uid://dhmhnfud50kwh",
    "cabLarge":   "uid://ubwulshv5sk8",
    "cabSmall":   "uid://bxgwymte6cefp",
    "bookcase":   "uid://bsx4udgu2dxv3",
    "tv":         "uid://crcsrwnju51ai",
    "clock":      "uid://rf7f8d81yme2",
    "mug":        "uid://dfg2be8ofcali",
    "cabscript":  "uid://dpwthayyuctmq",
    "t_carpet":   "uid://dytk5go0rpimi",
    "t_wall":     "uid://byed7sgf3vsvj",
    "t_ceil":     "uid://3av4u04ik1gc",
}

PATHS = {
    "player": "res://player.tscn",
    "pause": "res://scenes/pause_menu.tscn",
    "desk": "res://art/levels/desks/desk_1.tscn",
    "cluster": "res://art/levels/desks/cluster_desks.tscn",
    "confdesk": "res://art/levels/office/desks/conference_desk.glb",
    "confdesk2": "res://art/levels/office/desks/conference_desk_squared.glb",
    "confdesk2a": "res://art/levels/office/desks/conference_desk_squared_alt.glb",
    "confchair": "res://art/levels/office/chairs/conference_chair.glb",
    "whiteboard": "res://art/levels/office/extras/whiteboard.glb",
    "couchL": "res://art/levels/office/couches/couch_large_blue.glb",
    "armchair": "res://art/levels/office/couches/armchair_blue.glb",
    "armchairG": "res://art/levels/office/couches/armchair_green.glb",
    "coffee": "res://art/levels/office/extras/coffee_machine.glb",
    "cooler": "res://art/levels/office/extras/water_cooler.glb",
    "cabLarger": "res://art/levels/office/file_cabinets/file_cabinet_larger.glb",
    "cabLarge": "res://art/levels/office/file_cabinets/file_cabinet_large.glb",
    "cabSmall": "res://art/levels/office/file_cabinets/file_cabinet_smallest.glb",
    "bookcase": "res://art/levels/office/book_things/book_case.glb",
    "tv": "res://art/levels/office/computers/TV.glb",
    "clock": "res://art/levels/office/extras/wall_clock.glb",
    "mug": "res://art/levels/office/extras/mug.glb",
    "cabscript": None,
    "t_carpet": "res://art/levels/office/carpet_floor/floor_3x3_carpet.jpg",
    "t_wall": "res://art/levels/office/textures/walls/wall_beige_chair_rail/wall_beige_chair_rail_albedo.png",
    "t_ceil": "res://art/levels/office/textures/ceilings/light_panel_prismatic/light_panel_prismatic_albedo.png",
}

SCENE = "res://scripts/items/cabinet_large.gd"

# ---------------- габариты ----------------
W, D = 39.0, 27.0                 # здание (x, z) — в 1.5 раза больше основной сцены
X0, X1 = -W / 2, W / 2            # -19.5 .. 19.5
Z0, Z1 = -D / 2, D / 2            # -13.5 .. 13.5
WALL_H = 5.0                      # как в office_main.tscn
WALL_CY = 1.5                     # центр стены по Y (низ -1.0, верх 4.0)
CEIL_Y = 3.9                      # потолок
T = 0.3                           # толщина стены

# тупиковый проход «в никуда» на юг
PASS_X0, PASS_X1 = -2.5, 1.0
PASS_Z1 = 18.5

ext, sub, nodes = [], [], []
_rid = [0]


def rid():
    _rid[0] += 1
    return "r%d" % _rid[0]


def ext_res(key):
    r = rid()
    if key == "cabscript":
        ext.append('[ext_resource type="Script" uid="%s" path="%s" id="%s"]'
                   % (UID[key], SCENE, r))
    elif key.startswith("t_"):
        ext.append('[ext_resource type="Texture2D" uid="%s" path="%s" id="%s"]'
                   % (UID[key], PATHS[key], r))
    else:
        ext.append('[ext_resource type="PackedScene" uid="%s" path="%s" id="%s"]'
                   % (UID[key], PATHS[key], r))
    return r


def node(t):
    nodes.append(t)


def mat_transform(x, z, rot=0, y=0.0, scale=1.0):
    """Базис поворота вокруг Y + смещение."""
    sz = scale
    if rot == 0:
        return "Transform3D(%g, 0, 0, 0, 1, 0, 0, 0, %g, %g, %g, %g)" % (sz, sz, x, y, z)
    if rot == 90:      # -90 по Y
        return "Transform3D(0, 0, %g, 0, 1, 0, %g, 0, 0, %g, %g, %g)" % (-sz, sz, x, y, z)
    if rot == 180:
        return "Transform3D(%g, 0, 0, 0, 1, 0, 0, 0, %g, %g, %g, %g)" % (-sz, -sz, x, y, z)
    if rot == 270:      # +90 по Y
        return "Transform3D(0, 0, %g, 0, 1, 0, %g, 0, 0, %g, %g, %g)" % (sz, -sz, x, y, z)
    raise ValueError(rot)


# ---------------- материалы ----------------
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

sub.append('''[sub_resource type="StandardMaterial3D" id="mat_carpet"]
cull_mode = 2
albedo_texture = ExtResource("%s")
uv1_scale = Vector3(%g, %g, 1)
texture_filter = 2''' % (ext_res("t_carpet"), W * 3.0, D * 3.0))

sub.append('''[sub_resource type="StandardMaterial3D" id="mat_ceiling"]
cull_mode = 2
albedo_texture = ExtResource("%s")
roughness = 0.85
uv1_scale = Vector3(%g, %g, 1)
texture_filter = 2''' % (ext_res("t_ceil"), W * 2.5, D * 2.5))

sub.append('''[sub_resource type="StandardMaterial3D" id="mat_wall"]
cull_mode = 2
albedo_texture = ExtResource("%s")
roughness = 0.9
uv1_scale = Vector3(23.4, 1.7, 1)
texture_filter = 2''' % ext_res("t_wall"))

# ---------------- базовая геометрия ----------------
def box_mesh(mid, sx, sy, sz):
    sub.append('[sub_resource type="BoxMesh" id="%s"]\nsize = Vector3(%g, %g, %g)' % (mid, sx, sy, sz))


def box_shape(mid, sx, sy, sz):
    sub.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = Vector3(%g, %g, %g)' % (mid, sx, sy, sz))


box_mesh("mesh_floor", W, 0.2, D)
box_shape("shape_floor", W, 0.2, D)
box_mesh("mesh_ceil", W, 0.2, D)

node('[node name="OfficeBranch" type="Node3D"]')
node('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')

node('[node name="Floor" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)')
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]\nmaterial_override = SubResource("mat_carpet")\nmesh = SubResource("mesh_floor")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]\nshape = SubResource("shape_floor")')

node('[node name="Ceiling" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %g, 0)' % CEIL_Y)
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Ceiling"]\nmaterial_override = SubResource("mat_ceiling")\nmesh = SubResource("mesh_ceil")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Ceiling"]\nshape = SubResource("shape_floor")')

# пол/потолок тупикового прохода
PW = PASS_X1 - PASS_X0
PD = PASS_Z1 - Z1
PCZ = (Z1 + PASS_Z1) / 2
box_mesh("mesh_pass_floor", PW, 0.2, PD)
box_shape("shape_pass_floor", PW, 0.2, PD)
node('[node name="PassageFloor" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, -0.1, %g)' % ((PASS_X0 + PASS_X1) / 2, PCZ))
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="PassageFloor"]\nmaterial_override = SubResource("mat_carpet")\nmesh = SubResource("mesh_pass_floor")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="PassageFloor"]\nshape = SubResource("shape_pass_floor")')
node('[node name="PassageCeiling" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % ((PASS_X0 + PASS_X1) / 2, CEIL_Y, PCZ))
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="PassageCeiling"]\nmaterial_override = SubResource("mat_ceiling")\nmesh = SubResource("mesh_pass_floor")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="PassageCeiling"]\nshape = SubResource("shape_pass_floor")')


_wall_n = [0]


def wall(name, x1, z1, x2, z2):
    """Стена между двумя точками (только по осям)."""
    _wall_n[0] += 1
    n = _wall_n[0]
    if abs(z2 - z1) < 1e-6:            # вдоль X
        sx, sz = abs(x2 - x1), T
        cx, cz = (x1 + x2) / 2, z1
    else:                               # вдоль Z
        sx, sz = T, abs(z2 - z1)
        cx, cz = x1, (z1 + z2) / 2
    box_mesh("wm%d" % n, sx, WALL_H, sz)
    box_shape("ws%d" % n, sx, WALL_H, sz)
    node('[node name="%s" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % (name, cx, WALL_CY, cz))
    node('[node name="MeshInstance3D" type="MeshInstance3D" parent="%s"]\nmaterial_override = SubResource("mat_wall")\nmesh = SubResource("wm%d")' % (name, n))
    node('[node name="CollisionShape3D" type="CollisionShape3D" parent="%s"]\nshape = SubResource("ws%d")' % (name, n))


# ---------- периметр ----------
wall("WallNorth", X0, Z0, X1, Z0)
wall("WallEast", X1, Z0, X1, Z1)
wall("WallWest", X0, Z0, X0, Z1)
# юг с проёмом под тупиковый проход
wall("WallSouthW", X0, Z1, PASS_X0, Z1)
wall("WallSouthE", PASS_X1, Z1, X1, Z1)

# ---------- проход «в никуда» ----------
wall("PassageW", PASS_X0, Z1, PASS_X0, PASS_Z1)
wall("PassageE", PASS_X1, Z1, PASS_X1, PASS_Z1)
wall("PassageEnd", PASS_X0, PASS_Z1, PASS_X1, PASS_Z1)   # заглушка, дальше ничего

# ---------- кухня/кофе-поинт: x[-19.5,-6], z[-13.5,-5] ----------
wall("KitchenE", -6, Z0, -6, -5)
wall("KitchenS1", X0, -5, -14.5, -5)
wall("KitchenS2", -9.5, -5, -6, -5)      # проём -14.5..-9.5

# ---------- переговорка: x[4,19.5], z[-13.5,-5] ----------
wall("MeetingW", 4, Z0, 4, -5)
wall("MeetingS1", 4, -5, 7.6, -5)
wall("MeetingS2", 12.0, -5, X1, -5)      # проём 7.6..12.0

# ---------- санузел: x[13.5,19.5], z[-5,1.5] ----------
wall("RestW", 13.5, -5, 13.5, 1.5)
wall("RestS1", 13.5, 1.5, 15.5, 1.5)
wall("RestS2", 17.5, 1.5, X1, 1.5)

# ---------- кабинеты слева: x[-19.5,-10], z[-5,13.5] ----------
wall("OfficesE1", -10, -5, -10, 1.0)
wall("OfficesE2", -10, 4.5, -10, 13.5)   # проём 1.0..4.5
wall("OfficesMid1", X0, 4.0, -15.5, 4.0)
wall("OfficesMid2", -13.0, 4.0, -10, 4.0)  # проём -15.5..-13.0

# ---------- лаунж справа: x[8,19.5], z[1.5,13.5] ----------
wall("LoungeW1", 8, 1.5, 8, 6.0)
wall("LoungeW2", 8, 9.5, 8, 13.5)        # проём 6.0..9.5
wall("LoungeN", 8, 1.5, 13.5, 1.5)

# ================= СВЕТ =================
node('[node name="Lighting" type="Node3D" parent="."]')


def spot(nm, x, z, energy, color="0.82, 0.87, 0.94", rng=13.0, angle=72.0,
         fog=1.4, shadow=True, y=None):
    yy = CEIL_Y - 0.15 if y is None else y
    node(f'''[node name="{nm}" type="SpotLight3D" parent="Lighting"]
transform = Transform3D(1, 0, 0, 0, 0, 1, 0, -1, 0, {x}, {yy}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
light_volumetric_fog_energy = {fog}
shadow_enabled = {str(shadow).lower()}
shadow_bias = 0.05
spot_range = {rng}
spot_attenuation = 0.9
spot_angle = {angle}''')


def fill(nm, x, z, energy, color="0.78, 0.83, 0.9", rng=11.0, shadow=True, y=None):
    yy = CEIL_Y - 0.8 if y is None else y
    node(f'''[node name="{nm}" type="OmniLight3D" parent="Lighting"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {yy}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
light_volumetric_fog_energy = 0.0
shadow_enabled = {str(shadow).lower()}
omni_range = {rng}
omni_attenuation = 1.6''')


# опенспейс — часть ламп рабочая, часть тлеет, часть мёртвая
OPEN = [
    (-7.0, -1.0, 5.4, "0.80, 0.86, 0.94", 2.4),
    (-1.5, -1.0, 1.3, "0.76, 0.80, 0.84", 0.6),
    ( 4.0, -1.0, 0.0, "0.70, 0.72, 0.75", 0.0),
    (-7.0,  6.5, 4.6, "0.82, 0.88, 0.96", 2.1),
    (-1.5,  6.5, 0.0, "0.70, 0.72, 0.75", 0.0),
    ( 4.0,  6.5, 3.8, "0.90, 0.84, 0.70", 1.6),
    (-7.0, 12.0, 2.1, "0.80, 0.82, 0.78", 0.9),
    (-1.5, 12.0, 4.4, "0.82, 0.87, 0.92", 1.9),
]
for i, (x, z, e, c, f) in enumerate(OPEN, start=1):
    spot("CeilOpen%d" % i, x, z, e, color=c, rng=13.0, angle=74.0, fog=f)

# кухня — один живой светильник + один мёртвый
spot("CeilKitchen1", -12.5, -11.0, 4.8, color="0.88, 0.86, 0.78", rng=12.0, angle=76.0, fog=2.0)
spot("CeilKitchen2", -12.5, -7.0, 0.0, shadow=False, fog=0.0)

# переговорка
spot("CeilMeeting1", 8.5, -11.0, 5.0, color="0.86, 0.90, 0.96", rng=12.0, angle=72.0, fog=2.2)
spot("CeilMeeting2", 15.0, -11.0, 2.4, color="0.84, 0.88, 0.94", rng=11.0, angle=78.0, fog=1.2)
spot("CeilMeeting3", 11.5, -7.0, 0.9, color="0.80, 0.82, 0.86", rng=9.0, angle=80.0, fog=0.4)

# приёмная у входа
spot("CeilEntry", 0.0, -11.0, 3.2, color="0.84, 0.88, 0.92", rng=11.0, angle=76.0, fog=1.5)

# санузел
spot("CeilRest", 16.5, -1.8, 1.8, color="0.88, 0.94, 0.96", rng=7.0, angle=78.0, fog=0.8)

# кабинеты
spot("CeilOfficeA", -14.5, -1.0, 3.6, color="0.84, 0.88, 0.92", rng=11.0, angle=76.0, fog=1.6)
spot("CeilOfficeB", -14.5, 8.5, 3.0, color="0.86, 0.88, 0.90", rng=11.0, angle=78.0, fog=1.3)

# лаунж — тёплый
spot("CeilLounge1", 11.0, 5.0, 3.4, color="1, 0.84, 0.62", rng=12.0, angle=74.0, fog=2.2)
spot("CeilLounge2", 15.5, 10.5, 2.8, color="1, 0.80, 0.55", rng=11.0, angle=74.0, fog=2.0)

# тупиковый проход — одна тусклая лампа
spot("CeilPassage", (PASS_X0 + PASS_X1) / 2, PCZ, 1.6, color="0.82, 0.86, 0.90", rng=8.0, angle=76.0, fog=1.0)

# заливки (с тенями, как в основной сцене)
fill("FillOpenW", -8.0, 3.0, 0.9)
fill("FillOpenE", 2.0, 8.0, 0.8)
fill("FillKitchen", -13.0, -9.0, 0.9, color="0.88, 0.86, 0.80")
fill("FillMeeting", 12.0, -10.0, 0.8)
fill("FillEntry", 0.0, -10.0, 0.7)
fill("FillLounge", 13.0, 8.0, 0.8, color="1, 0.86, 0.70")
fill("FillOffices", -15.0, 4.0, 0.7)
fill("PassageFill", (PASS_X0 + PASS_X1) / 2, PCZ, 0.4, rng=6.0)

# ================= МЕБЕЛЬ =================
E_DESK = ext_res("desk")
E_CLUSTER = ext_res("cluster")
E_CONFDESK = ext_res("confdesk")
E_CONFDESK2 = ext_res("confdesk2")
E_CONFDESK2A = ext_res("confdesk2a")
E_CONFCHAIR = ext_res("confchair")
E_WHITEBOARD = ext_res("whiteboard")
E_COUCHL = ext_res("couchL")
E_ARMCHAIR = ext_res("armchair")
E_ARMCHAIRG = ext_res("armchairG")
E_COFFEE = ext_res("coffee")
E_COOLER = ext_res("cooler")
E_CABLARGER = ext_res("cabLarger")
E_CABLARGE = ext_res("cabLarge")
E_CABSMALL = ext_res("cabSmall")
E_BOOKCASE = ext_res("bookcase")
E_TV = ext_res("tv")
E_CLOCK = ext_res("clock")
E_MUG = ext_res("mug")
E_CABSCRIPT = ext_res("cabscript")


def prop(nm, res, x, z, rot=0, y=0.0, parent="."):
    node('[node name="%s" parent="%s" instance=ExtResource("%s")]\ntransform = %s'
         % (nm, parent, res, mat_transform(x, z, rot, y)))


def solid(nm, res, x, z, shape_id, rot=0, cy=0.5, parent="."):
    """Статичное тело: модель + коробка-коллизия."""
    node('[node name="%s" type="StaticBody3D" parent="%s"]\ntransform = %s'
         % (nm, parent, mat_transform(x, z, rot)))
    node('[node name="Model" parent="%s/%s" instance=ExtResource("%s")]' % (parent, nm, res))
    node('[node name="CollisionShape3D" type="CollisionShape3D" parent="%s/%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %g, 0)\nshape = SubResource("%s")'
         % (parent, nm, cy, shape_id))


# ---------- зоны ----------
node('[node name="Kitchen" type="Node3D" parent="."]')
node('[node name="MeetingRoom" type="Node3D" parent="."]')
node('[node name="Entry" type="Node3D" parent="."]')
node('[node name="Restroom" type="Node3D" parent="."]')
node('[node name="OfficeA" type="Node3D" parent="."]')
node('[node name="OfficeB" type="Node3D" parent="."]')
node('[node name="OpenSpace" type="Node3D" parent="."]')
node('[node name="Lounge" type="Node3D" parent="."]')
node('[node name="Passage" type="Node3D" parent="."]')

# коллизии мебели
box_shape("bs_cabLarger", 1.44, 1.05, 0.70)
box_shape("bs_cabLarge", 1.44, 0.71, 0.70)
box_shape("bs_cabSmall", 0.49, 0.71, 0.53)
box_shape("bs_bookcase", 2.00, 2.50, 0.49)
box_shape("bs_couchL", 3.16, 1.19, 1.39)
box_shape("bs_armchair", 1.40, 1.19, 1.36)
box_shape("bs_coffee", 1.25, 2.12, 1.28)
box_shape("bs_cooler", 0.38, 1.40, 0.45)
box_shape("bs_whiteboard", 2.15, 2.57, 0.86)
box_shape("bs_tv", 0.90, 0.95, 0.75)
box_shape("bs_confdesk", 4.97, 0.88, 2.58)
box_shape("bs_confdesk2", 4.19, 0.88, 2.03)

# ---------- кухня ----------
# линия тумб у северной стены
for i, cx in enumerate([-18.2, -16.6, -15.0, -13.4, -11.8, -10.2, -8.6], start=1):
    solid("KitchenCounter%d" % i, E_CABLARGER, cx, -12.8, "bs_cabLarger", cy=0.525, parent="Kitchen")
prop("CoffeeMachine", E_COFFEE, -16.6, -12.8, 0, 1.05, parent="Kitchen")
prop("KettleStand", E_CABSMALL, -13.4, -12.8, 0, 1.05, parent="Kitchen")
prop("KitchenMug1", E_MUG, -15.0, -12.55, 0, 1.06, parent="Kitchen")
prop("KitchenMug2", E_MUG, -12.0, -12.6, 0, 1.06, parent="Kitchen")
prop("KitchenCooler", E_COOLER, -6.9, -6.2, 270, 0, parent="Kitchen")
# остров
solid("KitchenIsland", E_CONFDESK2, -12.6, -8.4, "bs_confdesk2", cy=0.44, parent="Kitchen")
for i, (cx, cz, r) in enumerate([(-15.2, -8.4, 90), (-10.0, -8.4, 270),
                                 (-14.0, -10.2, 180), (-14.0, -6.6, 0)], start=1):
    prop("KitchenChair%d" % i, E_CONFCHAIR, cx, cz, r, 0, parent="Kitchen")

# ---------- переговорка ----------
solid("MeetingDesk", E_CONFDESK, 11.5, -10.0, "bs_confdesk", cy=0.44, parent="MeetingRoom")
for i, (cx, cz, r) in enumerate([
    (9.0, -10.0, 90), (14.0, -10.0, 270),
    (10.0, -12.0, 180), (13.0, -12.0, 180),
    (10.0, -8.0, 0), (13.0, -8.0, 0),
    (11.5, -12.2, 180), (11.5, -7.8, 0),
], start=1):
    prop("MeetingChair%d" % i, E_CONFCHAIR, cx, cz, r, 0, parent="MeetingRoom")
solid("MeetingWhiteboard", E_WHITEBOARD, 19.2, -10.0, "bs_whiteboard", rot=270, cy=0.909, parent="MeetingRoom")

# ---------- приёмная ----------
solid("EntryCabinet", E_CABLARGE, 3.0, -12.9, "bs_cabLarge", cy=0.353, parent="Entry")
prop("EntryCabinet2", E_CABLARGE, 1.4, -12.9, 0, 0, parent="Entry")
prop("EntryClock", E_CLOCK, 0.0, -13.1, 0, 2.4, parent="Entry")
solid("EntryBookcase", E_BOOKCASE, -5.4, -13.0, "bs_bookcase", cy=1.25, parent="Entry")

# ---------- санузел (сантехники в ассетах нет — только мебель и кулер) ----------
solid("RestCabinet", E_CABSMALL, 19.0, 0.6, "bs_cabSmall", cy=0.353, parent="Restroom")
prop("RestCooler", E_COOLER, 14.2, 1.0, 270, 0, parent="Restroom")

# ---------- кабинеты ----------
for room, zc, rz in (("OfficeA", -0.5, 0), ("OfficeB", 8.8, 180)):
    parent = room
    prop(room + "Desk1", E_DESK, -15.2, zc - 0.6, rz, 0, parent=parent)
    prop(room + "Desk2", E_DESK, -12.2, zc - 0.6, rz, 0, parent=parent)
    solid(room + "Bookcase", E_BOOKCASE, -19.0, zc + 2.4, "bs_bookcase", rot=90, cy=1.25, parent=parent)
    solid(room + "Cabinet", E_CABLARGE, -10.6, zc + 3.0, "bs_cabLarge", cy=0.353, parent=parent)

# ---------- опенспейс: кластеры ----------
for i, (cx, cz, r) in enumerate([(-6.0, 0.6, 0), (1.2, 0.6, 0),
                                 (-6.0, 8.3, 0), (1.2, 8.3, 0)], start=1):
    prop("Cluster%d" % i, E_CLUSTER, cx, cz, r, 0, parent="OpenSpace")

solid("OpenCabinet", E_CABLARGE, -9.2, 12.6, "bs_cabLarge", cy=0.353, parent="OpenSpace")
prop("OpenCabinet2", E_CABLARGE, -7.6, 12.6, 0, 0, parent="OpenSpace")
solid("OpenBookcase", E_BOOKCASE, 7.2, 3.0, "bs_bookcase", rot=270, cy=1.25, parent="OpenSpace")

# ---------- лаунж ----------
solid("LoungeCouch", E_COUCHL, 12.0, 12.6, "bs_couchL", cy=0.596, parent="Lounge")
prop("LoungeArmchair1", E_ARMCHAIR, 15.8, 9.0, 270, 0, parent="Lounge")
prop("LoungeArmchair2", E_ARMCHAIRG, 9.2, 9.6, 90, 0, parent="Lounge")
solid("LoungeTable", E_CONFDESK2A, 12.4, 9.0, "bs_confdesk2", cy=0.44, parent="Lounge")
solid("LoungeTV", E_TV, 19.2, 5.4, "bs_tv", rot=270, cy=1.05, parent="Lounge")
solid("LoungeCoffee", E_COFFEE, 9.0, 2.4, "bs_coffee", cy=1.062, parent="Lounge")
prop("LoungeCooler", E_COOLER, 10.6, 2.4, 180, 0, parent="Lounge")

# ---------- шкаф-контейнер в проходе ----------
node('[node name="PassageCabinet" type="StaticBody3D" parent="Passage"]\ntransform = %s\nscript = ExtResource("%s")'
     % (mat_transform((PASS_X0 + PASS_X1) / 2, PASS_Z1 - 0.6, 180), E_CABSCRIPT))
node('[node name="Model" parent="Passage/PassageCabinet" instance=ExtResource("%s")]' % E_CABLARGE)
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Passage/PassageCabinet"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.353, 0.091)\nshape = SubResource("bs_cabLarge")')

# ---------- игрок ----------
E_PLAYER = ext_res("player")
E_PAUSE = ext_res("pause")
node('[node name="Player" parent="." instance=ExtResource("%s")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.006, -6.0)' % E_PLAYER)
node('[node name="PauseMenu" parent="." instance=ExtResource("%s")]' % E_PAUSE)

# ================= запись =================
header = '[gd_scene load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
out = header + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n\n".join(nodes) + "\n"

path = r"c:\Users\dany\Downloads\vibeprojects\game\mega_game\art\levels\office_branch.tscn"
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(out)
print("written", path, len(out.splitlines()), "lines")
