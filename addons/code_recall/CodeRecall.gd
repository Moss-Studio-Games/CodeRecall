@tool
class_name CodeRecall
extends EditorPlugin

var cfg : ConfigFile
var plugin_name : String
var ui_scene : PackedScene = preload("res://addons/code_recall/ui_scene.tscn")
var ui : CodeRecallUI

var folder_path : String
var timer : Timer
const height : float = 25.0
const offset : float = 25.0

var dict : Dictionary = {".gd": false, ".cs": false, ".gdshader": false}

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
	ui.filter.connect(filter)
	ui.collapse.connect(collapse_all)
	ui.recolor.connect(recolor)
	
	timer = Timer.new()
	self.add_child(timer)

func _disable_plugin():
	if ui:
		remove_control_from_docks(ui)
		ui.queue_free()

func dir_change(path : String):
	if path == "": path = folder_path
	else: folder_path = path
	remove_all()
	if dict.get(".gd") or dict.get(".cs") or dict.get(".gdshader"): get_projects(path)

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
					var project_color : Color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")
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
	if !dir: return
	dir.list_dir_begin() # Open dir
	var file_name = dir.get_next() # First file
	while file_name != "": # After last file file_name is empty
		var full_path = path.path_join(file_name) # Build full path
		if dir.current_is_dir(): # Check if it is a folder
			if file_name != "." and file_name != ".." and file_name != "addons":
				get_scripts(full_path, parent)
		# If not a folder, check for wanted file types
		elif (dict.get(".gd") and file_name.ends_with(".gd")) or (dict.get(".cs") and file_name.ends_with(".cs")) or (dict.get(".gdshader") and file_name.ends_with(".gdshader")):
			## CREATE SCRIPT FOLDABLE
			var fc : FoldableContainer = FoldableContainer.new()
			parent.add_child(fc)
			fc.title = file_name
			fc.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var vb : VBoxContainer = VBoxContainer.new()
			fc.add_child(vb)
			vb.SIZE_EXPAND_FILL
			fc.fold()
			if file_name.ends_with(".gd"): get_gd_funcs(full_path, vb)
			elif file_name.ends_with(".cs"): get_cs_funcs(full_path, vb)
			elif file_name.ends_with(".gdshader"): get_gdshader(full_path, vb)
			if vb.get_child_count() < 1: fc.queue_free() # Remove empty scripts
		file_name = dir.get_next() # Next file
	dir.list_dir_end() # Close dir

func get_gd_funcs(file_path : String, parent : Control):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file: printerr("Error while opening file: ", file_path)
	var content = file.get_as_text()
	file.close()
	var lines = content.split("\n")
	
	var fc : FoldableContainer = null
	var vb : VBoxContainer = null
	var tf : TextEdit = null
	var flag : bool = false
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
			var func_declaration : String = trimmed.substr(5)  # Removes "func "
			var paren_pos : int = func_declaration.find("(")
			if paren_pos == -1: continue
			var func_name : String = func_declaration.substr(0, paren_pos).strip_edges()
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

func get_cs_funcs(file_path : String, parent : Control):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file: printerr("Error while opening file: ", file_path)
	var content = file.get_as_text()
	file.close()
	var lines = content.split("\n")
	
	var fc : FoldableContainer = null
	var vb : VBoxContainer = null
	var tf : TextEdit = null
	var flag : bool = false
	for line in lines:
		var trimmed : String = line.strip_edges()
		if trimmed.begins_with("public ") or trimmed.begins_with("private "):
			if flag: # Necessary to spot funcs with no space between
				if tf.get_line_count() > 1:
					tf.custom_minimum_size.y = offset + height * tf.get_line_count()
					fc.fold()
				else:
					fc.queue_free()
				flag = false
			if trimmed.ends_with(";"): continue
			var paren_pos : int = trimmed.find("(")
			if paren_pos == -1: continue
			var last_space_pos : int = -1
			var next_space_pos : int = -1
			while(true):
				next_space_pos = trimmed.find(" ", last_space_pos + 1)
				if (next_space_pos == -1) or (next_space_pos > paren_pos):
					break
				else: last_space_pos = next_space_pos
			var func_name : String = trimmed.substr(last_space_pos, paren_pos-last_space_pos)
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
			if !trimmed.begins_with("}"): 
				tf.text += "\n" + line
			else: # End of the func
				tf.text += "\n" + line
				if tf.text.get_slice_count("\n") > 1:
					tf.custom_minimum_size.y = offset + height * tf.get_line_count()
					fc.fold()
				else: # Empty func (really unlikely)
					fc.queue_free()
				flag = false

func get_gdshader(file_path : String, parent : Control):
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
	var flag : bool = false
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
	if text == "": return
	hide_all()
	search_code(ui.code_container, text)

func search2(text : String):
	# Reset search by default, unhighlighting is done in show_all()
	show_all()
	if text == "":
		collapse_all()
		return
	expand_all()
	for child in ui.code_container.get_children(): # Search in each project
		search_code2(child, text)
	collapse_empty(ui.code_container)

func search_code2(node : Control, text : String) -> bool:
	return 0
	var count : int = 0
	if node is VBoxContainer:
		var first : Control = node.get_child(0)
		if first is TextEdit:
			if first.text.containsn(text):
				highlight_code(first, text)
				return 1
			else: return 0
			return true
		elif first is FoldableContainer:
			for child in node.get_children():
				search_code2(child.get_child(0), text)
			for child in node.get_children():
				if child.visible:
					return true
		else: printerr("Error1")
	elif node is FoldableContainer:
		search_code2(node.get_child(0), text)
	else: printerr("Error2")

func collapse_empty(node : Control) -> bool:
	var any : bool = false
	for child in node.get_children():
		if child is VBoxContainer:
			
			if child.visible: collapse_empty(child)
			if child.visible: any = true
		elif child is TextEdit:
			if child.visible: any = true
		else:
			collapse_empty(child)
			if child.visible: any = true
	return any

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
			tf.set_line_background_color(l, 0)
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
		tf.set_line_background_color(line, ui.button_color.color)
		pos += text.length()

func recolor():
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

func filter(dictionary : Dictionary):
	dict.assign(dictionary)
	if !ui.button_dir.visible:
		dir_change("")
