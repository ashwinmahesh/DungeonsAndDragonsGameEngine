class_name MobileNative
extends Node
## iOS-only services are instantiated dynamically, so desktop imports and play do not load native code.

signal file_result(kind: String, value: String)
static var current: MobileNative
var bridge: Object
var pending := false
var system_reduced_motion := false
var accessibility := MobileAccessibility.new()
var access_time := 0.0
var accessibility_running := false
const IMPORT := "user://transfers/incoming.json"


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("ios") and ClassDB.class_exists(&"MobileIOS"):
		bridge = ClassDB.instantiate(&"MobileIOS")
		# Sensor must be enabled in the iOS project for runtime orientation changes.
		# Device idiom stays stable when an iPad window becomes narrower than a phone.
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR if bool(bridge.call("is_tablet"))
			else DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		bridge.call("observe_motion")
		bridge.call("observe_accessibility")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and available():
		# Godot 4.7.2 starts its audio unit immediately after this notification returns.
		# Reactivate synchronously; a deferred/main-queue task would race that restart.
		# This only prepares audio. MobileLifecycle still owns the player's Continue pause.
		var error := str(bridge.call("activate_audio_session"))
		if error != "":
			push_error("iOS audio session could not resume: " + error)


func _exit_tree() -> void:
	if current == self:
		current = null


func available() -> bool:
	return bridge != null


func import_save() -> void:
	if not available() or pending:
		return
	DirAccess.make_dir_recursive_absolute("user://transfers")
	pending = true
	UiFeel.touch.cancel()
	bridge.call("import_save", ProjectSettings.globalize_path(IMPORT))


func share_save(path: String) -> Error:
	return _share_json(path, transfer_path("save"))


func share_report(path: String) -> Error:
	return _share_json(path, transfer_path("diagnostics"))


## Keep exported file names recognizable while leaving campaign branding with the host project.
static func transfer_path(kind: String) -> String:
	var title := str(ProjectSettings.get_setting("application/config/name", "Game")).to_pascal_case().validate_filename()
	return "user://transfers/%s-%s.json" % [title if title != "" else "Game", kind.validate_filename()]


func _share_json(path: String, destination: String) -> Error:
	if not available() or pending:
		return ERR_BUSY
	var err := SaveTransfer.share_copy(path, destination)
	if err != OK:
		return err
	pending = true
	UiFeel.touch.cancel()
	bridge.call("share_save", ProjectSettings.globalize_path(destination))
	return OK


func _process(delta: float) -> void:
	if bridge == null:
		return
	access_time -= delta
	if access_time <= 0:
		access_time = 0.25
		var requested := OS.get_cmdline_user_args().has("--native-ui-testing") or bool(bridge.call("assistive_access_enabled"))
		if requested != accessibility_running:
			accessibility.snapshot_key = 0
		accessibility_running = requested
		if accessibility_running and not pending:
			_sync_accessibility()
	var messages: Variant = JSON.parse_string(str(bridge.call("take_events")))
	if not messages is Array:
		return
	for message: Dictionary in messages:
		var kind := str(message.get("kind", ""))
		if kind == "access_refresh":
			# UIKit rejected a projection while its scene had no active presenter. Its content
			# hash may be unchanged on return, so request a fresh delivery on the next frame.
			accessibility.snapshot_key = 0
			access_time = 0.0
			continue
		if kind == "reduce_motion":
			system_reduced_motion = str(message.get("value", "")) == "1"
		if kind.begins_with("access_") and accessibility_running and not pending:
			# Revalidate queued actions and publish any changed state to UIKit. A snapshot
			# advances the cached revision, so discarding it would strand native clients.
			_sync_accessibility()
			accessibility.activate(kind, str(message.get("value", "")))
		if kind.begins_with("file_"):
			pending = false
			accessibility.snapshot_key = 0
			file_result.emit(kind, str(message.get("value", "")))


func _sync_accessibility() -> void:
	var snapshot := accessibility.snapshot(get_tree().root)
	if not snapshot.is_empty():
		bridge.call("set_accessibility", JSON.stringify(snapshot))


static func feedback() -> void:
	if current != null and current.available() and not current.pending and bool(GameSettings.value("ios_haptics", true)):
		current.bridge.call("haptic")


## Mobile preference only; desktop keeps its existing animation and camera behavior.
static func reduced_motion() -> bool:
	return MobileDevice.enabled() and (bool(GameSettings.value("ios_reduce_motion", false))
		or current != null and current.system_reduced_motion)
