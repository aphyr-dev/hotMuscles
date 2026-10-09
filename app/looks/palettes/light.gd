extends RefCounted
## Light palette - light grey + blue
## a palette is colours only; the style (app/looks/styles/) decides shapes and feel. To add one: copy
## this file, change the name and colours, list it in app/looks/looks.gd

const paletteName: String = "Light"
const colours: Dictionary = {
	"page": Color("#e2e5ea"),
	"bg": Color("#eceef1"),
	"surface": Color("#ffffff"),
	"surfaceHi": Color("#f1f3f6"),
	"line": Color("#d5d9e0"),
	"text": Color("#1b1e24"),
	"textMuted": Color("#525459"),
	"textFaint": Color("#727477"),
	"accent": Color("#2f6bff"),
	"accentText": Color("#ffffff"),
	"cold": Color("#2f5bff"),
	"neutral": Color("#2fae64"),
	"hot": Color("#ff2a1a"),
	"ghost": Color("#00a6d6"),
	"bodyPlain": Color("#ccd0d7"),
	"bodyCosmetic": Color("#b9bec6"),
	"bodyGap": Color("#3a3f48"),
}
