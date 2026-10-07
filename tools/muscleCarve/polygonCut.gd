### /// POLYGON CUTTER ///
# headless helper for carve.py - reads cut jobs from json - writes the pieces back as json
# each job is one source polygon plus an ordered list of zones - every zone takes the part
# of what is left that falls inside it - whatever remains after the last zone is the remainder
# run: godot --headless --path <project> --script res://tools/muscleCarve/polygonCut.gd -- jobs.json results.json

extends SceneTree


func _initialize() -> void:
	### READ JOBS - CUT - WRITE RESULTS

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var jobs: Variant = null
	var results: Dictionary = {}

	# input
	if args.size() < 2:
		push_error("polygonCut needs: jobsPath resultsPath")
		quit(2)
		return
	var jobsText: String = FileAccess.get_file_as_string(args[0])
	jobs = JSON.parse_string(jobsText)
	if jobs == null:
		push_error("polygonCut could not parse " + args[0])
		quit(3)
		return

	# every job - cut zone by zone - or fuse several pieces into one
	for job in jobs["jobs"]:
		if job["kind"] == "fuse":
			results[job["id"]] = _fuseJob(job)
		else:
			results[job["id"]] = _cutJob(job)

	# output
	var outFile: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	outFile.store_string(JSON.stringify({"results": results}))
	outFile.close()
	print("polygonCut: ", results.size(), " jobs cut")
	quit(0)


func _cutJob(job: Dictionary) -> Array:
	### ONE SOURCE POLYGON THROUGH ITS ZONES IN ORDER

	var remaining: Array = [_toPacked(job["subject"])]
	var outputs: Array = []
	var halfGap: float = float(job["gap"]) * 0.5

	# the zone shrunk by half the gap takes its piece - the zone grown by half the gap is cut
	# out of the rest - so a dark seam as wide as the gap opens along every cut
	for zone in job["zones"]:
		var zonePacked: PackedVector2Array = _toPacked(zone)
		var zoneInner: Array = Geometry2D.offset_polygon(zonePacked, -halfGap, Geometry2D.JOIN_MITER)
		var zoneOuter: Array = Geometry2D.offset_polygon(zonePacked, halfGap, Geometry2D.JOIN_MITER)
		var taken: Array = []
		var stillLeft: Array = []
		if zoneInner.size() != 1 or zoneOuter.size() != 1:
			push_error("zone offset did not give one polygon in job " + str(job["id"]))
			quit(4)
		for polygon in remaining:
			for piece in Geometry2D.intersect_polygons(polygon, zoneInner[0]):
				taken.append(piece)
			for piece in Geometry2D.clip_polygons(polygon, zoneOuter[0]):
				stillLeft.append(piece)
		outputs.append(_toPlain(taken))
		remaining = stillLeft

	outputs.append(_toPlain(remaining))
	return outputs


func _fuseJob(job: Dictionary) -> Array:
	### MERGE NEIGHBOURING PIECES INTO ONE SHAPE

	var radius: float = float(job["radius"])
	var merged: PackedVector2Array = PackedVector2Array()

	# grow every piece by the radius so the gaps between them close - merge them -
	# then shrink back by the same radius so the outer outline returns to where it was
	for subject in job["subjects"]:
		var grown: Array = Geometry2D.offset_polygon(_toPacked(subject), radius, Geometry2D.JOIN_ROUND)
		if grown.size() != 1:
			push_error("fuse grow did not give one polygon in job " + str(job["id"]))
			quit(5)
		if merged.size() == 0:
			merged = grown[0]
		else:
			var joined: Array = Geometry2D.merge_polygons(merged, grown[0])
			if joined.size() != 1:
				push_error("fuse pieces do not touch in job " + str(job["id"]) + " - raise the radius")
				quit(6)
			merged = joined[0]

	var shrunk: Array = Geometry2D.offset_polygon(merged, -radius, Geometry2D.JOIN_MITER)
	return [_toPlain(shrunk)]


func _toPacked(points: Array) -> PackedVector2Array:
	# json [[x, y], ...] to a packed polygon
	var packed: PackedVector2Array = PackedVector2Array()
	for point in points:
		packed.append(Vector2(point[0], point[1]))
	return packed


func _toPlain(pieces: Array) -> Array:
	# packed polygons back to json lists - each with its winding so holes can be caught
	var plain: Array = []
	for piece in pieces:
		var points: Array = []
		for point in piece:
			points.append([snappedf(point.x, 0.01), snappedf(point.y, 0.01)])
		plain.append({"clockwise": Geometry2D.is_polygon_clockwise(piece), "points": points})
	return plain
