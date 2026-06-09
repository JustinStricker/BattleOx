@tool
extends SceneTree

# Usage: godot -d -s validate.gd 2>&1 | tee -a godot.log
#
# Forces compilation of every .gd file in the project to surface all
# GDScript compile-time warnings to stdout (and by tee, to godot.log).
# Temporarily elevates all warnings to Error level so they print.
# Warnings are otherwise only visible in the editor Debugger panel.
#
# Requires: godot -d (debug mode) to print warnings at Warn level.
#
# NOTE: Clear godot.log after troubleshooting by running:
#   > /dev/null godot.log || rm godot.log
# or: echo "" > godot.log

func _initialize():
	print("=== GDScript Warning Validator ===")
	var warning_settings = []
	for prop in ProjectSettings.get_property_list():
		if prop.name.begins_with("debug/gdscript/warnings/"):
			warning_settings.append(prop.name)
	var originals = {}
	for s in warning_settings:
		originals[s] = ProjectSettings.get_setting(s)
		ProjectSettings.set_setting(s, 2)
	var count = 0
	var errors = 0
	for path in _find_files("res://", ".gd"):
		if load(path) == null:
			errors += 1
		count += 1
	for s in originals:
		ProjectSettings.set_setting(s, originals[s])
	print("\n=== Results ===")
	print("  Scripts: %d" % count)
	print("  Issues:  %d" % errors)
	if errors > 0:
		print("  (See above for details)")
	quit()

func _find_files(root_path: String, ext: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(root_path)
	if not dir:
		return result
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		var p = root_path.path_join(f)
		if dir.current_is_dir():
			if f != "." and f != "..":
				result.append_array(_find_files(p + "/", ext))
		elif f.ends_with(ext):
			result.append(p)
		f = dir.get_next()
	return result
