@tool
class_name CodeRecallUI
extends Control

@onready var button_alert : Button = $VBox/HBox/ButtonAlert
@onready var button_dir : Button = $VBox/HBox/ButtonDir
@onready var searchbar : LineEdit = $VBox/HBox/Searchbar
@onready var button_coll : Button = $VBox/HBox/ButtonColl
@onready var button_filter : Button = $VBox/HBox/ButtonFilter
@onready var button_dir_2 : Button = $VBox/HBox/ButtonDir2
@onready var button_color : ColorPickerButton = $VBox/HBox/ButtonColor
@onready var filter_options : MarginContainer = $VBox/FilterOptions
@onready var folder_path : FileDialog = $VBox/FolderPath
@onready var scroll_container : ScrollContainer = $VBox/ScrollContainer
@onready var code_container : VBoxContainer = $VBox/ScrollContainer/VBox
@onready var check_box_gd : CheckBox = $VBox/FilterOptions/HBox/HBox1/CheckBox
@onready var check_box_cs : CheckBox = $VBox/FilterOptions/HBox/HBox2/CheckBox
@onready var check_box_gdshader : CheckBox = $VBox/FilterOptions/HBox/HBox3/CheckBox

var dict : Dictionary = {".gd": false, ".cs": false, ".gdshader": false}

signal search(text : String)
signal collapse()
signal filter(dict)
signal directory(text : String)
signal recolor()

func _ready():
	button_alert.icon = get_theme_icon("Timer", "EditorIcons")
	button_alert.tooltip_text = "Loading, please wait!"
	button_alert.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	button_dir.pressed.connect(on_dir_pressed)
	
	searchbar.right_icon = get_theme_icon("Search", "EditorIcons")
	searchbar.text_changed.connect(check_text)
	searchbar.text_submitted.connect(emit_search)
	
	button_coll.icon = get_theme_icon("CombineLines", "EditorIcons")
	button_coll.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_coll.tooltip_text = "Collapse all"
	button_coll.pressed.connect(emit_collapse)
	
	button_filter.icon = get_theme_icon("AnimationFilter", "EditorIcons")
	button_filter.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_filter.tooltip_text = "Filter files"
	button_filter.pressed.connect(toggle_filters)
	
	button_dir_2.icon = get_theme_icon("Folder", "EditorIcons")
	button_dir_2.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_dir_2.tooltip_text = "Change directory"
	button_dir_2.pressed.connect(on_dir_pressed)
	
	button_color.tooltip_text = "Highlight color"
	var ed_color : Color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")
	button_color.color = Color(ed_color.r, ed_color.g, ed_color.b, 0.376)
	button_color.popup_closed.connect(emit_recolor)
	
	folder_path.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_path.access = FileDialog.ACCESS_FILESYSTEM
	folder_path.title = "Select your projects folder"
	folder_path.ok_button_text = "Confirm"
	folder_path.dir_selected.connect(on_directory_selected)
	folder_path.visibility_changed.connect(on_folder_path_close)
	
	check_box_gd.toggled.connect(change_filter.bind(".gd"))
	check_box_cs.toggled.connect(change_filter.bind(".cs"))
	check_box_gdshader.toggled.connect(change_filter.bind(".gdshader"))

func on_dir_pressed():
	folder_path.popup_centered(Vector2i(800, 600))

func on_folder_path_close():
	button_alert.visible = folder_path.visible

func on_directory_selected(dir_path: String):
	directory.emit(dir_path)
	button_dir.visible = false
	searchbar.visible = true
	button_coll.visible = true
	button_dir_2.visible = true
	button_color.visible = true
	scroll_container.visible = true
	toggle_filters()

func toggle_filters():
	filter_options.visible = !filter_options.visible

func change_filter(t : bool, s : String):
	if !button_dir.visible:
		button_alert.visible = true
		check_box_gd.disabled = true
		check_box_cs.disabled = true
		check_box_gdshader.disabled = true
	await get_tree().create_timer(0.1).timeout
	dict.set(s, !(dict.get(s)))
	filter.emit(dict)
	if !button_dir.visible:
		button_alert.visible = false
		check_box_gd.disabled = false
		check_box_cs.disabled = false
		check_box_gdshader.disabled = false

func check_text(text : String):
	if text == "":
		emit_search("")

func emit_search(text : String):
	search.emit(text)

func emit_collapse():
	collapse.emit()

func emit_filter():
	filter.emit()

func emit_recolor():
	recolor.emit()
