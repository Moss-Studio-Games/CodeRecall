@tool
class_name CodeRecallUI
extends Control

@onready var button_dir : Button = $VBox/HBox/ButtonDir
@onready var searchbar : LineEdit = $VBox/HBox/Searchbar
@onready var button_coll : Button = $VBox/HBox/ButtonColl
@onready var button_dir_2 : Button = $VBox/HBox/ButtonDir2
@onready var button_color : ColorPickerButton = $VBox/HBox/ButtonColor

@onready var folder_path : FileDialog = $VBox/FolderPath
@onready var scroll_container : ScrollContainer = $VBox/ScrollContainer
@onready var code_container : VBoxContainer = $VBox/ScrollContainer/VBox

signal search(text : String)
signal directory(text : String)
signal collapse()
signal recolor()

func _ready():
	button_dir.pressed.connect(on_dir_pressed)
	
	searchbar.right_icon = get_theme_icon("Search", "EditorIcons")
	searchbar.text_changed.connect(check_text)
	searchbar.text_submitted.connect(emit_search)
	
	button_coll.icon = get_theme_icon("CombineLines", "EditorIcons")
	button_coll.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_coll.tooltip_text = "Collapse all"
	button_coll.pressed.connect(emit_collapse)
	
	button_dir_2.icon = get_theme_icon("Folder", "EditorIcons")
	button_dir_2.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_dir_2.tooltip_text = "Change directory"
	button_dir_2.pressed.connect(on_dir_pressed)
	
	button_color.tooltip_text = "Highlight color"
	button_color.popup_closed.connect(emit_recolor)
	
	folder_path.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_path.access = FileDialog.ACCESS_FILESYSTEM
	folder_path.title = "Select your projects folder"
	folder_path.ok_button_text = "Confirm"
	folder_path.dir_selected.connect(on_directory_selected)

func on_dir_pressed():
	folder_path.popup_centered(Vector2i(800, 600))

func on_directory_selected(dir_path: String):
	directory.emit(dir_path)
	button_dir.visible = false
	searchbar.visible = true
	button_coll.visible = true
	button_dir_2.visible = true
	button_color.visible = true
	scroll_container.visible = true

func check_text(text : String):
	if text == "":
		emit_search("")

func emit_search(text : String):
	search.emit(text)

func emit_collapse():
	collapse.emit()

func emit_recolor():
	recolor.emit()
