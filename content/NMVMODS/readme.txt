NMV content packs go here, one folder per mod:

	content/NMVMODS/<mod>/meta.json          { "name": "...", "description": "..." }
	content/NMVMODS/<mod>/data/weeks/*.json  week definitions (NMV schema)
	content/NMVMODS/<mod>/songs/<song>/      Inst.ogg / Voices.ogg / data/normal.json / <song>.hx
	content/NMVMODS/<mod>/scripts/           global scripts (loaded with PlayState)
	content/NMVMODS/<mod>/stages/            stage json / hx
	content/NMVMODS/<mod>/images|music|sounds|shaders|fonts|data/

A pack shows up as a tab on the main menu (switch with TAB or click). While that tab
is active, Freeplay lists only that pack's songs and the engine loads the pack's
scripts through Paths.currentContentRoot.

Week JSON is converted on load: NMV song tuples are
[title, icon, color, portrait, composer, ...] and FE only reads
[title, character, color, musician, charters], so portrait is dropped and
composer moves to the musician slot.

Packs are unlocked as a whole (NMV's Cosmicube / bean unlock system is not ported).
