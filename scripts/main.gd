extends Control

@onready var start: Button = %Start
@onready var stop: Button = %Stop
@onready var recording_state: TextureRect = %RecordingState
@onready var configs: LinkButton = %Configs
@onready var exit: LinkButton = %Exit
@onready var output: LinkButton = %Output
@onready var always_on_top: CheckButton = %AlwaysOnTop
@onready var reload: LinkButton = %Reload

var window = Window.new()
var dir_data = OS.get_data_dir()
var dir_user_data = OS.get_user_data_dir()	
var dir_editor = ProjectSettings.globalize_path("res://")
var dir_user = ProjectSettings.globalize_path("user://")
var path_file_config = ProjectSettings.globalize_path("user://configs.cfg")
var path_file_setup = ProjectSettings.globalize_path("user://SETUP.md")

var configs_dict = {}
var datetime = ""

var pid_shell = -1

var not_rec = preload("res://icons/not-rec.svg")
var rec = preload("res://icons/rec.svg")
var stop_rec = preload("res://icons/stop-rec.svg")
var pause_rec = preload("res://icons/pause-rec.svg")

var command = \
"""
_date=$(date +"%Y-%m-%d_%H-%M-%S")\n
ffmpeg -f pulse -i {id} "{save_location}/{file_name}_$_date.{extension}"
"""

var setup_text = """Welcome in souon!
In this file you'll found all the information necessary to setup souon.

a. Dependencies
Make sure to have installed the following softwares: ffmpeg and pipewire or pulseaudio.

ffmpeg, to be able to record, needs a device from which capturing an audio stream.
aa. If you have PulseAudio `pactl list short sinks` lists a short versions of the device available. Copy the id of your main source (the first number).
ab. If you have PipeWire `pw-cli` throws you into a REPL, where the command `list-objects` let you see all the available objects. Somewhere will be your main source.
Copy the object serial.

b. Configuration file location
$HOME/.local/share/godot/app_userdata/souon/config.cfg
`cd $HOME/.local/share/godot/app_userdata/souon/`

ba. configs section
`shell path`: the absolute path to the shell that'll be used to execute the script
(default: /bin/bash)
`id`: the id of the device from which ffmpeg will record the audio stream
(default: -1)
`save_location`: the location existent where you want to save the file
(default: /home/USERNAME/Music)
`file_name`: the name of the file that will prepend the date and time values
(default: output)
`extension`: the extension of the file 
(default: wav)

bb. ui section
`always_on_top`: determines if the window will stay on top of every other window or will succumb
(default: true)

c.
Troubleshooting
ca. Check the dependencies list in the a section
cb. If you click on Recording and is opened the configuration directory, check if the `id` value is correctly set.
Should be greater or equal than 0.
"""

func _ready() -> void:
	start.disabled = false
	stop.disabled = true
	
	configs.uri = dir_user
	
	configs_dict = read_configs()
	output.uri = configs_dict["save_location"]
	always_on_top.button_pressed = configs_dict["always_on_top"]
	
	command = command.format({
		"id": configs_dict["id"],
		"save_location": configs_dict["save_location"],
		"file_name": configs_dict["file_name"],
		"extension": configs_dict["extension"]
	})
	
	if OS.get_name() == "Windows":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start_recording"):
		_on_start_pressed()
	if event.is_action_pressed("stop_recording"):
		_on_stop_pressed()
	# bug: kills the entire system sessions on endeavourOS/KDE6
	#if event.is_action_pressed("exit"):
		#var pid = OS.get_process_id()
		#OS.kill(pid)
	if event.is_action_pressed("open_configs"):
		OS.shell_open(dir_user)
		

func _on_start_pressed() -> void:
	print_debug("Starting...")
	if configs_dict["id"] < 0:
		OS.shell_open(dir_user)
		return
	recording_state.texture = rec
	start.disabled = true
	stop.disabled = false
	exit.disabled = true
	exit.underline = LinkButton.UNDERLINE_MODE_NEVER
	exit.mouse_default_cursor_shape = Control.CURSOR_ARROW
	reload.disabled = true
	reload.underline = LinkButton.UNDERLINE_MODE_NEVER
	reload.mouse_default_cursor_shape = Control.CURSOR_ARROW

	pid_shell = OS.create_process("bash", ["-c", command])
	print_debug("OK! Started")

func _on_stop_pressed() -> void:
	print_debug("Stopping...")
	recording_state.texture = not_rec
	start.disabled = false
	stop.disabled = true
	exit.disabled = false
	exit.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	exit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reload.disabled = false
	reload.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	reload.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# kills the shell and the ffmpeg child process 
	var err = OS.kill(pid_shell)
	pid_shell = -1
	datetime = ""

	if err:
		print_debug(error_string(err))
		print_debug(pid_shell)
		return
	
	# sadly is not possible to copy the raw file 
	# (for example, to paste it directly in anki)
	if not configs_dict.is_empty():
		var file_record = configs_dict["save_location"] + "/" \
		+ configs_dict["file_name"] + "_" \
		+ datetime \
		+ "." \
		+ configs_dict["extension"]
		print_debug("file record guess: ", file_record)
		
		if FileAccess.file_exists(file_record):
			DisplayServer.clipboard_set(file_record)
			print_debug("Copied")

	print_debug("OK! Stopped")

func _on_exit_pressed() -> void:
	get_tree().quit()

func make_config():
	var config = ConfigFile.new()
	config.set_value("configs", "id", -1)
	config.set_value("configs", "save_location", OS.get_system_dir(OS.SYSTEM_DIR_MUSIC))
	config.set_value("configs", "file_name", "output")
	config.set_value("configs", "extension", "wav")
	config.set_value("ui", "always_on_top", true)
	config.save("user://configs.cfg")
	
func make_setup():
	var file = FileAccess.open(path_file_setup, FileAccess.WRITE)
	file.store_string(setup_text)
	file.close()

func read_configs():
	if not FileAccess.file_exists(path_file_config):
		make_config()
	if not FileAccess.file_exists(path_file_setup):
		make_setup()
	return get_config_as_dict()

func get_config_as_dict():
	var config = ConfigFile.new()
	var data = {}
	var err = config.load(path_file_config)
	if err != OK:
		printerr("error: can't load config file")
		return
	data["id"] = config.get_value("configs", "id", -1)
	data["save_location"] = config.get_value("configs", "save_location", OS.get_system_dir(OS.SYSTEM_DIR_MUSIC))
	data["file_name"] = config.get_value("configs", "file_name", "output")
	data["extension"] = config.get_value("configs", "extension", "aac")
	data["always_on_top"] = config.get_value("ui", "always_on_top", true)
	return data

func _on_always_on_top_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, toggled_on)

func _on_reload_pressed() -> void:
	_ready()

func _on_github_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouse: return
	if not event.is_pressed(): return
	if not event.button_index == MOUSE_BUTTON_LEFT: return
	OS.shell_open("github.com/plucafs/souon")
