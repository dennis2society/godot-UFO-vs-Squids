extends Control
## Spends skill points. A compact grid with a column per branch, built from
## Progress.SKILLS. Hovering a node fills the details line, synergies sit underneath.

signal closed

@export var maxed_color := Color(1.0, 0.82, 0.2)
@export var active_color := Color(0.4, 1.0, 0.5)
@export var inactive_color := Color(0.65, 0.65, 0.7)
@export var node_size := Vector2(172, 42)

var _buttons := {} ## Skill to its Button.
var _shown_skill := ""

@onready var points_label: Label = $Center/Items/Points
@onready var branches: HBoxContainer = $Center/Items/Branches
@onready var details: Label = $Center/Items/Details
@onready var synergies: RichTextLabel = $Center/Items/Synergies
@onready var back_button: Button = $Center/Items/Back


func _ready() -> void:
	hide()
	var columns := {}
	for skill: String in Progress.SKILLS:
		var branch: String = Progress.SKILLS[skill].branch
		if not columns.has(branch):
			columns[branch] = _add_column(branch)
		_buttons[skill] = _add_skill_button(skill, columns[branch])
	back_button.pressed.connect(closed.emit)
	Progress.skills_changed.connect(_refresh)
	_refresh()


func open() -> void:
	show()
	back_button.grab_focus()


func _add_column(branch: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var heading := Label.new()
	heading.text = branch
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	column.add_child(heading)
	branches.add_child(column)
	return column


func _add_skill_button(skill: String, column: VBoxContainer) -> Button:
	var button := Button.new()
	button.custom_minimum_size = node_size
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(Progress.buy.bind(skill))
	button.mouse_entered.connect(_show_details.bind(skill))
	button.focus_entered.connect(_show_details.bind(skill))
	column.add_child(button)
	return button


func _refresh() -> void:
	points_label.text = "Skill points: %d" % Progress.points
	for skill: String in _buttons:
		_refresh_button(skill)
	if _shown_skill != "":
		_show_details(_shown_skill)

	var lines := PackedStringArray()
	for synergy: String in Progress.SYNERGIES:
		var bonus: Dictionary = Progress.SYNERGIES[synergy]
		var active := Progress.has_synergy(synergy)
		var color: Color = active_color if active else inactive_color
		lines.append("[color=#%s]%s %s: %s  [i](%s)[/i][/color]" % [
			color.to_html(false), "◆" if active else "◇", bonus.name, bonus.about,
			_needs_text(bonus.requires),
		])
	synergies.text = "[center]%s[/center]" % "\n".join(lines)


func _refresh_button(skill: String) -> void:
	var button: Button = _buttons[skill]
	var entry: Dictionary = Progress.SKILLS[skill]
	var maxed: bool = Progress.rank(skill) >= entry.max
	var status := "MAX" if maxed else "Cost %d" % Progress.cost(skill)
	if not Progress.unlocked(skill):
		status = "Needs %s" % _needs_text(_unmet(entry.requires), 1)
	button.text = "%s  %d/%d\n%s" % [entry.name, Progress.rank(skill), entry.max, status]
	button.disabled = not Progress.can_buy(skill)
	button.modulate = maxed_color if maxed else Color.WHITE


func _show_details(skill: String) -> void:
	_shown_skill = skill
	var entry: Dictionary = Progress.SKILLS[skill]
	details.text = "%s: %s" % [entry.name, entry.about]
	if entry.has("requires"):
		details.text += "  (needs %s)" % _needs_text(entry.requires)


func _unmet(requires: Dictionary) -> Dictionary:
	var unmet := {}
	for skill: String in requires:
		if Progress.rank(skill) < requires[skill]:
			unmet[skill] = requires[skill]
	return unmet


func _needs_text(requires: Dictionary, limit := 99) -> String:
	var needs := PackedStringArray()
	for skill: String in requires:
		if needs.size() < limit:
			needs.append("%s %d" % [Progress.SKILLS[skill].name, requires[skill]])
	return ", ".join(needs)
