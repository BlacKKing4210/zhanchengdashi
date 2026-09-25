extends "res://tests/test_home_readability.gd"
## Regression companion to the separately frozen network-failure reproducer.

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-stage="): stage = arg.trim_prefix("--evidence-stage=")
	GameAudio.sfx_enabled = false
	GameAudio.set_music_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + stage))
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	add_child(viewport)
	app = TestApp.new()
	viewport.add_child(app)
	await get_tree().process_frame
	app.set_process(false)
	for failure in ["storage_error", "request_timeout", "request_failed", "home_unavailable"]:
		app.home_view.available = true
		app.home_view.snapshot.can_claim = true
		check(app.home_view.has_dot(), failure + "_initial_dot")
		app._home_operation_failed(failure)
		check(app.home_view.has_dot(), failure + "_keeps_claimable_dot", {"available": app.home_view.available, "can_claim": app.home_view.snapshot.can_claim})
	var result = {"stage": stage, "label": "supplemental integration logic, not native network transport", "checks": checks, "failures": failures, "home_hash": FileAccess.get_sha256("res://scripts/app/ui/home_view.gd"), "main_hash": FileAccess.get_sha256("res://scripts/app/main.gd"), "probe_hash": FileAccess.get_sha256(get_script().resource_path)}
	var file = FileAccess.open(OUT + stage + "/claim-failure-regression-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	app.queue_free()
	await get_tree().process_frame
	print("HOME_CLAIM_FAILURE checks=%d failures=%d" % [checks.size(), failures])
	get_tree().quit(1 if failures else 0)
