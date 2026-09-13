extends Node

# Godot Web exports can lack CJK fallback glyphs on some iPhone/Safari setups.
# Keep the original Traditional Chinese source strings for native builds, but
# replace visible Web text with ASCII-safe equivalents until a bundled CJK
# font is introduced for production.

const REPLACEMENTS := [
    ["先點背包寶石，再點孔洞安裝。四個孔洞彼此連線，輔助只會強化同組主動寶石。", "Tap a stash gem, then a socket. All 4 sockets are linked."],
    ["背包暫時沒有寶石；擊殺怪物後有機率掉落。", "No gems in stash. Enemies can drop gems."],
    ["你被裂隙吞沒，已在營火重生", "Defeated - respawned at camp"],
    ["沒有安裝主動寶石", "No active gem installed"],
    ["左下移動 · 右下攻擊 · 右上寶石", "Move: left / Attack: right / Gems: top"],
    ["裂隙寶石 · 4 連", "RIFT GEMS - 4 LINK"],
    ["寶石背包", "GEM STASH"],
    ["拾取：", "PICKUP: "],
    ["菁英裂隙獸", "ELITE RIFTBEAST"],
    ["裂隙獸", "RIFTBEAST"],
    ["緋紅裂矢", "Crimson Bolt"],
    ["翠綠疾矢", "Verdant Volley"],
    ["蒼藍霜槍", "Azure Lance"],
    ["蒼藍躍電", "Azure Arcshot"],
    ["緋紅猛攻", "Crimson Force"],
    ["緋紅爆裂", "Crimson Burst"],
    ["翠綠連鎖", "Verdant Chain"],
    ["翠綠多重", "Verdant Multishot"],
    ["翠綠分岔", "Verdant Fork"],
    ["蒼藍穿透", "Azure Pierce"],
    ["蒼藍迅捷", "Azure Haste"],
    ["蒼藍延伸", "Azure Reach"],
    ["未裝主動", "NO ACTIVE"],
    ["個連線輔助", "LINKED SUPPORTS"],
    ["生命", "HP"],
    ["擊殺", "KILLS"],
    ["投射", "PROJECTILES"],
    ["連鎖", "CHAIN"],
    ["主動", "ACTIVE"],
    ["輔助", "SUPPORT"],
    ["空孔", "EMPTY"],
    ["攻擊", "ATTACK"],
    ["寶石", "GEMS"],
]

const SYMBOL_REPLACEMENTS := [
    ["◆", "*"], ["✦", "*"], ["◇", "<>"], ["ϟ", "Z"],
    ["⬢", "#"], ["✹", "*"], ["⌁", "~"], ["⋔", "M"],
    ["➶", "->"], ["↯", "!"], ["⇢", "->"], ["○", "O"],
    ["·", " / "], ["：", ": "], ["；", "; "], ["，", ", "], ["。", "."],
]

var _elapsed := 0.0

func _ready() -> void:
    if not OS.has_feature("web"):
        set_process(false)
        return
    call_deferred("_patch_visible_text")

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < 0.12:
        return
    _elapsed = 0.0
    _patch_visible_text()

func _patch_visible_text() -> void:
    var scene := get_tree().current_scene
    if scene != null:
        _walk(scene)

func _walk(node: Node) -> void:
    if node is Label:
        var label := node as Label
        label.text = sanitize_text(label.text)
    elif node is Button:
        var button := node as Button
        button.text = sanitize_text(button.text)
    elif node is Label3D:
        var label3d := node as Label3D
        label3d.text = sanitize_text(label3d.text)

    for child in node.get_children():
        _walk(child)

static func sanitize_text(value: String) -> String:
    var output := value
    for pair in REPLACEMENTS:
        output = output.replace(String(pair[0]), String(pair[1]))
    for pair in SYMBOL_REPLACEMENTS:
        output = output.replace(String(pair[0]), String(pair[1]))

    var ascii := ""
    for index in range(output.length()):
        var code := output.unicode_at(index)
        if code == 10 or code == 9 or (code >= 32 and code <= 126):
            ascii += output.substr(index, 1)
    return ascii.strip_edges()
