extends Node
## Hub navigation singleton (autoload GameRouter).
## Owns hub landing state and the transition in/out of any game.
## Contract (see CONSTITUTION 一): games return via back_to_hub();
## hub never reaches into a game's internals.

const HUB_SCENE := "res://00-hub/hub.tscn"

## Where hub should land when (re)built: "title" | "grid".
var landing := "title"
## Vertical scroll offset of the grid, restored after returning from a game.
var grid_scroll := 0


## Change scene into a game. dir_name is the full game folder, e.g. "99-demo";
## the main scene is assumed at res://<dir>/<dir-without-NN->.tscn.
func enter_game(dir_name: String) -> void:
	landing = "grid"
	var path := "res://%s/%s.tscn" % [dir_name, dir_name.substr(3)]
	if not ResourceLoader.exists(path):
		push_error("GameRouter: main scene missing for %s (%s)" % [dir_name, path])
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameRouter: failed to enter %s (%s)" % [path, error_string(err)])


func back_to_hub() -> void:
	var err := get_tree().change_scene_to_file(HUB_SCENE)
	if err != OK:
		push_error("GameRouter: failed to return to hub (%s)" % error_string(err))


func quit_app() -> void:
	get_tree().quit()
