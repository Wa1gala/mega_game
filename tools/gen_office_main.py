import math

UID_PLAYER = "uid://5sgy0k2htp7b"
UID_PAUSE = "uid://dgaitm8l3pp6"
UID_DESK = "uid://c2g4n05y1bn2u"          # desk_1.tscn — рабочее место целиком
UID_CLUSTER = "uid://31fpq5bpra0w"        # cluster_desks.tscn — кластер из 4 столов
UID_CONFDESK = "uid://cxeyiju6qe4lq"
UID_CONFCHAIR = "uid://cntv22y05m6vk"
UID_WHITEBOARD = "uid://dxynib1acdx02"
UID_COUCH = "uid://w3tavcew48by"
UID_ARMCHAIR = "uid://ykhqgskglwyd"
UID_ARMCHAIR_G = "uid://yjjumxvmij7s"
UID_COFFEE = "uid://cjan0c3e3l8hd"
UID_COOLER = "uid://bi0ro6e5b8kkt"
UID_CABINET = "uid://ubwulshv5sk8"
UID_CLOCK = "uid://rf7f8d81yme2"
UID_TV = "uid://crcsrwnju51ai"
UID_SCRIPT_CAB = "uid://dpwthayyuctmq"
UID_CARPET = "uid://dytk5go0rpimi"
UID_WALL = "uid://byed7sgf3vsvj"
UID_CEIL = "uid://3av4u04ik1gc"

# --- габариты здания ---
W, D, H = 26.0, 18.0, 3.0      # ширина (x), глубина (z), высота
CX = 0.0                        # центр пола по x
CZ = 0.0
X0, X1 = CX - W / 2, CX + W / 2   # -13 .. 13
Z0, Z1 = CZ - D / 2, CZ + D / 2   # -9 .. 9

INNER_X = 5.0                   # стена между опенспейсом и правыми зонами

out = []
ext = []
sub = []
nodes = []


def ext_res(typ, uid, path, rid):
    ext.append(f'[ext_resource type="{typ}" uid="{uid}" path="{path}" id="{rid}"]')
    return rid


def sub_res(text):
    sub.append(text)


def node(text):
    nodes.append(text)


ext_res("PackedScene", UID_PLAYER, "res://player.tscn", "1_player")
ext_res("PackedScene", UID_PAUSE, "res://scenes/pause_menu.tscn", "2_pause")
ext_res("PackedScene", UID_DESK, "res://art/levels/desks/desk_1.tscn", "3_desk")
ext_res("PackedScene", UID_CLUSTER, "res://art/levels/desks/cluster_desks.tscn", "4_cluster")
ext_res("PackedScene", UID_CONFDESK, "res://art/levels/office/desks/conference_desk.glb", "6_confdesk")
ext_res("PackedScene", UID_CONFCHAIR, "res://art/levels/office/chairs/conference_chair.glb", "7_confchair")
ext_res("PackedScene", UID_WHITEBOARD, "res://art/levels/office/extras/whiteboard.glb", "8_whiteboard")
ext_res("PackedScene", UID_COUCH, "res://art/levels/office/couches/couch_blue.glb", "9_couch")
ext_res("PackedScene", UID_ARMCHAIR, "res://art/levels/office/couches/armchair_blue.glb", "10_armchair")
ext_res("PackedScene", UID_ARMCHAIR_G, "res://art/levels/office/couches/armchair_green.glb", "11_armchair_g")
ext_res("PackedScene", UID_COFFEE, "res://art/levels/office/extras/coffee_machine.glb", "12_coffee")
ext_res("PackedScene", UID_COOLER, "res://art/levels/office/extras/water_cooler.glb", "13_cooler")
ext_res("PackedScene", UID_CABINET, "res://art/levels/office/file_cabinets/file_cabinet_large.glb", "14_cabinet")
ext_res("PackedScene", UID_CLOCK, "res://art/levels/office/extras/wall_clock.glb", "15_clock")
ext_res("PackedScene", UID_TV, "res://art/levels/office/computers/TV.glb", "16_tv")
ext_res("Script", UID_SCRIPT_CAB, "res://scripts/items/cabinet_large.gd", "17_cabscript")
ext_res("Texture2D", UID_CARPET, "res://art/levels/office/carpet_floor/floor_3x3_carpet.jpg", "18_carpet")
ext_res("Texture2D", UID_WALL, "res://art/levels/office/textures/walls/wall_beige_chair_rail/wall_beige_chair_rail_albedo.png", "19_wall")
ext_res("Texture2D", UID_CEIL, "res://art/levels/office/textures/ceilings/light_panel_prismatic/light_panel_prismatic_albedo.png", "20_ceil")

# ---------- материалы ----------
sub_res('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.012, 0.014, 0.016, 1)
ambient_light_source = 2
ambient_light_color = Color(0.05, 0.06, 0.07, 1)
ambient_light_energy = 0.18
tonemap_mode = 3
tonemap_exposure = 0.9
glow_enabled = true
glow_intensity = 0.5
glow_bloom = 0.2
glow_hdr_threshold = 0.7
ssao_enabled = true
ssao_intensity = 1.8
ssao_radius = 1.4
ssao_power = 2.0
volumetric_fog_enabled = true
volumetric_fog_density = 0.09
volumetric_fog_albedo = Color(0.62, 0.66, 0.60, 1)
volumetric_fog_emission = Color(0.04, 0.05, 0.04, 1)
volumetric_fog_emission_energy = 0.15
volumetric_fog_gi_inject = 0.0
volumetric_fog_anisotropy = 0.45
volumetric_fog_length = 24.0
volumetric_fog_detail_spread = 2.0
volumetric_fog_ambient_inject = 0.0''')

sub_res('''[sub_resource type="StandardMaterial3D" id="mat_carpet"]
cull_mode = 2
albedo_texture = ExtResource("18_carpet")
uv1_scale = Vector3(%g, %g, 1)
texture_filter = 2''' % (W * 3.0, D * 3.0))

sub_res('''[sub_resource type="StandardMaterial3D" id="mat_ceiling"]
cull_mode = 2
albedo_texture = ExtResource("20_ceil")
roughness = 0.85
metallic = 0.0
uv1_scale = Vector3(%g, %g, 1)
texture_filter = 2''' % (W * 2.5, D * 2.5))

sub_res('''[sub_resource type="StandardMaterial3D" id="mat_wall"]
cull_mode = 2
albedo_texture = ExtResource("19_wall")
roughness = 0.9
uv1_scale = Vector3(%g, 1.7, 1)
texture_filter = 2''' % (W * 0.9))

# ---------- меши/шейпы ----------
def box_mesh(mid, size):
    sub_res('[sub_resource type="BoxMesh" id="%s"]\nsize = Vector3(%g, %g, %g)' % (mid, *size))

def box_shape(mid, size):
    sub_res('[sub_resource type="BoxShape3D" id="%s"]\nsize = Vector3(%g, %g, %g)' % (mid, *size))

box_mesh("mesh_floor", (W, 0.2, D))
box_shape("shape_floor", (W, 0.2, D))
box_mesh("mesh_ceil", (W, 0.2, D))

box_mesh("mesh_wall_ns", (W, H, 0.3))
box_shape("shape_wall_ns", (W, H, 0.3))
box_mesh("mesh_wall_ew", (0.3, H, D))
box_shape("shape_wall_ew", (0.3, H, D))

SEG = 6.0
box_mesh("mesh_wall_inner", (0.3, H, SEG))
box_shape("shape_wall_inner", (0.3, H, SEG))

box_shape("bs_confdesk", (4.97, 0.88, 2.58))
box_shape("bs_couch", (2.24, 1.19, 1.36))
box_shape("bs_armchair", (1.4, 1.19, 1.36))
box_shape("bs_coffee", (1.25, 2.12, 1.28))
box_shape("bs_cooler", (0.38, 1.4, 0.45))
box_shape("bs_cabinet", (1.44, 0.71, 0.7))
box_shape("bs_whiteboard", (2.15, 2.59, 0.92))

# фоновая слабая направленная подсветка (мягкий fill, без резких теней)
node('[node name="Office" type="Node3D"]')
node('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')

node('[node name="Floor" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, -0.1, %g)' % (CX, CZ))
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]\nmaterial_override = SubResource("mat_carpet")\nmesh = SubResource("mesh_floor")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]\nshape = SubResource("shape_floor")')

node('[node name="Ceiling" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % (CX, H - 0.1, CZ))
node('[node name="MeshInstance3D" type="MeshInstance3D" parent="Ceiling"]\nmaterial_override = SubResource("mat_ceiling")\nmesh = SubResource("mesh_ceil")')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="Ceiling"]\nshape = SubResource("shape_floor")')

# ---------- стены периметра ----------
def wall(nm, pos, mesh, shape):
    node('[node name="%s" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % (nm, *pos))
    node('[node name="MeshInstance3D" type="MeshInstance3D" parent="%s"]\nmaterial_override = SubResource("mat_wall")\nmesh = SubResource("%s")' % (nm, mesh))
    node('[node name="CollisionShape3D" type="CollisionShape3D" parent="%s"]\nshape = SubResource("%s")' % (nm, shape))

wall("WallNorth", (CX, H / 2, Z0), "mesh_wall_ns", "shape_wall_ns")
wall("WallSouth", (CX, H / 2, Z1), "mesh_wall_ns", "shape_wall_ns")
wall("WallWest", (X0, H / 2, CZ), "mesh_wall_ew", "shape_wall_ew")
wall("WallEast", (X1, H / 2, CZ), "mesh_wall_ew", "shape_wall_ew")

# внутренняя стена x=5 с проходом посередине (|z| < 3)
wall("WallInnerN", (INNER_X, H / 2, -6.0), "mesh_wall_inner", "shape_wall_inner")
wall("WallInnerS", (INNER_X, H / 2, 6.0), "mesh_wall_inner", "shape_wall_inner")
# перегородка между переговоркой и лаунжем (z=0), с проходом у x=5
sub_res('[sub_resource type="BoxMesh" id="mesh_wall_mid"]\nsize = Vector3(5.0, %g, 0.3)' % H)
sub_res('[sub_resource type="BoxShape3D" id="shape_wall_mid"]\nsize = Vector3(5.0, %g, 0.3)' % H)
wall("WallMid", (10.5, H / 2, 0.0), "mesh_wall_mid", "shape_wall_mid")

# ---------- свет ----------
node('[node name="Lighting" type="Node3D" parent="."]')

def spot(nm, x, z, energy, color="0.95, 0.96, 1", rng=9.0, angle=62.0,
         shadow=True, fog_energy=1.0):
    """Потолочный светильник, направленный вниз.
    fog_energy > 0 делает луч видимым в объёмном тумане (косые лучи)."""
    node(f'''[node name="{nm}" type="SpotLight3D" parent="Lighting"]
transform = Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, {x}, {H - 0.25}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
light_volumetric_fog_energy = {fog_energy}
shadow_enabled = {str(shadow).lower()}
shadow_bias = 0.05
spot_range = {rng}
spot_angle = {angle}
spot_angle_attenuation = 1.0
spot_attenuation = 0.9''')


# Без теней и с широким углом — только чтобы под лампами не было
# абсолютной черноты. Тише, чем споты, иначе убивает контраст.
def fill(nm, x, z, energy, color="0.78, 0.83, 0.90", rng=10.0):
    node(f'''[node name="{nm}" type="OmniLight3D" parent="Lighting"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {H - 0.8}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
light_volumetric_fog_energy = 0.0
shadow_enabled = false
omni_range = {rng}
omni_attenuation = 1.6''')

# Опенспейс: сетка потолочных панелей 3x3.
# Часть ламп работает, часть еле тлеет, часть мёртвая — заброшка.
# Тени включены у всех работающих: пятна света на полу и стенах.
# (энергия, цвет, видимость луча в тумане)
OPEN_LAMPS = [
    (6.0, "0.80, 0.86, 0.94", 2.4),   # рабочая, холодная
    (1.6, "0.76, 0.80, 0.84", 0.7),   # тусклая
    (0.0, "0.70, 0.72, 0.75", 0.0),   # мёртвая
    (3.4, "0.90, 0.82, 0.66", 1.5),   # живая, но тёплая и грязная
    (5.6, "0.82, 0.88, 0.96", 2.2),   # рабочая
    (1.1, "0.78, 0.81, 0.85", 0.5),   # почти сдохла
    (0.0, "0.70, 0.72, 0.75", 0.0),   # мёртвая
    (4.8, "0.84, 0.89, 0.94", 1.9),   # рабочая
    (2.2, "0.82, 0.84, 0.78", 0.9),   # тусклая
]
LX = [-10.0, -5.0, 0.2]
LZ = [-6.0, 0.0, 6.0]
n = 0
for li, z in enumerate(LZ):
    for xi, x in enumerate(LX):
        energy, col, fog = OPEN_LAMPS[n]
        n += 1
        spot(f"CeilOpen{n}", x, z, energy, color=col,
             rng=13.0, angle=68.0, shadow=True, fog_energy=fog)

# переговорка: одна рабочая, одна мёртвая
spot("CeilConf1", 9.0, -6.0, 5.2, color="0.86, 0.90, 0.96", rng=12.0, angle=66.0,
     shadow=True, fog_energy=2.0)
spot("CeilConf2", 9.0, -2.5, 0.0, shadow=False, fog_energy=0.0)

# лаунж — тёплый, полумёртвый, один явный луч
spot("CeilLounge1", 7.6, 3.0, 4.0, color="1, 0.84, 0.62", rng=12.0, angle=64.0,
     shadow=True, fog_energy=2.2)
spot("CeilLounge2", 11.0, 6.5, 4.8, color="1, 0.80, 0.55", rng=12.0, angle=62.0,
     shadow=True, fog_energy=2.6)
spot("CeilLounge3", 7.6, 8.0, 1.0, color="1, 0.82, 0.60", rng=9.0, angle=66.0,
     shadow=True, fog_energy=0.5)

# Слабый рассеянный подсвет в тёмных зонах (без теней, но очень тихий).
fill("FillOpenW", -8.0, -4.0, 0.9)
fill("FillOpenE", 0.0, -4.0, 0.9)
fill("FillOpenS", -4.0, 6.0, 0.8, color="0.82, 0.84, 0.86")
fill("FillConf", 9.0, -4.5, 0.8)
fill("FillLounge", 9.5, 5.0, 0.7, color="1, 0.86, 0.70")

# ---------- кубиклы: 5 кластеров по 4 стола (cluster_desks.tscn) ----------

def cluster(idx, cx, cz, rot=0):
    """Инстанс префаба cluster_desks.tscn (4 стола + свои перегородки)."""
    if rot == 0:
        t = f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx}, 0, {cz})"
    else:
        t = f"Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, {cx}, 0, {cz})"
    node(f'[node name="Cluster{idx}" parent="." instance=ExtResource("4_cluster")]\ntransform = {t}')

CLUSTERS = [
    (-9.5, -5.0, 0), (-4.0, -5.0, 0), (1.5, -5.0, 0),
    (-6.7, 5.2, 180), (-1.3, 5.2, 180),
]
for i, (x, z, r) in enumerate(CLUSTERS, start=1):
    cluster(i, x, z, r)

# ---------- переговорка ----------
node('[node name="ConferenceRoom" type="Node3D" parent="."]')
node('[node name="ConferenceDesk" type="StaticBody3D" parent="ConferenceRoom"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 9.0, 0, -4.5)')
node('[node name="Model" parent="ConferenceRoom/ConferenceDesk" instance=ExtResource("6_confdesk")]')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="ConferenceRoom/ConferenceDesk"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.44, 0)\nshape = SubResource("bs_confdesk")')

for i, (cx, cz, rot) in enumerate([
    (6.6, -4.5, 90), (11.4, -4.5, 270),
    (8.0, -6.6, 180), (10.0, -6.6, 180),
    (8.0, -2.4, 0), (10.0, -2.4, 0),
], start=1):
    if rot == 0:
        t = f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx}, 0, {cz})"
    elif rot == 90:
        t = f"Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, {cx}, 0, {cz})"
    elif rot == 270:
        t = f"Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, {cx}, 0, {cz})"
    else:
        t = f"Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, {cx}, 0, {cz})"
    node(f'[node name="ConfChair{i}" parent="ConferenceRoom" instance=ExtResource("7_confchair")]\ntransform = {t}')

node('[node name="Whiteboard" type="StaticBody3D" parent="ConferenceRoom"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12.35, 0, -4.5)')
node('[node name="Model" parent="ConferenceRoom/Whiteboard" instance=ExtResource("8_whiteboard")]\ntransform = Transform3D(0.705, 0, 0, 0, 0.705, 0, 0, 0, 0.705, 0, 0, 0)')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="ConferenceRoom/Whiteboard"]\ntransform = Transform3D(0.705, 0, 0, 0, 0.705, 0, 0, 0, 0.705, 0, 0.909, -0.022)\nshape = SubResource("bs_whiteboard")')

# ---------- лаунж ----------
node('[node name="LoungeRoom" type="Node3D" parent="."]')

node('[node name="Couch" type="StaticBody3D" parent="LoungeRoom"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.2, 0, 6.6)')
node('[node name="Model" parent="LoungeRoom/Couch" instance=ExtResource("9_couch")]')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="LoungeRoom/Couch"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.596, 0)\nshape = SubResource("bs_couch")')

node('[node name="Armchair1" type="StaticBody3D" parent="LoungeRoom"]\ntransform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 10.6, 0, 6.9)')
node('[node name="Model" parent="LoungeRoom/Armchair1" instance=ExtResource("10_armchair")]')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="LoungeRoom/Armchair1"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.596, 0)\nshape = SubResource("bs_armchair")')

node('[node name="Armchair2" type="StaticBody3D" parent="LoungeRoom"]\ntransform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 7.2, 0, 3.2)')
node('[node name="Model" parent="LoungeRoom/Armchair2" instance=ExtResource("11_armchair_g")]')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="LoungeRoom/Armchair2"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.596, 0)\nshape = SubResource("bs_armchair")')

node('[node name="TV" type="StaticBody3D" parent="LoungeRoom"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12.3, 1.2, 5.0)')
node('[node name="Model" parent="LoungeRoom/TV" instance=ExtResource("16_tv")]')

node('[node name="CoffeeMachine" type="StaticBody3D" parent="LoungeRoom"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12.2, 0, 1.6)')
node('[node name="Model" parent="LoungeRoom/CoffeeMachine" instance=ExtResource("12_coffee")]\ntransform = Transform3D(0.03, 0, -0.9996, 0, 1, 0, 0.9996, 0, 0.03, 0, 0, 0)')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="LoungeRoom/CoffeeMachine"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.062, 0)\nshape = SubResource("bs_coffee")')

node('[node name="WaterCooler" type="StaticBody3D" parent="LoungeRoom"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12.4, 0, 3.4)')
node('[node name="Model" parent="LoungeRoom/WaterCooler" instance=ExtResource("13_cooler")]\ntransform = Transform3D(-0.09, 0, -0.996, 0, 1, 0, 0.996, 0, -0.09, 0, 0, 0)')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="LoungeRoom/WaterCooler"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.698, 0)\nshape = SubResource("bs_cooler")')

# ---------- шкаф (интерактивный) ----------
node('[node name="FileCabinet" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12.3, 0, -8.3)\nscript = ExtResource("17_cabscript")')
node('[node name="Model" parent="FileCabinet" instance=ExtResource("14_cabinet")]')
node('[node name="CollisionShape3D" type="CollisionShape3D" parent="FileCabinet"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.353, 0.091)\nshape = SubResource("bs_cabinet")')

node('[node name="WallClock" parent="." instance=ExtResource("15_clock")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, 2.1, -8.8)')

node('[node name="Player" parent="." instance=ExtResource("1_player")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, 0.006, 0.0)')
node('[node name="PauseMenu" parent="." instance=ExtResource("2_pause")]')

header = '[gd_scene load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
body = header + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n\n".join(nodes) + "\n"

path = r"c:\Users\dany\Downloads\vibeprojects\game\mega_game\art\levels\office_main.tscn"
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(body)

print("written", path, len(body.splitlines()), "lines")
