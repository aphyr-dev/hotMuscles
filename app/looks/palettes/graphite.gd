extends RefCounted
## Graphite palette - black + white, no colour
## a palette is colours only; the style (app/looks/styles/) decides shapes and feel. To add one: copy
## this file, change the name and colours, list it in app/looks/looks.gd

const paletteName: String = "Graphite"
const colours: Dictionary = {
	"page": Color("#0a0a0a"),
	"bg": Color("#111111"),
	"surface": Color("#1a1a1a"),
	"surfaceHi": Color("#242424"),
	"line": Color("#2e2e2e"),
	"text": Color("#f2f2f2"),
	"textMuted": Color("#9a9a9a"),
	"textFaint": Color("#626262"),
	"accent": Color("#f2f2f2"),
	"accentText": Color("#111111"),
	"cold": Color("#4d7dff"),
	"neutral": Color("#50c878"),
	"hot": Color("#ff4136"),
	"ghost": Color("#7ff0ff"),
	"bodyPlain": Color("#3a3a3a"),
	"bodyCosmetic": Color("#2a2a2a"),
	"bodyGap": Color("#080808"),
}
