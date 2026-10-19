@tool
class_name CodeRecall
extends EditorPlugin

var cfg : ConfigFile
var plugin_name : String
var ui_scene : PackedScene = preload("res://addons/code_recall/ui_scene.tscn")
var ui : CodeRecallUI

var folder_path : String
var click_timer : Timer
const height : float = 25.0
const offset : float = 25.0

var dict : Dictionary = {".gd": false, ".cs": false, ".gdshader": false}
var flag : bool = false

func _enable_plugin():
	## UI SETUP
	cfg = ConfigFile.new()
	cfg.load("res://addons/code_recall/plugin.cfg")
	plugin_name = cfg.get_value("plugin", "name")
	ui = ui_scene.instantiate()
	ui.name = plugin_name
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, ui)
	
	ui.directory.connect(dir_change)
	ui.search.connect(search_start)
	ui.filter.connect(filter)
	ui.collapse.connect(for_all.bind(120))
	ui.recolor.connect(recolor)
	
	click_timer = Timer.new()
	self.add_child(click_timer)

func _disable_plugin():
	if ui:
		remove_control_from_docks(ui)
		ui.queue_free()

func dir_change(path : String):
	if path != "": folder_path = path
	for_all(0) # remove all
	if dict.get(".gd") or dict.get(".cs") or dict.get(".gdshader"): get_projects()

func get_code(): ## TODO
	var dir = DirAccess.open(folder_path)
	if !dir: printerr("Error while opening path: " + folder_path)
	dir.list_dir_begin()
	var f_name = dir.get_next() # File name
	while f_name != "":
		if dir.current_is_dir():
			if f_name != "." and f_name != "..":
				## CREATE PROJECT FOLDABLE
				var fc : FoldableContainer = FoldableContainer.new()
				ui.code_container.add_child(fc)
				fc.title = "<[   " + f_name + "   ]>"
				var project_color : Color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")
				fc.add_theme_color_override("font_color", project_color)
				fc.add_theme_color_override("collapsed_font_color", project_color)
				fc.add_theme_color_override("hover_font_color", project_color)
				fc.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var vb : VBoxContainer = VBoxContainer.new()
				fc.add_child(vb)
				vb.SIZE_EXPAND_FILL
				fc.fold()
				get_scripts(folder_path.path_join(f_name), vb)
				if vb.get_child_count() < 1: fc.queue_free() # Projects with 0 scripts
		f_name = dir.get_next()
	dir.list_dir_end()

func get_projects():
	var dir = DirAccess.open(folder_path)
	if !dir: printerr("Error while opening path: " + folder_path)
	dir.list_dir_begin()
	var f_name = dir.get_next() # File name
	while f_name != "":
		if dir.current_is_dir():
			if f_name != "." and f_name != "..":
				var fc : FoldableContainer = FoldableContainer.new() # Project fc
				ui.code_container.add_child(fc)
				fc.title = "<[   " + f_name + "   ]>"
				var project_color : Color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")
				fc.add_theme_color_override("font_color", project_color)
				fc.add_theme_color_override("collapsed_font_color", project_color)
				fc.add_theme_color_override("hover_font_color", project_color)
				fc.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var vb : VBoxContainer = VBoxContainer.new()
				fc.add_child(vb)
				vb.SIZE_EXPAND_FILL
				fc.fold()
				get_scripts(folder_path.path_join(f_name), vb)
				if vb.get_child_count() < 1: fc.queue_free() # Projects with 0 scripts
		f_name = dir.get_next()
	dir.list_dir_end()

func get_scripts(path : String, parent : Control):
	var dir = DirAccess.open(path)
	if !dir: printerr("Error while opening path: " + path)
	dir.list_dir_begin() # Open dir
	var f_name = dir.get_next() # First file
	while f_name != "": # After last file f_name is empty
		var full_path = path.path_join(f_name) # Build full path
		if dir.current_is_dir(): # Check if it is a folder
			if f_name != "." and f_name != ".." and f_name != "addons": get_scripts(full_path, parent)
		elif (dict.get(".gd") and f_name.ends_with(".gd")) or (dict.get(".cs") and f_name.ends_with(".cs")) or (dict.get(".gdshader") and f_name.ends_with(".gdshader")):
			## CREATE SCRIPT FOLDABLE
			var fc : FoldableContainer = FoldableContainer.new()
			parent.add_child(fc)
			fc.title = f_name
			fc.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var vb : VBoxContainer = VBoxContainer.new()
			fc.add_child(vb)
			vb.SIZE_EXPAND_FILL
			fc.fold()
			if f_name.ends_with(".gd"): get_gd_funcs(full_path, vb)
			elif f_name.ends_with(".cs"): get_cs_funcs(full_path, vb)
			elif f_name.ends_with(".gdshader"): get_gdshader(full_path, vb)
			if vb.get_child_count() < 1: fc.queue_free() # Remove empty scripts
		f_name = dir.get_next() # Next file
	dir.list_dir_end() # Close dir

func get_gd_funcs(file_path : String, parent : Control): # Get all funcs in a script.cs
	var file = FileAccess.open(file_path, FileAccess.READ)
	if !file: printerr("Error while opening file: " + file_path)
	var content = file.get_as_text()
	file.close()
	var lines = content.split("\n")
	var fc : FoldableContainer = null
	var vb : VBoxContainer = null
	var te : TextEdit = null
	var flag : bool = false
	for line in lines:
		var trimmed : String = line.strip_edges()
		if trimmed.begins_with("func "):
			if flag: # For funcs with no space between
				if te.get_line_count() > 1:
					te.custom_minimum_size.y = offset + height * te.get_line_count()
					fc.fold()
				else: fc.queue_free()
				flag = false
			var func_declaration : String = trimmed.substr(5)  # Removes "func "
			var paren_pos : int = func_declaration.find("(")
			if paren_pos == -1: continue
			fc = FoldableContainer.new() # Func fc
			parent.add_child(fc)
			fc.title = " " + func_declaration.substr(0, paren_pos).strip_edges()
			vb = VBoxContainer.new()
			fc.add_child(vb)
			vb.SIZE_EXPAND_FILL
			vb.tooltip_text = content
			te = TextEdit.new()
			vb.add_child(te)
			te.tooltip_text = "Ctrl+Click: copy function\nShift+Click: copy script"
			te.highlight_all_occurrences = true
			te.text = trimmed
			flag = true
			te.editable = false
			te.gui_input.connect(text_click.bind(te))
		elif flag: # If we find a func, we insert the following lines into the TextEdit
			if line.begins_with("\t"): # Part of the func
				if line.begins_with("\tpass"): # A pass with 1 tabspace means empty func
					flag = false
					fc.queue_free()
				else: te.text += "\n" + line
			else: # Not part of the func
				if te.text.get_slice_count("\n") > 1:
					te.custom_minimum_size.y = offset + height * te.get_line_count()
					fc.fold()
				else: fc.queue_free() # Empty func (really unlikely)
				flag = false

func get_cs_funcs(file_path : String, parent : Control): # Get all funcs in a script.cs
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file: printerr("Error while opening file: ", file_path)
	var content = file.get_as_text()
	file.close()
	var lines = content.split("\n")
	var fc : FoldableContainer = null
	var vb : VBoxContainer = null
	var te : TextEdit = null
	var flag : bool = false
	for line in lines:
		var trimmed : String = line.strip_edges()
		if trimmed.begins_with("public ") or trimmed.begins_with("private "):
			if flag: # For funcs with no space between
				if te.get_line_count() > 1:
					te.custom_minimum_size.y = offset + height * te.get_line_count()
					fc.fold()
				else: fc.queue_free()
				flag = false
			if trimmed.ends_with(";"): continue
			var paren_pos : int = trimmed.find("(")
			if paren_pos == -1: continue
			var last_space_pos : int = -1
			var next_space_pos : int = -1
			while(true):
				next_space_pos = trimmed.find(" ", last_space_pos + 1)
				if (next_space_pos == -1) or (next_space_pos > paren_pos): break
				else: last_space_pos = next_space_pos
			fc = FoldableContainer.new() # Func fc
			parent.add_child(fc)
			fc.title = " " + trimmed.substr(last_space_pos, paren_pos-last_space_pos)
			vb = VBoxContainer.new()
			fc.add_child(vb)
			vb.SIZE_EXPAND_FILL
			vb.tooltip_text = content
			te = TextEdit.new()
			vb.add_child(te)
			te.tooltip_text = "How to copy:\n1) Drag left click, Ctrl+c\n2) Click (whole function)\n3) Shift+Click (whole script)"
			te.highlight_all_occurrences = true
			te.text = trimmed
			flag = true
			te.editable = false
			te.gui_input.connect(text_click.bind(te))
		elif flag: # In func
			if !trimmed.begins_with("}"): te.text += "\n" + line # Insert line into te
			else: # End of the func
				te.text += "\n" + line
				if te.text.get_slice_count("\n") > 1:
					te.custom_minimum_size.y = offset + height * te.get_line_count()
					fc.fold()
				else: # Empty func (unlikely)
					te.queue_free()
					vb.queue_free()
					fc.queue_free()
				flag = false

func get_gdshader(file_path : String, parent : Control): # Get whole script.gdshader
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file: printerr("Error while opening file: ", file_path)
	var te : TextEdit = TextEdit.new()
	te.text = file.get_as_text()
	file.close()
	te.custom_minimum_size.y = offset + height * te.get_line_count()
	parent.add_child(te)
	te.tooltip_text = "Left-click copy all"
	te.highlight_all_occurrences = true
	te.editable = false
	te.gui_input.connect(text_click.bind(te))

func text_click(event : InputEvent, te : TextEdit):
	if event is not InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if Input.is_key_pressed(KEY_SHIFT) and event.pressed:
		DisplayServer.clipboard_set(te.get_parent().tooltip_text) # Copy whole script (stored in VB.tooltip_text
		display_text(event, "Script copied!")
	else:
		if event.pressed:
			if flag: return
			flag = true
			click_timer.start(0.2)
			await click_timer.timeout
			flag = false
		else:
			if !flag: return
			if click_timer.time_left > 0.0:
				click_timer.stop()
				click_timer.timeout.emit()
			DisplayServer.clipboard_set(te.text) # Copy whole func
			display_text(event, "Func copied!")

func search_start(text : String):
	for_all(110) # show all, collapsed
	if text == "": return
	for_all(100) # hide all
	search_code(ui.code_container, text)

func search_code(node : Control, text : String): ## TODO for gdshader
	for child in node.get_children():
		if child is TextEdit:
			highlight_code(child)
			if text != "" and child.text.containsn(text):
				highlight_code(child, text)
				var fc : Control = child
				while(true): # Show TextEdit by making parents visible
					fc = fc.get_parent().get_parent()
					if fc.visible: break
					fc.visible = true
					if fc.title.begins_with("<"): break
		else: search_code(child, text)

func highlight_code(te : TextEdit, text : String = ""):
	if text == "": # Remove highlight
		for l in te.get_line_count(): te.set_line_background_color(l, 0)
		return
	var pos : int = 0
	var pos_new : int = 0
	var line : int = 0
	while true:
		pos_new = te.text.substr(pos).findn(text)
		if pos_new == -1: return
		pos += pos_new
		line = te.text.substr(0, pos).count("\n")
		te.set_line_background_color(line, ui.button_color.color)
		pos += text.length()

func recolor():
	search_code(ui.code_container, ui.searchbar.text)

# i's digits actions > 1st = !delete, 2nd = visible, 3rd = expanded
# i's digits values  > '0' = false, '1' = true, '2' = do nothing
func for_all(i : int = 110, node : Control = ui.code_container):
	for child in node.get_children():
		for_all(i, child)
		if i/100 == 0: child.queue_free()
		elif child is FoldableContainer:
			var j : int = i - 100
			if !(j/10 == 2): child.visible = (j/10 == 1)
			j -= 10 * j/10
			if j != 2: child.folded = j == 0

func filter(dictionary : Dictionary):
	#for key in dict:
		#if dict.get(key) != dictionary.get(key):
			#if dictionary.get(key):
				## get new scripts
			#else:
				## remove old scripts
	dict.assign(dictionary)
	if !ui.button_dir.visible: dir_change("")

func display_text(event : InputEvent, text : String, time : float = 0.4):
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeDB.get_default_theme().get_stylebox("panel", "TooltipPanel"))
	panel.position = get_viewport().get_mouse_position()
	add_child(panel)
	var label : Label = Label.new()
	label.text = text
	panel.add_child(label)
	await get_tree().create_timer(time).timeout
	label.queue_free()
	panel.queue_free()
