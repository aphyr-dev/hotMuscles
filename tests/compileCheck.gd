extends SceneTree
## compileCheck.gd - compiles scripts inside a booted project, where autoload names exist
## what this offers: python tests/runGodot.py script res://tests/compileCheck.gd -- res://a.gd res://b.gd
## (runGodot.py parse calls it for scripts that --check-only rejects only for using autoload names)
## prints "compiled <path>" or "BROKEN <path>" per script and "COMPILE ALL OK" / "COMPILE FAILED"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var broken: int = 0
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	for path in paths:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			broken += 1
			print("BROKEN " + path)
		else:
			print("compiled " + path)
	if broken == 0 and paths.size() > 0:
		print("COMPILE ALL OK")
	else:
		print("COMPILE FAILED")
	quit(mini(broken, 1))
