class_name Palette
extends RefCounted
## Every colour the game draws with, in one place.
##
## The map and the characters use the Ninja Adventure pack's palette (its
## Palette.png), extended with the cream walls and blue doors of a Tunisian
## lycée. The UI colours follow, and every pair of text and background colour
## the UI uses is listed in [constant TEXT_PAIRS]; tests/contrast_test.gd checks
## each reaches [constant MIN_CONTRAST], WCAG's AAA level, so text stays legible
## on a washed-out projector.
##
## The art generators in tools/ read the colours below from this file, so a
## colour changed here changes the drawn art when they run again.


## The WCAG contrast ratio every text colour must reach on its background.
const MIN_CONTRAST: float = 7.0

#region The map palette

## The pack's outline, darkest colour and shadow ink.
const OUTLINE: Color = Color("141b1b")
const WHITE: Color = Color("ffffff")
## Warm ground and skin tones from the pack.
const SAND_LIGHT: Color = Color("ffe18d")
const SAND: Color = Color("f1c471")
const SAND_DARK: Color = Color("d2b37d")
const PEACH: Color = Color("ffcba9")
const SKIN_LIGHT: Color = Color("ffbc75")
const SKIN: Color = Color("f2ad7d")
const SKIN_MID: Color = Color("d3865f")
const SKIN_DARK: Color = Color("bd7959")
const WOOD_LIGHT: Color = Color("c8966b")
const WOOD: Color = Color("a3754e")
const WOOD_DARK: Color = Color("965340")
const BROWN_DARK: Color = Color("61372e")
const ORANGE_LIGHT: Color = Color("ffad5d")
const ORANGE: Color = Color("ef914f")
const ORANGE_DARK: Color = Color("e46d3a")
const RED: Color = Color("d14b34")
const RED_BRIGHT: Color = Color("e0394c")
const PINK: Color = Color("ef9597")
const ROSE: Color = Color("cf736d")
const WINE: Color = Color("8f3e56")
const MAUVE: Color = Color("a5608b")
const LILAC: Color = Color("d3a2c0")
const PLUM: Color = Color("543c52")
const SLATE: Color = Color("4a5270")
const TEAL_DARK: Color = Color("2d697b")
const TEAL: Color = Color("548789")
const SKY: Color = Color("79b8ce")
const SKY_LIGHT: Color = Color("b8dce5")
const MIST: Color = Color("f2eaf1")
const LEAF_DARK: Color = Color("56864c")
const LEAF: Color = Color("74a334")
const OLIVE: Color = Color("a8a129")
const LEAF_LIGHT: Color = Color("adbc3a")
const PINE_DARK: Color = Color("345a52")
const SAGE_DARK: Color = Color("5f7160")
const SAGE: Color = Color("8d977f")
const SAGE_LIGHT: Color = Color("abc2bc")
const GREY_DARK: Color = Color("4e484a")
const GREY: Color = Color("695953")
const GREY_MID: Color = Color("8e7c73")
const GREY_LIGHT: Color = Color("b3957f")
const NIGHT: Color = Color("3b3643")

## The lycée's own colours, which the pack does not have: rendered walls in
## white and cream, and the blue of doors and window frames.
const WALL_WHITE: Color = Color("fffaf0")
const WALL_CREAM: Color = Color("fbeed6")
const WALL_SHADE: Color = Color("e8d5b5")
const WALL_DEEP: Color = Color("c9b08e")
const DOOR_BLUE_LIGHT: Color = Color("5b9ee8")
const DOOR_BLUE: Color = Color("2f74d0")
const DOOR_BLUE_DARK: Color = Color("1d4e9e")
const DOOR_NAVY: Color = Color("173a73")
const BOARD_GREEN: Color = Color("2f5d4a")
const BOARD_GREEN_LIGHT: Color = Color("3f7a60")
const FLAG_RED: Color = Color("e70013")
const STEEL: Color = Color("9aa8b5")
const STEEL_DARK: Color = Color("5f6d7a")

#endregion

#region The UI colours

## The panel every text box sits on, near-opaque.
const PANEL: Color = Color("1d2433")
const PANEL_ALPHA: float = 0.95
## A lighter panel, behind the selected row of a list.
const PANEL_RAISED: Color = Color("2a3346")
## Body text on a panel.
const TEXT: Color = Color("f3efe2")
## Headings, the selected row, "The room chose B".
const FOCUS: Color = Color("ffd75e")
## Narration, which has no speaker.
const NARRATION: Color = Color("a9c1d9")
## Hints, and cards not yet collected.
const DIM: Color = Color("b4bccb")

## The concept cards' lecture-slide paper.
const PAPER: Color = Color("f3efe2")
const INK: Color = Color("222831")
const SLIDE_ACCENT: Color = Color("1a4a80")
const TERM: Color = Color("7a3016")
const FAINT: Color = Color("4f4a40")
const RIGHT_CALL: Color = Color("17521c")
const MISS: Color = Color("9b1c1c")

## The room's A, B and C cards: A blue, B orange, C green, each with the
## letter's colour, which passes on the card, and the light and dark edges
## that give the letters their 3D look.
const VOTE_CARDS: Array[Dictionary] = [
	{ "letter": "A", "card": Color("1d4e9e"), "text": Color("ffffff"), "light": Color("79b8ce"), "dark": Color("0d2a5c") },
	{ "letter": "B", "card": Color("ffad5d"), "text": Color("141b1b"), "light": Color("ffe18d"), "dark": Color("d14b34") },
	{ "letter": "C", "card": Color("7ccf4a"), "text": Color("141b1b"), "light": Color("e3f59a"), "dark": Color("3f7a2a") },
]

## The vote bar, filling and once the time is up. Not text.
const VOTE_BAR: Color = Color("ffd75e")
const VOTE_OVER: Color = Color("e0394c")
## Meter bars by state. Not text: each meter also has an icon, a label and a number.
const METER_GOOD: Color = Color("74a334")
const METER_WARN: Color = Color("f1c471")
const METER_BAD: Color = Color("e0394c")
const METER_OFF: Color = Color("695953")
const METER_TRACK: Color = Color("0f141e")

## Every text colour and the background it is drawn on, named for the check.
const TEXT_PAIRS: Array[Dictionary] = [
	{ "use": "text on a panel", "text": TEXT, "background": PANEL },
	{ "use": "heading or selected row on a panel", "text": FOCUS, "background": PANEL },
	{ "use": "narration on a panel", "text": NARRATION, "background": PANEL },
	{ "use": "hint or uncollected card on a panel", "text": DIM, "background": PANEL },
	{ "use": "selected row text on a raised panel", "text": FOCUS, "background": PANEL_RAISED },
	{ "use": "text on a raised panel", "text": TEXT, "background": PANEL_RAISED },
	{ "use": "slide text", "text": INK, "background": PAPER },
	{ "use": "slide title and number", "text": SLIDE_ACCENT, "background": PAPER },
	{ "use": "slide key term", "text": TERM, "background": PAPER },
	{ "use": "slide footer and slide range", "text": FAINT, "background": PAPER },
	{ "use": "histogram value inside a bar", "text": PAPER, "background": SLIDE_ACCENT },
	{ "use": "inspection: right call", "text": RIGHT_CALL, "background": PAPER },
	{ "use": "inspection: missed call", "text": MISS, "background": PAPER },
	{ "use": "org chart box label", "text": INK, "background": WHITE },
	{ "use": "room name on its plate", "text": TEXT, "background": PANEL },
	{ "use": "character name on its plate", "text": TEXT, "background": PANEL },
]

#endregion


## The WCAG contrast ratio of two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A name plate for a character's colour: the plate in that colour, darkened
## or lightened just enough that the name's colour passes [constant MIN_CONTRAST]
## on it. Light text on dark colours, dark text on light ones.
static func name_plate(color: Color) -> Dictionary:
	var light_text: bool = contrast(TEXT, color) >= contrast(OUTLINE, color)
	var text: Color = TEXT if light_text else OUTLINE
	var plate: Color = color
	for step: int in 40:
		if contrast(text, plate) >= MIN_CONTRAST:
			break
		plate = plate.darkened(0.05) if light_text else plate.lightened(0.05)
	return { "plate": plate, "text": text }


static func _luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	var linear: Array[float] = []
	for c: float in channels:
		linear.append(c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
