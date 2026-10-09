class_name WeekScreen
extends AppScreen
## WeekScreen - home: today, the rolling week, the last 30 days or the last 12 months
## what this offers
## - header (greeting, "This week", date range, workouts, total sets) and a settings button
## - Day | Week | Month | Year: setPeriod(periodId) - remembered (homePeriod). Day = today's raw sets,
##   week = the rolling 7 days, month and year = AVERAGE sets per week (the 0-N slider is always the
##   weekly scale); each switch lights the body up again over exactly 3 s
## - body card with the period's heat (the heat gradient and 0-N slider, like the workout card; its own N)
## - Balance | Workouts tabs: showTab("balance" / "workouts")
## - openRegion(regionId) -> the region sheet (sets, band, short/over, contributions, Find exercises)
## - workouts tab: tap = openEditor(workoutId); delete with undo = deleteWorkout(workoutId);
##   saveAsTemplate(workoutId) asks for a name; long-press / "..." = the row menu
## - startWorkout(): starts one (or resumes the running one) and opens it; the button reads
##   "Resume workout · mm:ss" while one runs
## - showFinished(workout): back from a finished workout - the heat blends slowly to the new week
## - startReplay() (the app calls it on start): the body empties, then the week fills back in workout
##   by workout, oldest first, muscle by muscle from the top of the body down - each muscle flashes
##   as its heat lands, each finished workout pulses as a whole. A tap on the body, leaving the page or
##   any saved change ends it on the real week at once. replaying() says whether it runs
## - refresh(animate); shownHeat (regionId -> effective sets, per week for month/year), shownWorkouts
##   and weeksCovered (what the period's totals were divided by) hold what is shown
## - one-tap overlays under the body (remembered in overlayTargets / overlayCardio), each chip only
##   there when it has something to show:
##   Targets (a target preset is on): setTargetsOverlay(on) - the body shows each muscle's sets as a
##     share of its target (at target = the hot end; muscles with no target stay plain), the balance
##     rows use the targets, the hint counts how many are on target. regionTargets holds them
##   Cardio (once any cardio was logged): setCardioOverlay(on) - red and blue vessels over the body,
##     as bright as hard / easy cardio minutes are of their weekly target, and a cardio panel on the
##     balance tab (both lights + the WHO health line). cardioMinutes / cardioTargets hold the numbers
## - the balance tab starts with the targets line (which presets are on, Change -> the Targets screen)

### /// TUNING ///

# tallest the body gets on the week card
const bodyMaxHeight: float = 470.0
# the period chips, the page title, the body card title and the words for "when" per period (the
# replay shows its own card title while it runs)
const periodOptions: Array = [["day", "Day"], ["week", "Week"], ["month", "Month"], ["year", "Year"]]
const pageTitles: Dictionary = {"day": "Today", "week": "This week", "month": "This month", "year": "This year"}
const cardTitles: Dictionary = {"day": "Sets today", "week": "Sets this week", "month": "Sets per week · average", "year": "Sets per week · average"}
const periodWords: Dictionary = {"day": "today", "week": "in the last 7 days", "month": "in the last 30 days", "year": "in the last 12 months"}
const cardHint: String = "Tap a muscle for details · pinch to zoom"
const targetsCardTitle: String = "Sets vs targets"
# with targets on, a muscle counts as "over" past this many times its target
const targetOverShare: float = 2.0
# the research's one-line honesty note under the cardio panel
const cardioNote: String = "Colours are a code, not anatomy: every minute of cardio works the whole circulation."
# cardio panel bar height
const cardioBarHeight: float = 10.0
# seconds the heat takes to blend after finishing a workout (normal changes use BodyView's own)
const finishBlendSeconds: float = 1.8
# tiny body thumbnail on a workout row
const thumbSize: Vector2 = Vector2(78.0, 84.0)
# main button height
const mainButtonHeight: float = 58.0
# balance rows made in the same frame a fresh week fills (they cover the screen below the body),
# then rows made per frame after that until all 30 are there - all at once cost a ~50 ms frame
const firstBalanceRows: int = 4
const balanceRowsPerFrame: int = 3
# workout (and month) rows: made in the first frame, then per frame (each carries a small body)
const firstWorkoutRows: int = 4
const workoutRowsPerFrame: int = 2
# week replay on start: wait before the first muscle (the page settles), seconds per muscle at most and
# at least, pause after each workout, and the longest the whole replay may take (muscles speed up to fit)
const replayStartDelay: float = 0.45
const replayMuscleSecondsMax: float = 0.1
const replayMuscleSecondsMin: float = 0.03
const replayWorkoutPause: float = 0.35
const replayMaxSeconds: float = 4.5
# seconds a muscle's heat takes to blend in during the replay, flash strength per muscle, and of the
# whole-workout pulse at the end of each workout
const replayBlendSeconds: float = 0.25
const replayMuscleFlash: float = 1.0
const replayWorkoutFlash: float = 0.45
# switching the period: the light-up always takes exactly this long, starts after this, and pauses
# between its steps (workouts, weeks or months) at most this share of the time in total
const switchReplaySeconds: float = 3.0
const switchReplayStartDelay: float = 0.15
const switchPauseShare: float = 0.2

### /// STATE ///

var scroll: KineticScroll = null
var column: VBoxContainer = null
var greetingLabel: Label = null
var statsLabel: Label = null
var bodyCard: BodyCard = null
var tabs: Segmented = null
var balanceBox: VBoxContainer = null
var workoutsBox: VBoxContainer = null
var startButton: Button = null
var currentTab: String = "balance"
var period: String = "week"
var periodChips: Segmented = null
var pageTitle: Label = null
var shownHeat: Dictionary = {}
var shownWorkouts: Array = []
var weeksCovered: float = 1.0
var allWorkouts: Array = []
var balanceNote: Label = null
var balanceRanks: Array = []
var balanceRows: Dictionary = {}
var balancePending: bool = false
var workoutsShown: String = ""
var workoutsNote: Label = null
var workoutRows: Dictionary = {}
var workoutPlan: Array = []
var workoutsPending: bool = false
var regionSheet: BottomSheet = null
var dirty: bool = true
var normalBlendSeconds: float = 0.9
var lastClockText: String = ""
var appliedDefaultView: String = ""
var replaySteps: Array = []
var replayClock: float = 0.0
var replayHeat: Dictionary = {}
var targetsChip: Button = null
var cardioChip: Button = null
var regionTargets: Dictionary = {}
var cardioMinutes: Dictionary = {}
var cardioTargets: Dictionary = {}
var cardioLogged: bool = false
var targetsLine: HBoxContainer = null
var targetsText: Label = null
var cardioPanel: PanelContainer = null
var cardioBox: VBoxContainer = null
var writingOverlay: bool = false


func _ready() -> void:
	_build()
	Storage.changed.connect(_onStorageChanged)
	refresh(false)


### /// BUILDING ///

func _build() -> void:
	### WHAT THIS DOES
	# one scrolling page (header, body card, tabs, rows) over a fixed start button

	var page := PanelContainer.new()
	page.theme_type_variation = "BackgroundPanel"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout: VBoxContainer = Ui.vbox(0)
	page.add_child(layout)

	scroll = KineticScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	column = Ui.vbox(pageGap)
	scroll.add_child(Ui.margin(column, pagePad, 14, pagePad, 24))

	# header
	var header: HBoxContainer = Ui.hbox(8)
	column.add_child(header)
	var titles: VBoxContainer = Ui.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	period = str(Storage.settings["homePeriod"])
	greetingLabel = Ui.label("", "MutedLabel")
	titles.add_child(greetingLabel)
	pageTitle = Ui.label(pageTitles[period], "HeaderLabel")
	titles.add_child(pageTitle)
	statsLabel = Ui.wrapLabel("", "MutedLabel")
	titles.add_child(statsLabel)
	var settingsButton: Button = Ui.iconButton("gear", "Button", "textMuted")
	settingsButton.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settingsButton.pressed.connect(_onSettingsPressed)
	header.add_child(settingsButton)

	# day / week / month / year
	periodChips = Segmented.new()
	periodChips.fillWidth = true
	column.add_child(periodChips)
	periodChips.setOptions(periodOptions, period)
	periodChips.changed.connect(setPeriod)

	# body card
	bodyCard = BodyCard.new()
	column.add_child(bodyCard)
	bodyCard.configure(cardTitle(), bodyMaxHeight, "rangeWeek", true, cardHint)
	bodyCard.regionTapped.connect(_onBodyRegionTapped)
	bodyCard.emptyTapped.connect(_onBodyEmptyTapped)
	normalBlendSeconds = bodyCard.bodyView.transitionSeconds
	targetsChip = bodyCard.addFooterChip("Targets")
	targetsChip.toggled.connect(setTargetsOverlay)
	cardioChip = bodyCard.addFooterChip("Cardio")
	cardioChip.toggled.connect(setCardioOverlay)

	# tabs
	tabs = Segmented.new()
	tabs.fillWidth = true
	column.add_child(tabs)
	tabs.setOptions([["balance", "Balance"], ["workouts", "Workouts"]], currentTab)
	tabs.changed.connect(showTab)
	balanceBox = Ui.vbox(8)
	column.add_child(balanceBox)
	workoutsBox = Ui.vbox(8)
	column.add_child(workoutsBox)

	# start / resume
	startButton = Ui.button("Start workout", "AccentButton", startWorkout)
	startButton.custom_minimum_size.y = mainButtonHeight
	layout.add_child(Ui.margin(startButton, pagePad, 8, pagePad, 12))
	_applyTab()
	decorateFrame({"page": page, "header": header, "content": scroll, "bottom": startButton.get_parent(), "titleLabel": pageTitle})


func rebuild() -> void:
	# a new theme: the workout rows carry theme colours, so they are made again
	workoutsShown = ""
	refresh(false)


### /// REFRESH ///

func _now() -> float:
	return Time.get_unix_time_from_system()


func _onStorageChanged(section: String) -> void:
	# settings: the slider (every target counts from it), the active presets and the overlay chips
	if section == "settings":
		_applySettings()
		if bodyCard != null and not replaying() and not writingOverlay:
			_readTargets()
			_applyOverlays(false)
		return
	if section == "exercisePrefs":
		return
	dirty = true
	if is_visible_in_tree():
		call_deferred("_refreshIfDirty")


func _refreshIfDirty() -> void:
	if dirty:
		refresh(true)


func onShown() -> void:
	if dirty:
		refresh(true)
	_applySettings()


func _applySettings() -> void:
	if bodyCard == null:
		return
	bodyCard.setHideUntouched(bool(Storage.settings["hideUntouched"]))
	bodyCard.setRange(int(Storage.settings["rangeWeek"]))
	# a changed "default body view" setting wins over the chips; otherwise the chips' pick stays
	var defaultView: String = str(Storage.settings["defaultView"])
	if defaultView != appliedDefaultView:
		appliedDefaultView = defaultView
		bodyCard.setView(defaultView)


func _bias() -> float:
	# minutes the local clock runs ahead of UTC (for "today")
	return float(Time.get_time_zone_from_system().get("bias", 0))


func cardTitle() -> String:
	if targetsOn():
		return targetsCardTitle
	return str(cardTitles[period])


func averaged() -> bool:
	# month and year show sets per week, averaged over the weeks they cover
	return period == "month" or period == "year"


func refresh(animate: bool) -> void:
	### WHAT THIS DOES
	# recomputes the shown period from storage and redraws everything on the page

	var now: float = _now()

	if replaying():
		_endReplay()
	dirty = false
	allWorkouts = Storage.submittedWorkouts()
	shownWorkouts = HeatEngine.periodWorkouts(allWorkouts, period, now, _bias())
	weeksCovered = HeatEngine.periodWeeks(allWorkouts, period, now)
	var totalHeat: Dictionary = HeatEngine.effectiveSets(HeatEngine.weekEntries(shownWorkouts), AppData.exerciseById)
	shownHeat = HeatEngine.scaleHeat(totalHeat, 1.0 / weeksCovered)
	var totalMinutes: Dictionary = HeatEngine.cardioMinutes(HeatEngine.weekEntries(shownWorkouts), AppData.effortById, AppData.cardioLights)
	cardioMinutes = HeatEngine.scaleHeat(totalMinutes, 1.0 / weeksCovered)
	cardioLogged = Targets.hasCardio()
	_readTargets()

	# header
	var totalSets: int = Ui.setCount(HeatEngine.weekEntries(shownWorkouts))
	var totalCardio: int = Ui.minuteCount(HeatEngine.weekEntries(shownWorkouts))
	var workoutWord: String = "workouts"
	if shownWorkouts.size() == 1:
		workoutWord = "workout"
	greetingLabel.text = Ui.greeting(str(Storage.profile["name"]), now)
	pageTitle.text = pageTitles[period]
	if averaged():
		statsLabel.text = "%s · %d %s · %s sets a week" % [Ui.periodRangeLabel(period, now), shownWorkouts.size(), workoutWord, Ui.formatSets(float(totalSets) / weeksCovered)]
	else:
		statsLabel.text = "%s · %d %s · %d sets" % [Ui.periodRangeLabel(period, now), shownWorkouts.size(), workoutWord, totalSets]
	if totalCardio > 0:
		statsLabel.text += " · %d min cardio" % int(roundf(float(totalCardio) / weeksCovered))
		if averaged():
			statsLabel.text += " a week"

	# body
	bodyCard.setBody(str(Storage.profile["body"]))
	bodyCard.setGradient(str(Storage.profile["gradient"]))
	_applySettings()
	_applyOverlays(animate)
	_fillWorkouts()
	_updateStartButton()


### /// OVERLAYS ///

func targetsOn() -> bool:
	return bool(Storage.settings["overlayTargets"]) and regionTargets.size() > 0


func cardioOn() -> bool:
	return bool(Storage.settings["overlayCardio"]) and cardioLogged


func setTargetsOverlay(on: bool) -> void:
	_writeOverlay("overlayTargets", on)
	_applyOverlays(true)


func setCardioOverlay(on: bool) -> void:
	_writeOverlay("overlayCardio", on)
	_applyOverlays(true)


func _writeOverlay(key: String, on: bool) -> void:
	# remembered for next time; the page is redrawn once by the caller, not again by the save
	if on == bool(Storage.settings[key]):
		return
	writingOverlay = true
	Storage.setSetting(key, on)
	writingOverlay = false


func _readTargets() -> void:
	# the switched-on presets' numbers (they count from the slider, so they follow it)
	regionTargets = Targets.regionTargets()
	cardioTargets = Targets.cardioTargets()


func displayHeat(heat: Dictionary) -> Dictionary:
	# what the body draws for some heat: the sets as they are, or with targets on each muscle's share
	# of its target on the 0-N scale
	if targetsOn():
		return HeatEngine.targetHeat(heat, regionTargets, float(Storage.settings["rangeWeek"]))
	return heat


func cardioLevels() -> Dictionary:
	# how full each cardio light is (0..1) by its colour, for the vessels
	var levels: Dictionary = {}
	for light in AppData.cardioLights:
		var wanted: float = maxf(float(cardioTargets.get(light["id"], 0.0)), 1.0)
		levels[str(light["colour"])] = clampf(float(cardioMinutes.get(light["id"], 0.0)) / wanted, 0.0, 1.0)
	return levels


func _applyOverlays(animate: bool) -> void:
	### WHAT THIS DOES
	# the chips (shown only when they have something to show), the body's heat and vessels, the card
	# title and hint, and the balance tab - everything the two overlays change

	targetsChip.visible = regionTargets.size() > 0
	targetsChip.set_pressed_no_signal(targetsOn())
	cardioChip.visible = cardioLogged
	cardioChip.set_pressed_no_signal(cardioOn())
	if replaying():
		return
	bodyCard.setTitle(cardTitle())
	bodyCard.setHint(cardHintText())
	if targetsOn():
		bodyCard.setScaleMode("target")
	else:
		bodyCard.setScaleMode("sets")
	bodyCard.setHeat(displayHeat(shownHeat), animate)
	if cardioOn():
		bodyCard.setVessels(cardioLevels())
	else:
		bodyCard.setVessels({})
	_fillBalance()


func cardHintText() -> String:
	# the plain hint, or what the overlays say: how many muscles are on target, the cardio minutes
	var lines: Array = []
	if targetsOn():
		var met: int = HeatEngine.onTarget(shownHeat, regionTargets).size()
		var counted: int = 0
		for regionId in regionTargets:
			if float(regionTargets[regionId]) > 0.0:
				counted += 1
		lines.append("%d/%d muscles on target · tap one for details" % [met, counted])
	if cardioOn():
		var parts: Array = []
		for light in AppData.cardioLights:
			var colourWord: String = str(light["colour"]).capitalize()
			var effortWord: String = str(light["name"]).get_slice(" ", 0).to_lower()
			var done: int = int(roundf(float(cardioMinutes.get(light["id"], 0.0))))
			parts.append("%s = %s %d/%d min" % [colourWord, effortWord, done, int(cardioTargets.get(light["id"], 0))])
		lines.append(" · ".join(parts))
	if lines.is_empty():
		return cardHint
	return "\n".join(lines)


func _bandOf(regionId: String) -> Array:
	# a muscle's band: with targets on, its target up to targetOverShare x it; otherwise the usual one
	if targetsOn() and float(regionTargets.get(regionId, 0.0)) > 0.0:
		var wanted: float = float(regionTargets[regionId])
		return [wanted, wanted * targetOverShare]
	return AppData.regionBand(regionId)


### /// PERIOD ///

func setPeriod(periodId: String) -> void:
	### WHAT THIS DOES
	# shows another period: remembered for next time, the page refilled, the body lit up again over
	# exactly switchReplaySeconds (also when the same period is picked again)

	if not HeatEngine.periodIds.has(periodId):
		return
	period = periodId
	periodChips.select(periodId, false)
	if str(Storage.settings["homePeriod"]) != periodId:
		Storage.setSetting("homePeriod", periodId)
	refresh(false)
	startReplay(switchReplaySeconds)


### /// TABS ///

func showTab(tabId: String) -> void:
	currentTab = tabId
	tabs.select(tabId, false)
	_applyTab()


func _applyTab() -> void:
	balanceBox.visible = currentTab == "balance"
	workoutsBox.visible = currentTab == "workouts"


### /// BALANCE ///

func _fillBalance() -> void:
	### WHAT THIS DOES
	# one row per region, furthest from its target band first; each row is made once and after that
	# only gets new numbers and a new place, and a fresh page makes the first few rows now and the
	# rest over the next frames (_process)

	if balanceNote == null:
		_buildBalanceTop()
	_fillTargetsLine()
	_fillCardioPanel()
	var regions: Array = AppData.regions
	if targetsOn():
		regions = []
		for region in AppData.regions:
			if float(regionTargets.get(region["id"], 0.0)) > 0.0:
				regions.append({"id": region["id"], "name": region["name"], "band": _bandOf(region["id"])})
	balanceRanks = HeatEngine.rankRegions(shownHeat, regions)
	if period == "day":
		balanceRanks = _todayRanks(balanceRanks)
	balanceNote.text = _balanceNoteText()
	_placeBalanceRows(firstBalanceRows)


func _buildBalanceTop() -> void:
	### WHAT THIS DOES
	# the three lines over the balance rows: the targets line, the cardio panel and the note

	targetsLine = Ui.hbox(8)
	balanceBox.add_child(targetsLine)
	targetsText = Ui.wrapLabel("", "MutedLabel")
	targetsText.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targetsText.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	targetsLine.add_child(targetsText)
	var change: Button = Ui.button("Targets", "ChipButton", openTargets)
	change.custom_minimum_size.y = Segmented.chipHeight
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	targetsLine.add_child(change)
	targetsLine.set_meta("button", change)

	cardioPanel = PanelContainer.new()
	cardioPanel.theme_type_variation = "CardPanel"
	balanceBox.add_child(cardioPanel)
	cardioBox = Ui.vbox(6)
	cardioPanel.add_child(cardioBox)

	balanceNote = Ui.label("", "FaintLabel")
	balanceNote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balanceBox.add_child(balanceNote)


func _fillTargetsLine() -> void:
	var names: Array = []
	for preset in Targets.activePresets():
		names.append(str(preset["name"]))
	if names.is_empty():
		targetsText.text = "Training for a sport or a look? Target presets set a goal per muscle."
		targetsLine.get_meta("button").text = "Pick one"
	else:
		targetsText.text = "Targets: %s" % ", ".join(names)
		targetsLine.get_meta("button").text = "Change"


func _fillCardioPanel() -> void:
	### WHAT THIS DOES
	# with the cardio overlay on: each light's minutes against its weekly target as a coloured bar,
	# then the health line (easy + 2 x hard against the WHO 150, extra benefit at 300) and the note

	cardioPanel.visible = cardioOn()
	if not cardioOn():
		return
	Ui.clearChildren(cardioBox)
	var when: String = "this week"
	if averaged():
		when = "a week, averaged"
	elif period == "day":
		when = "today, of the weekly target"
	cardioBox.add_child(Ui.label("Cardio %s" % when, "BoldLabel"))
	for light in AppData.cardioLights:
		var minutes: float = float(cardioMinutes.get(light["id"], 0.0))
		var wanted: float = float(cardioTargets.get(light["id"], 0.0))
		var top: HBoxContainer = Ui.hbox(8)
		cardioBox.add_child(top)
		var nameLabel: Label = Ui.label("%s (%s)" % [light["name"], light["colour"]], "BoldLabel")
		nameLabel.add_theme_color_override("font_color", _lightColour(str(light["colour"])))
		nameLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nameLabel)
		top.add_child(Ui.label("%d / %d min" % [int(roundf(minutes)), int(wanted)], "BoldLabel"))
		cardioBox.add_child(_cardioBar(minutes / maxf(wanted, 1.0), _lightColour(str(light["colour"]))))

	# the health line: a bar toward the WHO minimum (then toward the extra-benefit end) and a verdict
	var health: float = HeatEngine.healthMinutes(cardioMinutes)
	var goal: float = HeatEngine.healthMinimum
	var verdict: String = "Below the WHO minimum"
	var verdictColour: Color = Ui.colour("cold").lerp(Ui.colour("text"), 0.35)
	if health >= HeatEngine.healthExtra:
		goal = HeatEngine.healthExtra
		verdict = "Past the extra-benefit end"
		verdictColour = Ui.colour("neutral")
	elif health >= HeatEngine.healthMinimum:
		goal = HeatEngine.healthExtra
		verdict = "Meets the WHO minimum · %d for extra benefit" % int(HeatEngine.healthExtra)
		verdictColour = Ui.colour("neutral")
	var healthTop: HBoxContainer = Ui.hbox(8)
	cardioBox.add_child(healthTop)
	var healthName: Label = Ui.label("Health minutes", "MutedLabel")
	healthName.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	healthTop.add_child(healthName)
	healthTop.add_child(Ui.label("%d / %d" % [int(roundf(health)), int(goal)], "BoldLabel"))
	cardioBox.add_child(_cardioBar(health / goal, Ui.colour("neutral")))
	var verdictLabel: Label = Ui.wrapLabel("%s (easy + 2 × hard)" % verdict, "")
	verdictLabel.add_theme_color_override("font_color", verdictColour)
	cardioBox.add_child(verdictLabel)
	cardioBox.add_child(Ui.wrapLabel(cardioNote, "MutedLabel"))


func _lightColour(colourName: String) -> Color:
	if colourName == "red":
		return VesselLayer.redColour
	return VesselLayer.blueColour


func _cardioBar(share: float, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = cardioBarHeight
	bar.max_value = 1.0
	bar.value = clampf(share, 0.0, 1.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", AppTheme.box("balance", fill))
	return bar


func openTargets() -> AppScreen:
	return app.openTargets()


func _balanceNoteText() -> String:
	if targetsOn() and period == "day":
		return "Effective sets today, as part of each muscle's weekly target"
	if targetsOn():
		return "Muscles with a target, furthest from it first (over = more than %d× the target)" % int(targetOverShare)
	if period == "day" and balanceRanks.is_empty():
		return "Nothing trained today yet - the muscles you work show up here, as part of their weekly target."
	if period == "day":
		return "Effective sets today, as part of each muscle's weekly target band"
	if averaged():
		return "Average effective sets per week %s against each muscle's weekly target band" % periodWords[period]
	return "Effective sets in the last 7 days against each muscle's weekly target band"


func _todayRanks(ranks: Array) -> Array:
	# the day view lists only the muscles worked today, most sets first
	var worked: Array = []
	for rank in ranks:
		if float(rank["sets"]) >= HeatEngine.missedBelow:
			worked.append(rank)
	worked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["sets"]) > float(b["sets"]))
	return worked


func _placeBalanceRows(newRowLimit: int) -> void:
	### WHAT THIS DOES
	# puts the rows in rank order with fresh numbers, making at most newRowLimit missing rows;
	# stops at the first row it may not make yet and leaves the rest for the next frame

	var made: int = 0
	var place: int = balanceNote.get_index() + 1
	var listed: Dictionary = {}

	# rows of muscles this list leaves out (the day view, muscles without a target) are hidden
	balancePending = false
	for rank in balanceRanks:
		listed[str(rank["region"])] = true
	for regionId in balanceRows:
		balanceRows[regionId]["row"].visible = listed.has(regionId)

	for rank in balanceRanks:
		var regionId: String = str(rank["region"])
		if not balanceRows.has(regionId):
			if made >= newRowLimit:
				balancePending = true
				return
			balanceRows[regionId] = _balanceRow(regionId, str(rank["name"]))
			balanceBox.add_child(balanceRows[regionId]["row"])
			made += 1
		var parts: Dictionary = balanceRows[regionId]
		_updateBalanceRow(parts, rank)
		balanceBox.move_child(parts["row"], place)
		place += 1


func _balanceRow(regionId: String, regionName: String) -> Dictionary:
	# one region's row, without numbers yet (_updateBalanceRow fills them)
	var row := TapRow.new()
	var box: VBoxContainer = Ui.vbox(8)
	row.setContent(box)
	var top: HBoxContainer = Ui.hbox(8)
	box.add_child(top)
	var nameLabel: Label = Ui.label(regionName, "BoldLabel")
	nameLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nameLabel)
	var amount: Label = Ui.label("", "MutedLabel")
	top.add_child(amount)
	var status: PanelContainer = Ui.tag("", Ui.colour("textMuted"))
	top.add_child(status)
	var bar := BalanceBar.new()
	box.add_child(bar)
	row.tapped.connect(openRegion.bind(regionId))
	row.set_meta("regionId", regionId)
	return {"row": row, "amount": amount, "status": status, "bar": bar}


func _updateBalanceRow(parts: Dictionary, rank: Dictionary) -> void:
	# the day view tags how much of the weekly target today gave; the others the usual status
	var band: Array = rank["band"]
	parts["amount"].text = "%s / %d–%d" % [Ui.formatSets(rank["sets"]), int(band[0]), int(band[1])]
	if period == "day":
		var percent: int = int(roundf(100.0 * float(rank["sets"]) / maxf(float(band[0]), 0.001)))
		Ui.retag(parts["status"], "%d%% of week" % percent, Ui.colour("accent"))
	elif targetsOn() and rank["status"] == HeatEngine.statusOk:
		Ui.retag(parts["status"], "on target", Ui.statusColour(rank["status"]))
	else:
		Ui.retag(parts["status"], Ui.statusText(rank["status"]), Ui.statusColour(rank["status"]))
	if targetsOn():
		parts["amount"].text = "%s / %s" % [Ui.formatSets(rank["sets"]), Ui.formatSets(float(band[0]))]
	parts["bar"].setValues(float(rank["sets"]), band, str(rank["status"]))


### /// WORKOUTS ///

func _fillWorkouts() -> void:
	### WHAT THIS DOES
	# the period's workouts newest first (the year view: one row per month instead); a row is only
	# made again when something it shows changed (its workouts, the body, the colours, the 0-N range,
	# the date - day names follow it), otherwise kept and moved into place; missing rows are made a
	# few per frame (_process), each carries a small body

	var shared: String = JSON.stringify([Storage.profile["body"], Storage.profile["gradient"], Storage.settings["rangeWorkout"], Storage.settings["rangeWeek"], Time.get_date_string_from_system()])
	var planned: Dictionary = {}

	# the plan: what rows the list should hold, in order
	workoutPlan = []
	if period == "year":
		for bucket in _monthBuckets():
			workoutPlan.append({"key": "month" + JSON.stringify(bucket["workouts"]) + shared, "month": bucket})
	else:
		var newestFirst: Array = shownWorkouts.duplicate()
		newestFirst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["startedAt"]) > float(b["startedAt"]))
		for workout in newestFirst:
			workoutPlan.append({"key": JSON.stringify(workout) + shared, "workout": workout})

	# nothing in the period: the hint text instead of rows
	if workoutPlan.is_empty():
		workoutsPending = false
		if workoutsShown == "empty" + period:
			return
		workoutsShown = "empty" + period
		Ui.clearChildren(workoutsBox)
		workoutRows = {}
		var empty: Label = Ui.wrapLabel("No workouts %s yet. Start one with the button below - it shows up here when you finish it." % periodWords[period], "MutedLabel")
		workoutsBox.add_child(Ui.margin(empty, 4, 8, 4, 8))
		return

	# the line over the rows (a fresh list, after the hint text, or after a theme change)
	if workoutsShown != "rows":
		workoutsShown = "rows"
		Ui.clearChildren(workoutsBox)
		workoutRows = {}
		workoutsNote = Ui.label("", "FaintLabel")
		workoutsNote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		workoutsBox.add_child(workoutsNote)
	workoutsNote.text = "Tap to edit · swipe left to delete, right to save as a template"
	if period == "year":
		workoutsNote.text = "Each month: workouts, sets and its average week on the body"

	# rows that left the plan go at once, the rest are placed (and made) by _placeWorkoutRows
	for item in workoutPlan:
		planned[item["key"]] = true
	for rowKey in workoutRows.keys():
		if not planned.has(rowKey):
			workoutsBox.remove_child(workoutRows[rowKey])
			workoutRows[rowKey].queue_free()
			workoutRows.erase(rowKey)
	_placeWorkoutRows(firstWorkoutRows)


func _placeWorkoutRows(newRowLimit: int) -> void:
	# puts the planned rows in order, making at most newRowLimit missing ones (the rest next frame)
	var made: int = 0
	var place: int = 1

	workoutsPending = false
	for item in workoutPlan:
		var row: Control = workoutRows.get(item["key"], null)
		if row == null:
			if made >= newRowLimit:
				workoutsPending = true
				return
			if item.has("month"):
				row = _monthRow(item["month"])
			else:
				row = _workoutRow(item["workout"])
			workoutsBox.add_child(row)
			workoutRows[item["key"]] = row
			made += 1
		workoutsBox.move_child(row, place)
		place += 1


func _monthBuckets() -> Array:
	### WHAT THIS DOES
	# the year view's months, newest first: [{label, workouts, weeks}] - weeks = the part of the month
	# inside the year and after the first workout ever, in weeks (at least 1), to average it by

	var buckets: Dictionary = {}
	var now: float = _now()
	var firstEver: float = now
	var windowStart: float = now - float(HeatEngine.periodDays["year"]) * HeatEngine.daySeconds
	var bias: float = _bias()
	var ordered: Array = []

	for workout in allWorkouts:
		firstEver = minf(firstEver, HeatEngine.workoutTime(workout))
	for workout in shownWorkouts:
		var when: float = HeatEngine.workoutTime(workout)
		var date: Dictionary = Ui.localDate(when)
		var key: String = "%04d-%02d" % [int(date["year"]), int(date["month"])]
		if not buckets.has(key):
			var monthStart: float = Time.get_unix_time_from_datetime_dict({"year": int(date["year"]), "month": int(date["month"]), "day": 1, "hour": 0, "minute": 0, "second": 0}) - bias * 60.0
			var nextYear: int = int(date["year"])
			var nextMonth: int = int(date["month"]) + 1
			if nextMonth > 12:
				nextMonth = 1
				nextYear += 1
			var monthEnd: float = Time.get_unix_time_from_datetime_dict({"year": nextYear, "month": nextMonth, "day": 1, "hour": 0, "minute": 0, "second": 0}) - bias * 60.0
			var from: float = maxf(monthStart, maxf(windowStart, firstEver))
			var to: float = minf(monthEnd, now)
			var weeks: float = maxf((to - from) / HeatEngine.daySeconds / 7.0, 1.0)
			buckets[key] = {"key": key, "label": Ui.monthLabel(when), "workouts": [], "weeks": weeks}
		buckets[key]["workouts"].append(workout)

	var keys: Array = buckets.keys()
	keys.sort()
	keys.reverse()
	for key in keys:
		ordered.append(buckets[key])
	return ordered


func _monthRow(bucket: Dictionary) -> PanelContainer:
	### WHAT THIS DOES
	# one month of the year view: a small body with its average week, workouts, sets, the top muscles

	var row := PanelContainer.new()
	var entries: Array = HeatEngine.weekEntries(bucket["workouts"])
	var heat: Dictionary = HeatEngine.scaleHeat(HeatEngine.effectiveSets(entries, AppData.exerciseById), 1.0 / float(bucket["weeks"]))
	var line: HBoxContainer = Ui.hbox(12)
	var count: int = bucket["workouts"].size()

	row.add_theme_stylebox_override("panel", AppTheme.box("row"))
	row.add_child(line)
	row.set_meta("month", bucket["key"])

	var thumb := BodyView.new()
	thumb.interactive = false
	thumb.viewMode = "both"
	thumb.edgeMargin = 2.0
	thumb.pairGap = 0.02
	thumb.custom_minimum_size = thumbSize
	thumb.body = str(Storage.profile["body"])
	thumb.gradientId = str(Storage.profile["gradient"])
	thumb.rangeMax = float(Storage.settings["rangeWeek"])
	line.add_child(thumb)
	thumb.setHeat(heat, false)

	var texts: VBoxContainer = Ui.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	texts.add_child(Ui.label(str(bucket["label"]), "BoldLabel"))
	var workoutWord: String = "workouts"
	if count == 1:
		workoutWord = "workout"
	texts.add_child(Ui.label("%d %s · %s · %s a week" % [count, workoutWord, Ui.workSummary(entries), Ui.formatSets(float(count) / float(bucket["weeks"]))], "MutedLabel"))
	var top: Array = heat.keys()
	top.sort_custom(func(a: String, b: String) -> bool: return float(heat[a]) > float(heat[b]))
	var names: Array = []
	for regionId in top.slice(0, 3):
		names.append(AppData.regionName(regionId).to_lower())
	var most: Label = Ui.label("most: %s" % ", ".join(names), "FaintLabel")
	most.clip_text = true
	most.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	most.custom_minimum_size.x = 60.0
	texts.add_child(most)
	return row


func _workoutRow(workout: Dictionary) -> TapRow:
	var row := TapRow.new()
	var entries: Array = workout["entries"]
	var line: HBoxContainer = Ui.hbox(12)
	row.setContent(line)

	# tiny body with this workout's own heat (a picture, not tappable)
	var thumb := BodyView.new()
	thumb.interactive = false
	thumb.viewMode = "both"
	thumb.edgeMargin = 2.0
	thumb.pairGap = 0.02
	thumb.custom_minimum_size = thumbSize
	thumb.body = str(Storage.profile["body"])
	thumb.gradientId = str(Storage.profile["gradient"])
	thumb.rangeMax = float(Storage.settings["rangeWorkout"])
	line.add_child(thumb)
	thumb.setHeat(HeatEngine.effectiveSets(entries, AppData.exerciseById), false)

	# text
	var texts: VBoxContainer = Ui.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	var started: float = float(workout["startedAt"])
	texts.add_child(Ui.label("%s · %s" % [Ui.dayLabel(started), Ui.timeLabel(started)], "BoldLabel"))
	var length: float = HeatEngine.workoutTime(workout) - started
	var exerciseWord: String = "exercises"
	if entries.size() == 1:
		exerciseWord = "exercise"
	texts.add_child(Ui.label("%s · %s · %d %s" % [Ui.formatLength(length), Ui.workSummary(entries), entries.size(), exerciseWord], "MutedLabel"))
	var names: Array = []
	for entry in entries:
		names.append(str(AppData.getExercise(entry["exerciseId"]).get("name", entry["exerciseId"])))
	var nameLine: Label = Ui.label(", ".join(names), "FaintLabel")
	nameLine.clip_text = true
	nameLine.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nameLine.custom_minimum_size.x = 60.0
	texts.add_child(nameLine)

	var more: Button = Ui.iconButton("more", "FlatButton", "textMuted")
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	more.pressed.connect(openWorkoutMenu.bind(str(workout["id"])))
	line.add_child(more)

	var workoutId: String = str(workout["id"])
	row.setSwipeActions({"id": "template", "text": "Save as template", "colour": Ui.colour("accent")}, {"id": "delete", "text": "Delete", "colour": Ui.colour("hot")})
	row.tapped.connect(openEditor.bind(workoutId))
	row.longPressed.connect(openWorkoutMenu.bind(workoutId))
	row.swiped.connect(_onWorkoutSwiped.bind(workoutId))
	row.set_meta("workoutId", workoutId)
	return row


func _onWorkoutSwiped(actionId: String, workoutId: String) -> void:
	if actionId == "delete":
		deleteWorkout(workoutId)
	elif actionId == "template":
		saveAsTemplate(workoutId)


func openWorkoutMenu(workoutId: String) -> BottomSheet:
	var index: int = Storage.findWorkoutIndex(workoutId)
	if index < 0:
		return null
	var workout: Dictionary = Storage.submittedWorkouts()[index]
	var title: String = "%s · %s" % [Ui.dayLabel(float(workout["startedAt"])), Ui.timeLabel(float(workout["startedAt"]))]
	var actions: Array = [["edit", "Edit workout", "Button"], ["template", "Save as template", "Button"], ["delete", "Delete workout", "Button"]]
	return app.confirm(title, "", actions, _onWorkoutMenu.bind(workoutId))


func _onWorkoutMenu(actionId: String, workoutId: String) -> void:
	if actionId == "edit":
		openEditor(workoutId)
	elif actionId == "template":
		saveAsTemplate(workoutId)
	elif actionId == "delete":
		deleteWorkout(workoutId)


func openEditor(workoutId: String) -> WorkoutScreen:
	return app.openWorkoutEditor(workoutId)


func deleteWorkout(workoutId: String) -> void:
	# gone at once, with an undo on the toast (no "are you sure")
	var removed: Dictionary = Storage.deleteWorkout(workoutId)
	if removed.is_empty():
		return
	app.showToast("Workout deleted", "Undo", func() -> void: Storage.restoreWorkout(removed))


func saveAsTemplate(workoutId: String) -> BottomSheet:
	var index: int = Storage.findWorkoutIndex(workoutId)
	if index < 0:
		return null
	var workout: Dictionary = Storage.submittedWorkouts()[index]
	var suggested: String = "%s workout" % Ui.dayLabel(float(workout["startedAt"]))
	var sheet: BottomSheet = app.askText("Save as template", "Its exercises, sets and grips - apply it from Add exercise → Templates.", suggested, "Template name", "Save template", Callable())
	sheet.onChoice = _onTemplateNamed.bind(sheet, workout["entries"])
	return sheet


func _onTemplateNamed(actionId: String, sheet: BottomSheet, entries: Array) -> void:
	if actionId != "ok":
		return
	var templateName: String = sheet.textValue()
	if templateName == "":
		templateName = "Template"
	Storage.saveTemplate(templateName, entries)
	app.showToast("Template \"%s\" saved" % templateName)


### /// REGION SHEET ///

func openRegion(regionId: String) -> BottomSheet:
	### WHAT THIS DOES
	# the period's sets (per week for month and year), the band, how far off, which exercises gave how
	# much, Find exercises

	var sets: float = float(shownHeat.get(regionId, 0.0))
	var band: Array = _bandOf(regionId)
	var withTarget: bool = targetsOn() and float(regionTargets.get(regionId, 0.0)) > 0.0
	var status: String = HeatEngine.targetStatus(sets, band)
	var region: Dictionary = AppData.getRegion(regionId)
	var sheet := BottomSheet.new()
	var viewWords: Array = region.get("views", [])

	bodyCard.bodyView.selectedRegions = [regionId]
	var when: String = str(periodWords[period])
	if averaged():
		when = "per week, averaged %s" % when
	sheet.setTitle(str(region.get("name", regionId)), "%s view · %s" % [" + ".join(viewWords), when])

	# three stat tiles
	var tiles: HBoxContainer = Ui.hbox(8)
	sheet.body.add_child(tiles)
	var setsWords: Dictionary = {"day": "sets today", "week": "sets this week", "month": "sets a week", "year": "sets a week"}
	tiles.add_child(_statTile(Ui.formatSets(sets), setsWords[period], null))
	if withTarget:
		tiles.add_child(_statTile(Ui.formatSets(float(band[0])), "your target", null))
	else:
		tiles.add_child(_statTile("%d–%d" % [int(band[0]), int(band[1])], "weekly target", null))
	if period == "day":
		var percent: int = int(roundf(100.0 * sets / maxf(float(band[0]), 0.001)))
		tiles.add_child(_statTile("%d%%" % percent, "of the week's low end", null))
	else:
		var offText: String = "on target"
		if withTarget and sets >= float(band[0]):
			offText = "target met"
		elif sets < float(band[0]):
			offText = "%s short" % Ui.formatSets(float(band[0]) - sets)
		elif sets > float(band[1]):
			offText = "%s over" % Ui.formatSets(sets - float(band[1]))
		tiles.add_child(_statTile("", offText, Ui.tag(Ui.statusText(status), Ui.statusColour(status))))

	# where it came from (per week for month and year)
	var contributions: Array = HeatEngine.contributions(regionId, HeatEngine.weekEntries(shownWorkouts), AppData.exerciseById)
	var heading: HBoxContainer = Ui.hbox(8)
	heading.add_child(Ui.label("Where it came from", "BoldLabel"))
	heading.add_child(Ui.spacer())
	if averaged():
		heading.add_child(Ui.label("effective sets a week", "FaintLabel"))
	else:
		heading.add_child(Ui.label("effective sets", "FaintLabel"))
	sheet.body.add_child(heading)
	if contributions.is_empty():
		sheet.body.add_child(Ui.wrapLabel("Nothing worked this muscle %s." % periodWords[period], "MutedLabel"))
	var biggest: float = 0.0
	for row in contributions:
		biggest = maxf(biggest, float(row["effective"]) / weeksCovered)
	for row in contributions:
		sheet.body.add_child(_contributionRow(row, biggest))

	sheet.addAction("find", "Find exercises for %s" % str(region.get("name", regionId)).to_lower(), "AccentButton")
	sheet.onChoice = _onRegionChoice.bind(regionId)
	sheet.closed.connect(_onRegionSheetClosed)
	sheet.set_meta("regionId", regionId)
	sheet.set_meta("contributionCount", contributions.size())
	regionSheet = sheet
	return app.openSheet(sheet)


func _statTile(big: String, small: String, extra: Control) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", AppTheme.box("tile"))
	var stack: VBoxContainer = Ui.vbox(4)
	tile.add_child(stack)
	if extra != null:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		stack.add_child(extra)
	if big != "":
		var value: Label = Ui.label(big, "TitleLabel")
		stack.add_child(value)
	stack.add_child(Ui.label(small, "MutedLabel"))
	return tile


func _contributionRow(row: Dictionary, biggest: float) -> VBoxContainer:
	var box: VBoxContainer = Ui.vbox(4)
	var top: HBoxContainer = Ui.hbox(8)
	box.add_child(top)
	var nameLabel: Label = Ui.wrapLabel(str(row["name"]), "BoldLabel")
	top.add_child(nameLabel)
	var effective: float = float(row["effective"]) / weeksCovered
	top.add_child(Ui.label(Ui.formatSets(effective), "BoldLabel"))
	var detail: String = "%d sets × %s" % [int(row["sets"]), Ui.formatSets(float(row["share"]))]
	if averaged():
		detail = "%d sets × %s %s" % [int(row["sets"]), Ui.formatSets(float(row["share"])), periodWords[period]]
	box.add_child(Ui.label(detail, "MutedLabel"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6.0
	bar.max_value = maxf(biggest, 0.001)
	bar.value = effective
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	return box


func _onRegionChoice(actionId: String, regionId: String) -> void:
	if actionId == "find":
		app.openPicker(null, regionId)


func _onRegionSheetClosed() -> void:
	regionSheet = null
	if bodyCard != null:
		bodyCard.bodyView.selectedRegions = []


### /// START / RESUME ///

func startWorkout() -> WorkoutScreen:
	if not Storage.hasCurrentWorkout():
		Storage.startWorkout()
	return app.openWorkout()


func _updateStartButton() -> void:
	var text: String = "Start workout"
	if Storage.hasCurrentWorkout():
		var started: float = float(Storage.currentWorkout()["startedAt"])
		text = "Resume workout · %s" % Ui.formatClock(_now() - started)
	if text != lastClockText:
		lastClockText = text
		startButton.text = text


func _process(delta: float) -> void:
	if replaying():
		_stepReplay(delta)
	if balancePending:
		_placeBalanceRows(balanceRowsPerFrame)
	if workoutsPending:
		_placeWorkoutRows(workoutRowsPerFrame)
	if is_visible_in_tree() and Storage.hasCurrentWorkout():
		_updateStartButton()


func showFinished(_workout: Dictionary) -> void:
	### WHAT THIS DOES
	# back from Finish: scroll to the body and blend the new heat in slowly so the change shows

	scroll.scrollTo(0.0)
	bodyCard.bodyView.transitionSeconds = finishBlendSeconds
	refresh(true)
	get_tree().create_timer(finishBlendSeconds + 0.1).timeout.connect(_restoreBlend)


func _restoreBlend() -> void:
	if bodyCard != null:
		bodyCard.bodyView.transitionSeconds = normalBlendSeconds


func _onSettingsPressed() -> void:
	app.openSettings()


func _onBodyRegionTapped(regionId: String) -> void:
	# during the replay a tap only skips it
	if replaying():
		_endReplay()
		return
	openRegion(regionId)


func _onBodyEmptyTapped() -> void:
	if replaying():
		_endReplay()


### /// WEEK REPLAY ///

func replaying() -> bool:
	return replaySteps.size() > 0


func startReplay(exactSeconds: float = 0.0) -> void:
	### WHAT THIS DOES
	# empties the body and lays out every step of the replay on a clock: one step per muscle of each
	# group (oldest first, muscles in body order), a pulse step closing each group. Groups are the
	# workouts (day, week), the rolling weeks (month) or the months (year). exactSeconds 0 = the app
	# start pacing (muscles as slow as allowed, at most replayMaxSeconds); above 0 the last pulse lands
	# exactly then (a period switch)

	var groups: Array = _replayGroups()
	var muscleCount: int = 0
	var perGroup: Array = []

	if groups.is_empty():
		return

	# each group's muscles, top of the body down (AppData.regions is in body order)
	for group in groups:
		var muscles: Array = []
		for region in AppData.regions:
			var amount: float = float(group["heat"].get(region["id"], 0.0))
			if amount > 0.0:
				muscles.append({"region": region["id"], "amount": amount})
		if muscles.is_empty():
			continue
		muscleCount += muscles.size()
		perGroup.append({"caption": group["caption"], "muscles": muscles})
	if muscleCount == 0:
		return

	# the clock
	var startDelay: float = replayStartDelay
	var pause: float = replayWorkoutPause
	var muscleSeconds: float = 0.0
	if exactSeconds > 0.0:
		startDelay = switchReplayStartDelay
		pause = minf(replayWorkoutPause, switchPauseShare * exactSeconds / float(perGroup.size()))
		muscleSeconds = (exactSeconds - startDelay - pause * float(perGroup.size() - 1)) / float(muscleCount)
	else:
		var pauses: float = startDelay + pause * perGroup.size()
		muscleSeconds = clampf((replayMaxSeconds - pauses) / muscleCount, replayMuscleSecondsMin, replayMuscleSecondsMax)

	# the steps (a group's pulse fires with its last muscle)
	var at: float = startDelay
	replaySteps = []
	for index in range(perGroup.size()):
		var caption: String = "%s · %d/%d" % [perGroup[index]["caption"], index + 1, perGroup.size()]
		var regionIds: Array = []
		for muscle in perGroup[index]["muscles"]:
			at += muscleSeconds
			replaySteps.append({"at": at, "kind": "muscle", "region": muscle["region"], "amount": muscle["amount"], "caption": caption})
			regionIds.append(muscle["region"])
		replaySteps.append({"at": at, "kind": "pulse", "regions": regionIds})
		if index < perGroup.size() - 1:
			at += pause

	# start from an empty body
	replayClock = 0.0
	replayHeat = {}
	bodyCard.bodyView.transitionSeconds = replayBlendSeconds
	bodyCard.setHeat({}, false)
	bodyCard.setVessels({})
	bodyCard.setTitle(pageTitles[period])
	bodyCard.setHint("Tap the body to skip")


func replayLength() -> float:
	# when the last step of the running replay fires (0 = none running)
	if replaySteps.is_empty():
		return 0.0
	return float(replaySteps[replaySteps.size() - 1]["at"])


func _replayGroups() -> Array:
	### WHAT THIS DOES
	# [{caption, heat}] oldest first, heat already divided like the shown period and turned into what
	# the body draws (displayHeat - so the replay ends on exactly what the body shows): a workout each
	# for day and week, a rolling week each for month, a calendar month each for year

	var groups: Array = []
	var scale: float = 1.0 / weeksCovered
	var now: float = _now()

	if period == "year":
		var months: Array = _monthBuckets()
		months.reverse()
		for bucket in months:
			var heat: Dictionary = HeatEngine.effectiveSets(HeatEngine.weekEntries(bucket["workouts"]), AppData.exerciseById)
			groups.append({"caption": bucket["label"], "heat": displayHeat(HeatEngine.scaleHeat(heat, scale))})
		return groups
	if period == "month":
		var weekCount: int = int(ceilf(float(HeatEngine.periodDays["month"]) / 7.0))
		for weeksBack in range(weekCount - 1, -1, -1):
			var newest: float = now - float(weeksBack) * 7.0 * HeatEngine.daySeconds
			var oldest: float = newest - 7.0 * HeatEngine.daySeconds
			var inside: Array = []
			for workout in shownWorkouts:
				var when: float = HeatEngine.workoutTime(workout)
				if when > oldest and when <= newest:
					inside.append(workout)
			if inside.is_empty():
				continue
			var heat: Dictionary = HeatEngine.effectiveSets(HeatEngine.weekEntries(inside), AppData.exerciseById)
			groups.append({"caption": "Week of %s" % Ui.dayLabel(oldest + HeatEngine.daySeconds), "heat": displayHeat(HeatEngine.scaleHeat(heat, scale))})
		return groups

	var oldestFirst: Array = shownWorkouts.duplicate()
	oldestFirst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["startedAt"]) < float(b["startedAt"]))
	for workout in oldestFirst:
		var heat: Dictionary = HeatEngine.effectiveSets(workout["entries"], AppData.exerciseById)
		groups.append({"caption": Ui.dayLabel(float(workout["startedAt"])), "heat": displayHeat(HeatEngine.scaleHeat(heat, scale))})
	return groups


func _stepReplay(delta: float) -> void:
	# fires every step whose time has come; the last one ends the replay
	replayClock += delta
	while replaySteps.size() > 0 and float(replaySteps[0]["at"]) <= replayClock:
		var step: Dictionary = replaySteps.pop_front()
		if step["kind"] == "muscle":
			var regionId: String = step["region"]
			replayHeat[regionId] = float(replayHeat.get(regionId, 0.0)) + float(step["amount"])
			bodyCard.setHeat(replayHeat, true)
			bodyCard.bodyView.flashRegion(regionId, replayMuscleFlash)
			bodyCard.setTitle(step["caption"])
		else:
			for regionId in step["regions"]:
				bodyCard.bodyView.flashRegion(regionId, replayWorkoutFlash)
	if replaySteps.is_empty():
		_endReplay()
	elif not is_visible_in_tree():
		_endReplay()


func _endReplay() -> void:
	# straight to the real week (a skip lands softly; after the last step it is already there)
	replaySteps = []
	_applyOverlays(true)
	get_tree().create_timer(replayBlendSeconds + 0.1).timeout.connect(_restoreBlend)
