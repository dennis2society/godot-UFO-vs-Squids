extends Node
## Medals earned during this play session. Not saved, so they reset on quit.

const MEDALS := [
	{"name": "Bronze", "color": "#cd7f32"},
	{"name": "Silver", "color": "#c0c8d0"},
	{"name": "Gold", "color": "#ffd030"},
]

var _best := {} ## Mission name to {"medal": index into MEDALS, "time": seconds}.


## Keeps the best result per mission. Longest_wins suits survival, where more time
## is better, instead of races where the fastest time is.
func award(mission: String, medal: int, time: float, longest_wins := false) -> void:
	if Progress.demo:
		return
	if not _best.has(mission):
		_best[mission] = {"medal": medal, "time": time}
		return
	var best: float = _best[mission].time
	if time > best if longest_wins else time < best:
		_best[mission] = {"medal": medal, "time": time}


## Seconds as "m:ss" from a minute up, otherwise with hundredths for close races.
func format_time(time: float) -> String:
	return "%.2f s" % time if time < 60.0 else format_clock(time)


## Seconds as "m:ss", for running clocks.
func format_clock(time: float) -> String:
	return "%d:%02d" % [int(time) / 60, int(time) % 60]


## BBCode lines for the menu, or an empty string if nothing has been earned yet.
func summary() -> String:
	var lines := PackedStringArray()
	for mission in _best:
		var result: Dictionary = _best[mission]
		var medal: Dictionary = MEDALS[result.medal]
		lines.append("Best this session: %s  [color=%s]● %s[/color]  %s" % [
			mission, medal.color, medal.name, format_time(result.time)
		])
	return "\n".join(lines)
