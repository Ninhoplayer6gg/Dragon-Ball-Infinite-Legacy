#!/usr/bin/env python3
"""Generates the TEMPORARY character model of Dragon Ball: Infinite Legacy.

Writes dbil/mods/dbil_character/models/dbil_character.b3d: a blocky humanoid
(32 skin pixels tall, classic 64x32 box skin layout) with spiky hair as a
second material, a 7-bone skeleton and all animations used by the game.

Materials (textures list order in Lua): 1 = skin, 2 = hair.
Animation frame ranges must match dbil_core/config/theme.lua.

Usage: python3 tools/assets/gen_model.py
"""
import math
import os
import struct

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "dbil", "mods",
                                   "dbil_character", "models", "dbil_character.b3d"))

PX = 0.55          # model units per skin pixel (10 units = 1 node)
TEX_W, TEX_H = 64, 32


# ----------------------------------------------------------------- skeleton --

# name: (parent, global pivot)
BONES = {
    "Root": (None, (0.0, 0.0, 0.0)),
    "Body": ("Root", (0.0, 12 * PX, 0.0)),
    "Head": ("Body", (0.0, 24 * PX, 0.0)),
    "Arm_Right": ("Body", (6 * PX, 23 * PX, 0.0)),
    "Arm_Left": ("Body", (-6 * PX, 23 * PX, 0.0)),
    "Leg_Right": ("Body", (2 * PX, 12 * PX, 0.0)),
    "Leg_Left": ("Body", (-2 * PX, 12 * PX, 0.0)),
}
BONE_ORDER = ["Root", "Body", "Head", "Arm_Right", "Arm_Left", "Leg_Right", "Leg_Left"]

# ------------------------------------------------------------------ meshes --


class Mesh:
    def __init__(self):
        self.verts = []        # (x, y, z, u, v)
        self.bone_of = []      # bone name per vertex
        self.tris = {0: [], 1: []}  # brush -> [(a, b, c)]

    def vert(self, pos, uv, bone):
        self.verts.append((pos[0], pos[1], pos[2], uv[0], uv[1]))
        self.bone_of.append(bone)
        return len(self.verts) - 1

    def quad(self, corners, uvs, bone, brush):
        """corners: 4 points counter-clockwise seen from outside."""
        idx = [self.vert(c, uv, bone) for c, uv in zip(corners, uvs)]
        self.tris[brush].append((idx[0], idx[1], idx[2]))
        self.tris[brush].append((idx[0], idx[2], idx[3]))

    def tri(self, pts, uvs, bone, brush):
        idx = [self.vert(p, uv, bone) for p, uv in zip(pts, uvs)]
        self.tris[brush].append(tuple(idx))


def uv_rect(x0, y0, x1, y1, flip_u=False):
    """UVs for a quad listed as (bottom-left, bottom-right, top-right, top-left)
    in image space where y grows downward."""
    u0, u1 = x0 / TEX_W, x1 / TEX_W
    v0, v1 = y0 / TEX_H, y1 / TEX_H
    if flip_u:
        u0, u1 = u1, u0
    return [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]


def box(mesh, bone, mn, mx, uvblock, mirror=False, inflate=0.0):
    """Axis aligned box with classic skin UVs. Front faces +Z; the
    character's right side is +X."""
    x0, y0, z0 = (c - inflate for c in mn)
    x1, y1, z1 = (c + inflate for c in mx)
    u, v, w, h, d = uvblock
    faces = {
        "top": (u + d, v, u + d + w, v + d),
        "bottom": (u + d + w, v, u + d + 2 * w, v + d),
        "right": (u, v + d, u + d, v + d + h),
        "front": (u + d, v + d, u + d + w, v + d + h),
        "left": (u + d + w, v + d, u + 2 * d + w, v + d + h),
        "back": (u + 2 * d + w, v + d, u + 2 * d + 2 * w, v + d + h),
    }
    if mirror:
        faces["right"], faces["left"] = faces["left"], faces["right"]
    # Each quad: (bottom-left, bottom-right, top-right, top-left) as seen by a
    # viewer looking at that face from outside.
    quads = {
        # Front (+Z): viewer at +Z sees +X on their left.
        "front": [(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)],
        # Back (-Z): viewer sees -X on their left.
        "back": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
        # Right (+X): viewer sees -Z on their left.
        "right": [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)],
        # Left (-X): viewer sees +Z on their left.
        "left": [(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)],
        # Top: image bottom edge touches the front face.
        "top": [(x1, y1, z1), (x0, y1, z1), (x0, y1, z0), (x1, y1, z0)],
        # Bottom: image top edge touches the front face.
        "bottom": [(x1, y0, z0), (x0, y0, z0), (x0, y0, z1), (x1, y0, z1)],
    }
    for name, corners in quads.items():
        rect = faces[name]
        uvs = uv_rect(*rect, flip_u=mirror)
        mesh.quad(corners, uvs, bone, 0)


def hair_uv(p):
    return ((p[0] / (8 * PX) + 0.5) % 1.0, (p[1] / (8 * PX)) % 1.0)


def pyramid(mesh, bone, base_center, half, tip, axis="y"):
    """Square-based spike. axis is the base plane normal ('y', 'x', 'z')."""
    cx, cy, cz = base_center
    if axis == "y":
        base = [(cx - half, cy, cz - half), (cx + half, cy, cz - half),
                (cx + half, cy, cz + half), (cx - half, cy, cz + half)]
    elif axis == "x":
        base = [(cx, cy - half, cz - half), (cx, cy - half, cz + half),
                (cx, cy + half, cz + half), (cx, cy + half, cz - half)]
    else:
        base = [(cx - half, cy - half, cz), (cx + half, cy - half, cz),
                (cx + half, cy + half, cz), (cx - half, cy + half, cz)]
    apex = (cx + tip[0], cy + tip[1], cz + tip[2])
    for i in range(4):
        a, b = base[i], base[(i + 1) % 4]
        mesh.tri([a, b, apex], [hair_uv(a), hair_uv(b), hair_uv(apex)], bone, 1)
    mesh.tri([base[0], base[2], base[1]], [hair_uv(base[0]), hair_uv(base[2]), hair_uv(base[1])], bone, 1)
    mesh.tri([base[0], base[3], base[2]], [hair_uv(base[0]), hair_uv(base[3]), hair_uv(base[2])], bone, 1)


def hair_box(mesh, bone, mn, mx):
    x0, y0, z0 = mn
    x1, y1, z1 = mx
    quads = [
        [(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)],
        [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
        [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)],
        [(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)],
        [(x1, y1, z1), (x0, y1, z1), (x0, y1, z0), (x1, y1, z0)],
        [(x1, y0, z0), (x0, y0, z0), (x0, y0, z1), (x1, y0, z1)],
    ]
    for q in quads:
        mesh.quad(q, [hair_uv(p) for p in q], bone, 1)


def build_mesh():
    m = Mesh()
    P = PX
    # Legs (right = +X).
    box(m, "Leg_Right", (0, 0, -2 * P), (4 * P, 12 * P, 2 * P), (0, 16, 4, 12, 4))
    box(m, "Leg_Left", (-4 * P, 0, -2 * P), (0, 12 * P, 2 * P), (0, 16, 4, 12, 4), mirror=True)
    # Body.
    box(m, "Body", (-4 * P, 12 * P, -2 * P), (4 * P, 24 * P, 2 * P), (16, 16, 8, 12, 4))
    # Arms.
    box(m, "Arm_Right", (4 * P, 12 * P, -2 * P), (8 * P, 24 * P, 2 * P), (40, 16, 4, 12, 4))
    box(m, "Arm_Left", (-8 * P, 12 * P, -2 * P), (-4 * P, 24 * P, 2 * P), (40, 16, 4, 12, 4), mirror=True)
    # Head.
    box(m, "Head", (-4 * P, 24 * P, -4 * P), (4 * P, 32 * P, 4 * P), (0, 0, 8, 8, 8))

    # Hair: cap + spikes (material 2).
    top = 32 * P
    hair_box(m, "Head", (-4.4 * P, 28.6 * P, -4.4 * P), (4.4 * P, top + 0.5 * P, 4.4 * P))
    hair_box(m, "Head", (-4.4 * P, 24.6 * P, -4.4 * P), (4.4 * P, 28.6 * P, -1.8 * P))
    hair_box(m, "Head", (-4.4 * P, 26.0 * P, -1.8 * P), (-3.6 * P, 28.6 * P, 2.0 * P))
    hair_box(m, "Head", (3.6 * P, 26.0 * P, -1.8 * P), (4.4 * P, 28.6 * P, 2.0 * P))
    y = top + 0.5 * P
    spikes_up = [
        ((-2.2 * P, y, 1.8 * P), 1.6 * P, (-0.8 * P, 5.5 * P, 0.6 * P)),
        ((1.8 * P, y, 1.6 * P), 1.6 * P, (1.0 * P, 5.0 * P, 0.4 * P)),
        ((0.0, y, -0.2 * P), 1.9 * P, (0.0, 6.5 * P, -1.5 * P)),
        ((-2.6 * P, y, -2.4 * P), 1.7 * P, (-1.6 * P, 5.0 * P, -2.2 * P)),
        ((2.6 * P, y, -2.4 * P), 1.7 * P, (1.8 * P, 4.6 * P, -2.4 * P)),
    ]
    for base, half, tip in spikes_up:
        pyramid(m, "Head", base, half, tip, "y")
    # Side spikes.
    for sx in (-1, 1):
        pyramid(m, "Head", (sx * 4.4 * P, 29.5 * P, -0.5 * P), 1.4 * P, (sx * 3.2 * P, 1.6 * P, -1.0 * P), "x")
        pyramid(m, "Head", (sx * 4.4 * P, 27.0 * P, -2.5 * P), 1.3 * P, (sx * 2.6 * P, -0.6 * P, -1.6 * P), "x")
    # Back spikes.
    for bx in (-2.2 * P, 0.0, 2.2 * P):
        pyramid(m, "Head", (bx, 27.5 * P, -4.4 * P), 1.5 * P, (bx * 0.3, -1.5 * P, -3.6 * P), "z")
    # Front bangs.
    for fx, tipx in ((-2.4 * P, -0.4 * P), (0.2 * P, 0.3 * P), (2.4 * P, 0.5 * P)):
        pyramid(m, "Head", (fx, 30.4 * P, 4.4 * P), 1.0 * P, (tipx, -2.8 * P, 0.8 * P), "z")
    return m

# -------------------------------------------------------------- animations --

# Each animation: (start, end, [(frame, pose)]). A pose maps bone -> (rx, ry, rz)
# in degrees; "Root_pos" moves the whole model. Unlisted bones are at rest.
# Rotations are applied X, then Y, then Z, in the parent's frame. Conventions
# (verified on screenshots, see tests/run_visual.py with scenario "poses"):
#   rx > 0  swings a hanging limb FORWARD; tips Body/Head/Root BACKWARD
#   ry > 0  turns the bone to its left (the right shoulder comes forward)
#   rz > 0  moves a hanging right limb inward and a left limb outward

STAND_A = {"Arm_Right": (0, 0, -4), "Arm_Left": (0, 0, 4)}
STAND_B = {"Arm_Right": (0, 0, -6), "Arm_Left": (0, 0, 6), "Head": (2, 0, 0)}
GUARD = {"Arm_Right": (60, 0, 10), "Arm_Left": (55, 0, -10), "Body": (-5, 0, 0)}

ANIMS = {
    "stand": (0, 40, [(0, STAND_A), (20, STAND_B), (40, STAND_A)]),
    "walk": (50, 70, [
        (50, {"Leg_Right": (35, 0, 0), "Leg_Left": (-35, 0, 0), "Arm_Right": (-30, 0, -3), "Arm_Left": (30, 0, 3)}),
        (55, {"Arm_Right": (0, 0, -3), "Arm_Left": (0, 0, 3)}),
        (60, {"Leg_Right": (-35, 0, 0), "Leg_Left": (35, 0, 0), "Arm_Right": (30, 0, -3), "Arm_Left": (-30, 0, 3)}),
        (65, {"Arm_Right": (0, 0, -3), "Arm_Left": (0, 0, 3)}),
        (70, {"Leg_Right": (35, 0, 0), "Leg_Left": (-35, 0, 0), "Arm_Right": (-30, 0, -3), "Arm_Left": (30, 0, 3)}),
    ]),
    "light": (80, 90, [
        (80, GUARD),
        (83, {"Arm_Right": (95, 0, 5), "Arm_Left": (55, 0, -10), "Body": (-5, 20, 0)}),
        (86, {"Arm_Right": (92, 0, 5), "Arm_Left": (55, 0, -10), "Body": (-5, 18, 0)}),
        (90, GUARD),
    ]),
    "light_alt": (95, 105, [
        (95, GUARD),
        (98, {"Arm_Left": (95, 0, -5), "Arm_Right": (60, 0, 10), "Body": (-5, -20, 0)}),
        (101, {"Arm_Left": (92, 0, -5), "Arm_Right": (60, 0, 10), "Body": (-5, -18, 0)}),
        (105, GUARD),
    ]),
    "heavy": (110, 126, [
        (110, GUARD),
        (114, {"Arm_Right": (-50, 0, -20), "Arm_Left": (60, 0, -10), "Body": (5, -30, 0), "Leg_Right": (-15, 0, 0)}),
        (118, {"Arm_Right": (100, 0, 5), "Arm_Left": (30, 0, -15), "Body": (-15, 35, 0), "Leg_Left": (25, 0, 0), "Leg_Right": (-20, 0, 0)}),
        (122, {"Arm_Right": (95, 0, 5), "Arm_Left": (35, 0, -15), "Body": (-12, 30, 0), "Leg_Left": (20, 0, 0), "Leg_Right": (-15, 0, 0)}),
        (126, GUARD),
    ]),
    "block": (130, 135, [
        (130, {"Arm_Right": (85, 40, 0), "Arm_Left": (80, -40, 0), "Body": (-8, 0, 0), "Head": (-8, 0, 0)}),
        (135, {"Arm_Right": (85, 40, 0), "Arm_Left": (80, -40, 0), "Body": (-8, 0, 0), "Head": (-8, 0, 0)}),
    ]),
    "charge": (140, 160, [
        (140, {"Arm_Right": (-10, 0, -25), "Arm_Left": (-10, 0, 25), "Body": (6, 0, 0), "Head": (12, 0, 0),
               "Leg_Right": (0, 0, -8), "Leg_Left": (0, 0, 8)}),
        (145, {"Arm_Right": (-14, 0, -30), "Arm_Left": (-14, 0, 30), "Body": (8, 0, 2), "Head": (15, 0, 0),
               "Leg_Right": (0, 0, -9), "Leg_Left": (0, 0, 9)}),
        (150, {"Arm_Right": (-10, 0, -26), "Arm_Left": (-10, 0, 26), "Body": (6, 0, -2), "Head": (12, 0, 0),
               "Leg_Right": (0, 0, -8), "Leg_Left": (0, 0, 8)}),
        (155, {"Arm_Right": (-14, 0, -30), "Arm_Left": (-14, 0, 30), "Body": (8, 0, 2), "Head": (15, 0, 0),
               "Leg_Right": (0, 0, -9), "Leg_Left": (0, 0, 9)}),
        (160, {"Arm_Right": (-10, 0, -25), "Arm_Left": (-10, 0, 25), "Body": (6, 0, 0), "Head": (12, 0, 0),
               "Leg_Right": (0, 0, -8), "Leg_Left": (0, 0, 8)}),
    ]),
    "fly": (170, 190, [
        (170, {"Body": (-75, 0, 0), "Head": (65, 0, 0), "Arm_Right": (170, 0, 6), "Arm_Left": (-10, 0, 10),
               "Leg_Right": (-5, 0, 0), "Leg_Left": (-12, 0, 0)}),
        (180, {"Body": (-80, 0, 0), "Head": (70, 0, 0), "Arm_Right": (172, 0, 4), "Arm_Left": (-6, 0, 8),
               "Leg_Right": (-12, 0, 0), "Leg_Left": (-5, 0, 0)}),
        (190, {"Body": (-75, 0, 0), "Head": (65, 0, 0), "Arm_Right": (170, 0, 6), "Arm_Left": (-10, 0, 10),
               "Leg_Right": (-5, 0, 0), "Leg_Left": (-12, 0, 0)}),
    ]),
    "hover": (200, 220, [
        (200, {"Leg_Right": (20, 0, -5), "Leg_Left": (-10, 0, 5), "Arm_Right": (10, 0, -15), "Arm_Left": (10, 0, 15),
               "Root_pos": (0, 0.0, 0)}),
        (210, {"Leg_Right": (25, 0, -5), "Leg_Left": (-6, 0, 5), "Arm_Right": (14, 0, -18), "Arm_Left": (14, 0, 18),
               "Root_pos": (0, 0.5, 0)}),
        (220, {"Leg_Right": (20, 0, -5), "Leg_Left": (-10, 0, 5), "Arm_Right": (10, 0, -15), "Arm_Left": (10, 0, 15),
               "Root_pos": (0, 0.0, 0)}),
    ]),
    "fire": (230, 240, [
        (230, {"Arm_Right": (40, 0, -10), "Arm_Left": (40, 0, 10), "Body": (0, -15, 0)}),
        (233, {"Arm_Right": (92, 0, 8), "Arm_Left": (92, 0, -8), "Body": (-6, 0, 0), "Leg_Right": (-15, 0, 0), "Leg_Left": (20, 0, 0)}),
        (240, {"Arm_Right": (88, 0, 8), "Arm_Left": (88, 0, -8), "Body": (-4, 0, 0), "Leg_Right": (-12, 0, 0), "Leg_Left": (15, 0, 0)}),
    ]),
    "hurt": (250, 256, [
        (250, {"Body": (15, 0, 0), "Head": (20, 0, 0), "Arm_Right": (-20, 0, -30), "Arm_Left": (-20, 0, 30)}),
        (253, {"Body": (20, 0, 0), "Head": (25, 0, 0), "Arm_Right": (-25, 0, -35), "Arm_Left": (-25, 0, 35)}),
        (256, {"Body": (8, 0, 0), "Head": (10, 0, 0), "Arm_Right": (-10, 0, -15), "Arm_Left": (-10, 0, 15)}),
    ]),
    "dead": (260, 262, [
        (260, {"Root": (90, 0, 0), "Root_pos": (0, 2.2, 0), "Arm_Right": (0, 0, -40), "Arm_Left": (0, 0, 40)}),
        (262, {"Root": (90, 0, 0), "Root_pos": (0, 2.2, 0), "Arm_Right": (0, 0, -40), "Arm_Left": (0, 0, 40)}),
    ]),
}
LAST_FRAME = 262


def quat_from_euler(rx, ry, rz):
    """File quaternion (w, x, y, z) for a pose rotation.

    The engine applies the conjugate of the stored quaternion, so composing
    qx * qy * qz here results in X, then Y, then Z being applied in game."""
    rx, ry, rz = math.radians(rx), math.radians(ry), math.radians(rz)

    def q_axis(ax, ang):
        s = math.sin(ang / 2)
        return (math.cos(ang / 2), ax[0] * s, ax[1] * s, ax[2] * s)

    def mul(a, b):
        aw, ax, ay, az = a
        bw, bx, by, bz = b
        return (aw * bw - ax * bx - ay * by - az * bz,
                aw * bx + ax * bw + ay * bz - az * by,
                aw * by - ax * bz + ay * bw + az * bx,
                aw * bz + ax * by - ay * bx + az * bw)
    qx = q_axis((1, 0, 0), rx)
    qy = q_axis((0, 1, 0), ry)
    qz = q_axis((0, 0, 1), rz)
    return mul(qx, mul(qy, qz))


def keyframes():
    """bone -> sorted list of (frame, quat, pos or None)."""
    keys = {b: [] for b in BONE_ORDER}
    for _, (start, end, frames) in ANIMS.items():
        for frame, pose in frames:
            for bone in BONE_ORDER:
                rot = pose.get(bone, (0, 0, 0))
                pos = None
                if bone == "Root":
                    pos = pose.get("Root_pos", (0, 0, 0))
                keys[bone].append((frame, quat_from_euler(*rot), pos))
    for bone in keys:
        keys[bone].sort(key=lambda k: k[0])
    return keys

# ------------------------------------------------------------------ writer --


def chunk(name, payload):
    return name.encode() + struct.pack("<i", len(payload)) + payload


def cstr(s):
    return s.encode() + b"\0"


def write_b3d(mesh):
    keys = keyframes()
    # Vertex positions are relative to the "Model" node (identity), i.e. model space.
    vrts = struct.pack("<iii", 0, 1, 2)
    for x, y, z, u, v in mesh.verts:
        vrts += struct.pack("<3f2f", x, y, z, u, v)
    tris = b""
    for brush in (0, 1):
        data = struct.pack("<i", brush)
        for a, b, c in mesh.tris[brush]:
            data += struct.pack("<3i", a, b, c)
        tris += chunk("TRIS", data)
    mesh_chunk = chunk("MESH", struct.pack("<i", -1) + chunk("VRTS", vrts) + tris)

    def node(bone):
        parent, pivot = BONES[bone]
        ppos = BONES[parent][1] if parent else (0.0, 0.0, 0.0)
        local = tuple(pivot[i] - ppos[i] for i in range(3))
        payload = cstr(bone) + struct.pack("<3f3f4f", *local, 1, 1, 1, 1, 0, 0, 0)
        weights = b"".join(struct.pack("<if", i, 1.0) for i, b in enumerate(mesh.bone_of) if b == bone)
        payload += chunk("BONE", weights)
        flags = 4 | (1 if bone == "Root" else 0)
        kdata = struct.pack("<i", flags)
        for frame, q, pos in keys[bone]:
            kdata += struct.pack("<i", frame + 1)  # B3D frames are 1-based
            if flags & 1:
                kdata += struct.pack("<3f", local[0] + pos[0], local[1] + pos[1], local[2] + pos[2])
            kdata += struct.pack("<4f", *q)
        payload += chunk("KEYS", kdata)
        for child in BONE_ORDER:
            if BONES[child][0] == bone:
                payload += node(child)
        return chunk("NODE", payload)

    anim = chunk("ANIM", struct.pack("<iif", 0, LAST_FRAME + 1, 30.0))
    brushes = struct.pack("<i", 0)
    for name in ("skin", "hair"):
        brushes += cstr(name) + struct.pack("<5f2i", 1, 1, 1, 1, 0, 1, 0)
    brus = chunk("BRUS", brushes)
    model = chunk("NODE", cstr("Model") + struct.pack("<3f3f4f", 0, 0, 0, 1, 1, 1, 1, 0, 0, 0)
                  + mesh_chunk + node("Root") + anim)
    data = chunk("BB3D", struct.pack("<i", 1) + brus + model)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(data)
    print("wrote", OUT, len(data), "bytes,", len(mesh.verts), "vertices")


if __name__ == "__main__":
    write_b3d(build_mesh())
