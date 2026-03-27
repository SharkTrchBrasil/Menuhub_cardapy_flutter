"""
Gera animações Lottie de comida (pizza, burger, café, cupcake)
para o splash dinâmico do MenuHub Totem.
"""
import json, math, os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "assets", "animations")

def kf(t, val, ease_in=False, ease_out=False):
    """Cria um keyframe Lottie."""
    k = {"t": t, "s": val if isinstance(val, list) else [val]}
    if ease_in or ease_out:
        k["i"] = {"x": [0.42], "y": [1]}
        k["o"] = {"x": [0.58], "y": [0]}
    return k

def animated_prop(keyframes):
    return {"a": 1, "k": keyframes}

def static_prop(val):
    if isinstance(val, list):
        return {"a": 0, "k": val}
    return {"a": 0, "k": val}

def make_fill(r, g, b, opacity=100):
    return {
        "ty": "fl",
        "c": static_prop([r/255, g/255, b/255, 1]),
        "o": static_prop(opacity),
        "r": 1,
        "bm": 0
    }

def make_ellipse(cx, cy, rx, ry):
    return {
        "ty": "el",
        "p": static_prop([cx, cy]),
        "s": static_prop([rx*2, ry*2]),
    }

def make_rect(cx, cy, w, h, r=0):
    return {
        "ty": "rc",
        "p": static_prop([cx, cy]),
        "s": static_prop([w, h]),
        "r": static_prop(r),
    }

def make_group(name, shapes, transform=None):
    if transform is None:
        transform = {
            "ty": "tr",
            "p": static_prop([0, 0]),
            "a": static_prop([0, 0]),
            "s": static_prop([100, 100]),
            "r": static_prop(0),
            "o": static_prop(100),
        }
    items = shapes + [transform]
    return {"ty": "gr", "it": items, "nm": name}

def make_shape_layer(name, groups, w, h, transform_override=None):
    tr = {
        "o": static_prop(100),
        "r": static_prop(0),
        "p": static_prop([w/2, h/2]),
        "a": static_prop([w/2, h/2]),
        "s": static_prop([100, 100]),
    }
    if transform_override:
        tr.update(transform_override)
    return {
        "ddd": 0,
        "ty": 4,
        "nm": name,
        "sr": 1,
        "ks": tr,
        "ao": 0,
        "shapes": groups,
        "ip": 0,
        "op": 90,
        "st": 0,
        "bm": 0,
    }

def wrap_lottie(name, w, h, layers, fr=30, op=90):
    return {
        "v": "5.7.4",
        "fr": fr,
        "ip": 0,
        "op": op,
        "w": w,
        "h": h,
        "nm": name,
        "ddd": 0,
        "assets": [],
        "layers": layers,
    }

# ═══════════════════════════════════════════
# 1. PIZZA — fatia girando
# ═══════════════════════════════════════════
def create_pizza():
    W, H = 200, 200
    cx, cy = 100, 100

    # Massa (triângulo via path)
    pizza_path = {
        "ty": "sh",
        "ks": static_prop({
            "c": True,
            "v": [[0, -70], [50, 50], [-50, 50]],
            "i": [[0,0],[0,0],[0,0]],
            "o": [[0,0],[0,0],[0,0]],
        })
    }
    
    # Borda curva
    crust_path = {
        "ty": "sh",
        "ks": static_prop({
            "c": False,
            "v": [[-50, 50], [0, 65], [50, 50]],
            "i": [[0,0],[-20,0],[0,0]],
            "o": [[0,0],[20,0],[0,0]],
        })
    }

    pizza_group = make_group("pizza_slice", [
        pizza_path,
        make_fill(255, 200, 50),  # Queijo amarelo
    ])
    
    crust_group = make_group("crust", [
        crust_path,
        {"ty": "st", "c": static_prop([0.76, 0.53, 0.18, 1]), "o": static_prop(100), "w": static_prop(10), "lc": 2, "lj": 2},
    ])

    # Pepperoni (bolinhas vermelhas)
    pep1 = make_group("pep1", [make_ellipse(-15, 10, 8, 8), make_fill(200, 40, 30)])
    pep2 = make_group("pep2", [make_ellipse(15, 15, 7, 7), make_fill(200, 40, 30)])
    pep3 = make_group("pep3", [make_ellipse(0, -20, 6, 6), make_fill(200, 40, 30)])

    # Layer com rotação
    layer = make_shape_layer("pizza", [pep3, pep2, pep1, crust_group, pizza_group], W, H, {
        "r": animated_prop([
            kf(0, [0], ease_out=True),
            kf(45, [-15], ease_in=True, ease_out=True),
            kf(90, [0], ease_in=True),
        ]),
        "s": animated_prop([
            kf(0, [100, 100], ease_out=True),
            kf(22, [110, 110], ease_in=True, ease_out=True),
            kf(45, [100, 100], ease_in=True, ease_out=True),
            kf(67, [95, 95], ease_in=True, ease_out=True),
            kf(90, [100, 100], ease_in=True),
        ]),
    })

    return wrap_lottie("Pizza Loading", W, H, [layer])


# ═══════════════════════════════════════════
# 2. BURGER — hambúrguer pulsando
# ═══════════════════════════════════════════
def create_burger():
    W, H = 200, 200

    # Pão superior (arco)
    top_bun = make_group("top_bun", [
        make_rect(0, -25, 80, 35, 20),
        make_fill(230, 170, 80),
    ])
    # Sementes de gergelim
    seed1 = make_group("seed1", [make_ellipse(-15, -30, 4, 6), make_fill(255, 245, 220)])
    seed2 = make_group("seed2", [make_ellipse(10, -35, 4, 6), make_fill(255, 245, 220)])
    seed3 = make_group("seed3", [make_ellipse(0, -25, 4, 6), make_fill(255, 245, 220)])

    # Alface
    lettuce = make_group("lettuce", [
        make_rect(0, -5, 85, 8, 4),
        make_fill(100, 190, 60),
    ])

    # Queijo
    cheese = make_group("cheese", [
        make_rect(0, 3, 82, 7, 2),
        make_fill(255, 210, 50),
    ])

    # Carne
    patty = make_group("patty", [
        make_rect(0, 13, 78, 14, 5),
        make_fill(120, 60, 30),
    ])

    # Pão inferior
    bottom_bun = make_group("bottom_bun", [
        make_rect(0, 28, 80, 18, 8),
        make_fill(220, 160, 70),
    ])

    layer = make_shape_layer("burger", [seed3, seed2, seed1, top_bun, lettuce, cheese, patty, bottom_bun], W, H, {
        "p": animated_prop([
            kf(0, [100, 100], ease_out=True),
            kf(20, [100, 85], ease_in=True, ease_out=True),
            kf(40, [100, 105], ease_in=True, ease_out=True),
            kf(55, [100, 95], ease_in=True, ease_out=True),
            kf(70, [100, 100], ease_in=True),
            kf(90, [100, 100]),
        ]),
        "s": animated_prop([
            kf(0, [100, 100], ease_out=True),
            kf(20, [105, 95], ease_in=True, ease_out=True),
            kf(40, [98, 103], ease_in=True, ease_out=True),
            kf(60, [100, 100], ease_in=True),
            kf(90, [100, 100]),
        ]),
    })

    return wrap_lottie("Burger Loading", W, H, [layer])


# ═══════════════════════════════════════════
# 3. CAFÉ — xícara com vapor
# ═══════════════════════════════════════════
def create_coffee():
    W, H = 200, 200

    # Xícara
    cup = make_group("cup", [
        make_rect(0, 15, 60, 55, 8),
        make_fill(160, 100, 60),
    ])

    # Café dentro
    coffee_liquid = make_group("coffee", [
        make_rect(0, 8, 52, 25, 4),
        make_fill(90, 50, 20),
    ])

    # Alça
    handle = make_group("handle", [
        make_ellipse(38, 18, 12, 16),
        {"ty": "st", "c": static_prop([0.63, 0.39, 0.24, 1]), "o": static_prop(100), "w": static_prop(6), "lc": 2, "lj": 2},
    ])

    # Prato
    saucer = make_group("saucer", [
        make_ellipse(0, 45, 45, 8),
        make_fill(200, 200, 200),
    ])

    # Vapor 1
    steam1_tr = {
        "ty": "tr",
        "p": static_prop([-12, -25]),
        "a": static_prop([0, 0]),
        "s": static_prop([100, 100]),
        "r": static_prop(0),
        "o": animated_prop([
            kf(0, [30], ease_out=True),
            kf(30, [80], ease_in=True, ease_out=True),
            kf(60, [30], ease_in=True, ease_out=True),
            kf(90, [30]),
        ]),
    }
    steam1 = {
        "ty": "gr",
        "it": [
            make_ellipse(0, 0, 6, 10),
            make_fill(220, 220, 220, 60),
            steam1_tr,
        ],
        "nm": "steam1",
    }

    # Vapor 2
    steam2_tr = {
        "ty": "tr",
        "p": animated_prop([
            kf(0, [5, -20], ease_out=True),
            kf(45, [5, -45], ease_in=True, ease_out=True),
            kf(90, [5, -20], ease_in=True),
        ]),
        "a": static_prop([0, 0]),
        "s": static_prop([100, 100]),
        "r": static_prop(0),
        "o": animated_prop([
            kf(0, [60], ease_out=True),
            kf(45, [20], ease_in=True, ease_out=True),
            kf(90, [60], ease_in=True),
        ]),
    }
    steam2 = {
        "ty": "gr",
        "it": [
            make_ellipse(0, 0, 5, 12),
            make_fill(200, 200, 200, 50),
            steam2_tr,
        ],
        "nm": "steam2",
    }

    # Vapor 3
    steam3_tr = {
        "ty": "tr",
        "p": animated_prop([
            kf(0, [12, -22], ease_out=True),
            kf(60, [12, -50], ease_in=True, ease_out=True),
            kf(90, [12, -22], ease_in=True),
        ]),
        "a": static_prop([0, 0]),
        "s": static_prop([100, 100]),
        "r": static_prop(0),
        "o": animated_prop([
            kf(0, [40], ease_out=True),
            kf(60, [10], ease_in=True, ease_out=True),
            kf(90, [40], ease_in=True),
        ]),
    }
    steam3 = {
        "ty": "gr",
        "it": [
            make_ellipse(0, 0, 4, 8),
            make_fill(210, 210, 210, 40),
            steam3_tr,
        ],
        "nm": "steam3",
    }

    layer = make_shape_layer("coffee_cup", [steam3, steam2, steam1, coffee_liquid, cup, handle, saucer], W, H, {
        "s": animated_prop([
            kf(0, [100, 100], ease_out=True),
            kf(45, [103, 103], ease_in=True, ease_out=True),
            kf(90, [100, 100], ease_in=True),
        ]),
    })

    return wrap_lottie("Coffee Loading", W, H, [layer])


# ═══════════════════════════════════════════
# 4. CUPCAKE — cupcake pulsando
# ═══════════════════════════════════════════
def create_cupcake():
    W, H = 200, 200

    # Base do cupcake (wrapper)
    wrapper = make_group("wrapper", [
        {
            "ty": "sh",
            "ks": static_prop({
                "c": True,
                "v": [[-30, 0], [-25, 30], [25, 30], [30, 0]],
                "i": [[0,0],[0,0],[0,0],[0,0]],
                "o": [[0,0],[0,0],[0,0],[0,0]],
            })
        },
        make_fill(230, 130, 60),
    ])

    # Cobertura (frosting)
    frosting = make_group("frosting", [
        make_ellipse(0, -8, 35, 25),
        make_fill(255, 140, 180),
    ])

    # Cereja no topo
    cherry = make_group("cherry", [
        make_ellipse(0, -25, 10, 10),
        make_fill(220, 30, 50),
    ])

    # Granulados
    sprinkle1 = make_group("sp1", [make_ellipse(-12, -10, 3, 3), make_fill(255, 255, 100)])
    sprinkle2 = make_group("sp2", [make_ellipse(10, -5, 3, 3), make_fill(100, 200, 255)])
    sprinkle3 = make_group("sp3", [make_ellipse(-5, -15, 3, 3), make_fill(150, 255, 150)])
    sprinkle4 = make_group("sp4", [make_ellipse(8, -15, 3, 3), make_fill(255, 180, 100)])

    layer = make_shape_layer("cupcake", [cherry, sprinkle4, sprinkle3, sprinkle2, sprinkle1, frosting, wrapper], W, H, {
        "p": animated_prop([
            kf(0, [100, 105], ease_out=True),
            kf(25, [100, 90], ease_in=True, ease_out=True),
            kf(50, [100, 108], ease_in=True, ease_out=True),
            kf(70, [100, 98], ease_in=True, ease_out=True),
            kf(90, [100, 105], ease_in=True),
        ]),
        "r": animated_prop([
            kf(0, [0], ease_out=True),
            kf(25, [5], ease_in=True, ease_out=True),
            kf(50, [0], ease_in=True, ease_out=True),
            kf(75, [-5], ease_in=True, ease_out=True),
            kf(90, [0], ease_in=True),
        ]),
    })

    return wrap_lottie("Cupcake Loading", W, H, [layer])


# ═══════════════════════════════════════════
# GERAR TODOS
# ═══════════════════════════════════════════
os.makedirs(OUTPUT_DIR, exist_ok=True)

animations = {
    "food_pizza.json": create_pizza(),
    "food_burger.json": create_burger(),
    "food_coffee.json": create_coffee(),
    "food_cupcake.json": create_cupcake(),
}

for filename, data in animations.items():
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    size = os.path.getsize(path)
    print(f"✅ {filename} ({size} bytes)")

print(f"\n🎉 {len(animations)} animações geradas em {OUTPUT_DIR}")
