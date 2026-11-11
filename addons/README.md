# The Ordaen addons

The addons are written in LunaType. Their sources are in the `lunatype` repository, under `addons/`: `Ordaen` (the
core), `OrdaenApp` (the program's root, which tells the core of every module), `OrdaenLibrary`, `OrdaenSettings`,
`OrdaenMinimap`, `OrdaenPanel`, `OrdaenProfessions`, `OrdaenTooltips` and `OrdaenDev`. `lunatype build addons <out>`
writes the Lua the game loads; `scripts/link.ps1` there puts a build into the game's AddOns folder.

The Lua addons these replace, with their tests, are in `_old/lua/`.
