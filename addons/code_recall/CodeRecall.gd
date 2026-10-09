@tool
class_name CodeRecall
extends EditorPlugin

var cfg : ConfigFile
var plugin_name : String
var ui_scene : PackedScene = preload("res://addons/code_recall/ui_scene.tscn")
var ui : CodeRecallUI

var folder_path : String
var timer : Timer
var flag : bool
const height : float = 25.0
const offset : float = 25.0
const transparent : Color = Color(0.0, 0.0, 0.0, 0.0)
var highlighter : Color = Color(0.506, 0.282, 0.729, 0.376)
var project_color : Color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")

func _enter_tree():
	_enable_plugin()

func _enable_plugin():
	## UI SETUP
	cfg = ConfigFile.new()
	cfg.load("res://addons/code_recall/plugin.cfg")
	plugin_name = cfg.get_value("plugin", "name")
	ui = ui_scene.instantiate()
	ui.name = plugin_name
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, ui)
	
	ui.directory.connect(dir_change)
	ui.search.connect(search)
	ui.collapse.connect(collapse_all)
	ui.recolor.connect(recolor)
	
	timer = Timer.new()
	self.add_child(timer)
	flag = false

func _disable_plugin():
	if ui:
		remove_control_from_docks(ui)
		ui.queue_free()

func dir_change(path : String):
	remove_all()
	get_projects(path)
	ui.button_color.color = highlighter

func get_projects(path : String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					## CREATE PROJECT FOLDABLE
					var fc : FoldableContainer = FoldableContainer.new()
					ui.code_container.add_child(fc)
					fc.title = "<[   " + file_name + "   ]>"
					fc.add_theme_color_override("font_color", project_color)
					fc.add_theme_color_override("collapsed_font_color", project_color)
					fc.add_theme_color_override("hover_font_color", project_color)
					fc.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
					var vb : VBoxContainer = VBoxContainer.new()
					fc.add_child(vb)
					vb.SIZE_EXPAND_FILL
					fc.fold()
					get_scripts(full_path, vb)
					if vb.get_child_count() < 1: # Remove projects with 0 scripts
						fc.queue_free()
			file_name = dir.get_next()
		dir.list_dir_end()

func get_scripts(path : String, parent : Control):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				if file_name != "." and file_name != ".." and file_name != "addons":
					get_scripts(full_path, parent)
			elif file_name.ends_with(".gd") or file_name.ends_with(".cs") or file_name.ends_with(".gdshader"):
				## CREATE SCRIPT FOLDABLE
				var fc : FoldableContainer = FoldableContainer.new()
				parent.add_child(fc)
				fc.title = file_name
				fc.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var vb : VBoxContainer = VBoxContainer.new()
				fc.add_child(vb)
				vb.SIZE_EXPAND_FILL
				fc.fold()
				if file_name.ends_with(".gdshader"): get_code(full_path, vb)
				else: get_funcs(full_path, vb)
				if vb.get_child_count() < 1: fc.queue_free() # Remove empty scripts
			file_name = dir.get_next()
		dir.list_dir_end()

func get_funcs(file_path : String, parent : Control):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("Error while opening file: ", file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	
	var fc : FoldableContainer = null
	var vb : VBoxContainer = null
	var tf : TextEdit = null
	for line in lines:
		var trimmed : String = line.strip_edges()
		if trimmed.begins_with("func "):
			if flag: # Necessary to spot funcs with no space between
				if tf.get_line_count() > 1:
					tf.custom_minimum_size.y = offset + height * tf.get_line_count()
					fc.fold()
				else:
					fc.queue_free()
				flag = false
			var func_declaration = trimmed.substr(5)  # Removes "func "
			var paren_pos = func_declaration.find("(")
			if paren_pos != -1:
				var func_name = func_declaration.substr(0, paren_pos).strip_edges()
				## CREATE FUNC FOLDABLE
				fc = FoldableContainer.new()
				parent.add_child(fc)
				fc.title = " " + func_name
				vb = VBoxContainer.new()
				fc.add_child(vb)
				vb.SIZE_EXPAND_FILL
				## CREATE CODE AREA
				tf = TextEdit.new()
				vb.add_child(tf)
				tf.tooltip_text = "Click to copy function\nShift+Click to copy script"
				tf.highlight_all_occurrences = true
				tf.text = trimmed
				flag = true
				tf.editable = false
				tf.gui_input.connect(copy_text.bind(tf))
		elif flag: # If we find a func, we insert the following lines into the TextEdit
			if line.begins_with("\t"): # Part of the func
				if line.begins_with("\tpass"): # A pass with 1 tabspace means empty func
					flag = false
					fc.queue_free()
				else:
					tf.text += "\n" + line
			else: # Not part of the func
				if tf.text.get_slice_count("\n") > 1:
					tf.custom_minimum_size.y = offset + height * tf.get_line_count()
					fc.fold()
				else: # Empty func (really unlikely)
					fc.queue_free()
				flag = false

func get_code(file_path : String, parent : Control):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("Error while opening file: ", file_path)
		return
	
	var tf : TextEdit = TextEdit.new()
	tf.text = file.get_as_text()
	file.close()
	tf.custom_minimum_size.y = offset + height * tf.get_line_count()
	parent.add_child(tf)
	tf.tooltip_text = "Left-click copy all"
	tf.highlight_all_occurrences = true
	tf.editable = false
	tf.gui_input.connect(copy_text.bind(tf))

func copy_text(event : InputEvent, tf : TextEdit):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SHIFT) and event.pressed:
				DisplayServer.clipboard_set(tf.get_parent().tooltip_text)
			else:
				if event.pressed:
					if tf.text[0] == "f":
						flag = true
						timer.start(0.2)
						await timer.timeout
						flag = false
				else:
					if flag and tf.text[0] == "f":
						if timer.time_left > 0.0:
							timer.stop()
							timer.timeout.emit()
						DisplayServer.clipboard_set(tf.text)
						tf.select_all()
						await get_tree().create_timer(0.2).timeout
						tf.deselect()

func search(text : String):
	# Reset search by default, unhighlighting is done in show_all()
	show_all()
	collapse_all()
	if text != "":
		hide_all()
		search_code(ui.code_container, text)

func search2(text : String):
	# Reset search by default, unhighlighting is done in show_all()
	show_all()
	collapse_all()
	if text == "": return
	expand_all()
	search_code2(ui.code_container, text)

func search_code2(node : Control, text : String):
	for child in node.get_children():
		if child is TextEdit:
			if child.text.containsn(text): ## TODO what did I do here fml
				# Expand Project Foldable
				child.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().visible = true
				child.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().expand()
				# Expand Script Foldable
				child.get_parent().get_parent().get_parent().get_parent().visible = true
				child.get_parent().get_parent().get_parent().get_parent().expand()
				# Expand Code Foldable
				child.get_parent().get_parent().visible = true
				child.get_parent().get_parent().expand()
				# Highlight Text
				highlight_code(child, text)
		else:
			search_code(child, text)

func search_code(node : Control, text : String):
	for child in node.get_children():
		if child is TextEdit:
			if child.text.containsn(text):
				# Expand Project Foldable
				child.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().visible = true
				child.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().expand()
				# Expand Script Foldable
				child.get_parent().get_parent().get_parent().get_parent().visible = true
				child.get_parent().get_parent().get_parent().get_parent().expand()
				# Expand Code Foldable
				child.get_parent().get_parent().visible = true
				child.get_parent().get_parent().expand()
				# Highlight Text
				highlight_code(child, text)
		else:
			search_code(child, text)

func highlight_code(tf : TextEdit, text : String = ""):
	# Default case is unhighlighting
	if text == "":
		for l in tf.get_line_count():
			tf.set_line_background_color(l, transparent)
		return
	# Text highlighting
	var pos : int = 0
	var pos_new : int = 0
	var line : int = 0
	while true:
		pos_new = tf.text.substr(pos).findn(text)
		if pos_new == -1:
			return
		pos += pos_new
		line = tf.text.substr(0, pos).count("\n")
		tf.set_line_background_color(line, highlighter)
		pos += text.length()

func recolor():
	highlighter = ui.button_color.color
	search_code(ui.code_container, ui.searchbar.text)

func remove_all(node : Control = ui.code_container):
	for child in node.get_children():
		remove_all(child)
		child.queue_free()

func collapse_all(node : Control = ui.code_container):
	for child in node.get_children():
		collapse_all(child)
		if child is FoldableContainer:
			child.fold()

func expand_all(node : Control = ui.code_container):
	for child in node.get_children():
		collapse_all(child)
		if child is FoldableContainer:
			child.expand()

func hide_all(node : Control = ui.code_container):
	for child in node.get_children():
		hide_all(child)
		if child is FoldableContainer:
			child.visible = false

func show_all(node : Control = ui.code_container):
	for child in node.get_children():
		show_all(child)
		if child is FoldableContainer:
			child.visible = true
		elif child is TextEdit:
			# Search Unhighlighting
			highlight_code(child)
