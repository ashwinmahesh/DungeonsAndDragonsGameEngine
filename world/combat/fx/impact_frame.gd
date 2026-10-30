class_name ImpactFrame
extends CanvasLayer
## An impact frame (GameFeel's `impact_frame`, shaders/post/impact_frame.gdshader): for a few frames on a critical hit
## or a killing blow the picture turns to ink and paper, inverted first, then as it is. Counted in drawn frames, not
## seconds, so a hit-stop holding the fight doesn't stretch it. One per window, hidden between blows; over the world and
## the screen pulse, under every menu and the HUD. Never in headless runs, nor with reduced motion.

const SHADER := preload("res://addons/dnd_core/shaders/post/impact_frame.gdshader")
const LAYER := -4
static var _layers: Dictionary = {}

var _rect: ColorRect
var _mat: ShaderMaterial
var _left := 0
var _half := 0
var _pending := 0


## Shows the frame for `frames` drawn frames in the window `from` is in, its speed lines out from `at`.
static func play(from: Node, frames: int, at: Vector3 = Vector3.INF) -> void:
	if frames <= 0 or from == null or not from.is_inside_tree() or MobileNative.reduced_motion() \
			or DisplayServer.get_name() == "headless":
		return
	var f := _for(from)
	f._mat.set_shader_parameter("ink", Look.color(str(GameFeel.settings()["impact_ink"])))
	f._mat.set_shader_parameter("paper", Look.color(str(GameFeel.settings()["impact_paper"])))
	if f.is_inside_tree():
		f._start(frames, at)
	else:
		f._pending = frames


static func _for(from: Node) -> ImpactFrame:
	var vp := from.get_viewport()
	var have: Variant = _layers.get(vp.get_instance_id())
	if is_instance_valid(have) and not (have as Node).is_queued_for_deletion():
		return have as ImpactFrame
	var f := ImpactFrame.new()
	f.name = "ImpactFrame"
	f.layer = LAYER
	f.visible = false
	f._mat = ShaderMaterial.new()
	f._mat.shader = SHADER
	f._rect = ColorRect.new()
	f._rect.material = f._mat
	f._rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f._rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.add_child(f._rect)
	_layers[vp.get_instance_id()] = f
	vp.add_child.call_deferred(f)
	return f


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _pending > 0:
		_start(_pending, Vector3.INF)
		_pending = 0


func _exit_tree() -> void:
	for key: Variant in _layers.keys():
		if _layers[key] == self:
			_layers.erase(key)


func _start(frames: int, at: Vector3) -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var cam := vp.get_camera_3d()
	var centre := Vector2(0.5, 0.5)
	if at != Vector3.INF and cam != null and not cam.is_position_behind(at):
		centre = cam.unproject_position(at) / size
	_mat.set_shader_parameter("centre", centre)
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_left = frames
	_half = maxi(1, frames / 2)
	_mat.set_shader_parameter("invert", true)
	visible = true


func _process(_delta: float) -> void:
	if not visible:
		return
	_left -= 1
	if _left <= 0 or MobileNative.reduced_motion():
		visible = false
	elif _left <= _half:
		_mat.set_shader_parameter("invert", false)
