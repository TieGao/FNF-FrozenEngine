Here's a Q&A!

Q: Where should I put my charts?
A: "assets/shared/data/".

Q: Where should I put my songs?
A: "assets/songs/".

Q: Where should images, characters, weeks, stages, sounds and other JSONs files go?
A: You can put them in "assets/shared/" or "assets/week_assets/your-week-folder/"! Really depends on your preference.

Q: I don't want base game assets in my mod! What should I do??
A: Compile with "-D NO_BASE_GAME_FILES" (or delete the line with "BASE_GAME_FILES" in Project.xml).
You can safely delete the "assets/base_game/" folder after that if you want to, but virtually it won't have any effect when you compile.

Q: Where do MY OWN resources go, the ones I add on top of the base game?
A: "assets/shared/". NEVER put them in "assets/base_game/" - that whole folder is dropped when you
compile with NO_BASE_GAME_FILES, and anything you add there later goes with it.
"assets/shared/" is always packaged, and it is the last fallback of Paths.getPath().

Q: What's the "translations" folder for?
A: This is where I've put the Portuguese translation in, you can also set up other languages inside it easily,
You can turn off languages by deleting the line with "TRANSLATIONS_ALLOWED" inside Project.xml