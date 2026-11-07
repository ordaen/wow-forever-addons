# Forever tooltip data (measured live)

What `tooltip:GetTooltipData()` (and `C_TooltipInfo.*`) returns on Forever, read in game with OrdaenTooltips' dev
probe, which is part of its dev dump. The API dump in `1.60.1-70790/` lists `Enum.TooltipDataLineType` without values,
so the numbers below are what the client actually sent. Client: 1.60.1-70790, ruRU, 2026-11-07.

**Re-measuring:** with OrdaenCore_Debug installed, hover what you need (the probe keeps the last 20 different tooltips per kind:
items, spells and units; dev mode only), then click **Send state** in the Ordaen Dev window. `wow_dump OrdaenTooltips` →
`takeover.probe` has one line of text per tooltip line, `takeover.strings` has Blizzard's stat strings, and
`takeover.paperDoll` has the character tab's stat tooltips. Code: `Reader.lastData`, and `probe()` / `paperDoll()` in
`addons/OrdaenTooltips/Takeover.lua`.

## Tooltip kinds (`data.type`, `Enum.TooltipDataType`)

| type | kind | top-level fields seen |
|---|---|---|
| 0 | item | `id`, `guid` (own items) or `hyperlink` (auction, links: with bonus IDs, e.g. random suffixes; for a recipe, the link is the made item's), `isAzerite…`, `isCorruptedItem`; `overrideItemLevel` on some (drinks, ammo; not gear) |
| 1 | spell | `id` |
| 2 | unit | `guid`, `healthGUID` |
| 4 | (frame text, e.g. a button) | none |
| 7 | aura (a buff or debuff) | `id` (its spell) |
| 21 | (empty) | none |
| 25 | macro / action | `id` |

## Line types (`line.type`)

| type | what | extra fields | example (ruRU) |
|---|---|---|---|
| 0 | plain text (most lines) | none | «Броня: 191», «+3 к силе», «Урон: 7-13» \| «Скорость 2,60», «(3,8 ед. урона в секунду)», «Прочность: 35 / 35», «Устойчивость: +10 огонь», «Если на персонаже: …», a set's header, «Уникальный использующийся», «<Изготовитель: …>», «У вас еще нет такой модели.» |
| 1 | blank separator | none | « » |
| 2 | unit name | `unitToken` (`mouseover`, `target`, `nameplateN`) | «Эндрю Крайтон» |
| 11 | sell price (the money frame; on Forever the coins are in the text too) | `price` (copper), `maxPrice` | «» |
| 13 | spell name | right side: rank («Уровень 1», «Ученик») | «Боевой крик» |
| 16 | unit owner (a pet's) | `guid` (the owner) | «Прислужник \|3-1(Caéna Daerek)» |
| 19 | nested block: the item a recipe makes; its own lines follow inline (its name is a type 22 line starting with a newline) | **`tooltipID`** (the made item's ID), `tooltipType` (0 = item) | «» |
| 20 | binding | `bonding`: 3 = already soulbound («Персональный предмет»), 7 = binds on equip | «Становится персональным при надевании» |
| 21 | slot · type | left: slot, right: type (empty for rings, trinkets, shirts…); `isValidInvSlot` (false: the slot is red too, e.g. a weapon type you can't train), `isValidItemType` (false: the type is red, you can't use it) | «Одноручное» \| «Дробящее» |
| 22 | item name | `quality` | «Медная палица» |
| 33 | «Пассивная» (a passive spell) | none | «Пассивная» |
| 34 | spell description | `wrapText` | «Воин издает боевой крик…» |
| 37 | flavour text (the quote) | `isGameInfo` (false) | «"Так про-100, что даже ваша кошка справится."» |
| 38 | «Использование:» that teaches (a recipe, a pet) | **`spellID`** (the learned spell) | «Использование: Обучает изготовлению яркоглазых очков.» (12587), «Использование: Учит призывать этого спутника.» |
| 42 | set piece or set bonus (grey when not active) | none | «  Алый пояс», «Комплект (2 \|4предмет:предмета:предметов;): +10 к сопротивлению темной магии.» |
| 43 | requirement | `requirementType` (5 = level, with `level`; 2 = profession; 9 = weapon, on spells; 10 = stance/form), `usable` (false: red) | «Требуется 40-й уровень», «Требуется: Инженерное дело (140)», «Требуется: Оборонительная стойка» |
| 44 | «Использование:» effect | **`spellID`** | «Использование: Повышает сопротивление огню на 33…» (13744) |
| 45 | «Если на персонаже:» as a real equip spell (procs and auras: a quiver's haste, a shield's damage on block) | **`spellID`** | «Если на персонаже: Увеличение скорости дальней атаки на 13%.» (29413), «Если на персонаже: Наносит 6 - 38 ед. урона от сил природы, когда вы блокируете атаку…» (1324686) |
| 46 | «Возможный эффект при попадании:» (chance on hit) | **`spellID`** | «Возможный эффект при попадании: Наносит противнику 42 ед. урона от темной магии.» (1292158) |

Every line also has `leftText`, `leftColor` (a ColorMixin), `lineIndex`, and on two-sided lines `rightText` and
`rightColor`.

## Spells and units

- **Spell:** name (13; right side: the rank «Уровень 1», empty when unranked), then plain lines: cost («Ярость: 10»,
  right side: range «Дистанция ближнего боя» when there is one) or range alone («Радиус действия: 8-25 м.»), cast
  («Мгновенное действие», «Следующая атака»; right side: «Восстановление: 15 сек.»), requirements (43: 9 = weapon,
  10 = stance; `usable`), «Пассивная» (33), the description (34, gold). An unranked spell may carry an empty plain
  line after its name («Атака», racials).
- **Talent** (in the talent tree): a spell tooltip (kind 1, `id` = the talent's spell for the shown rank) whose
  data **starts at line 3**: the talent frame writes the first lines itself (name, «Уровень N/M», next rank), and they
  are not in the data. Then an empty plain line, «Пассивная» (33) or cost and cast for an active talent, and the
  description (34). Learned or not is not in the data: read it from the talent API.
- **Aura** (kind 7, `id` = its spell): all plain lines: the name (gold; right side: the dispel type «Магия»), «ID
  заклинания: 19834» (Forever's own line), the description (white), «Осталось 34 |4минута:минуты:минут;» (gold, the
  plural code again).
- **Player:** name (2, `unitToken`), the guild (a plain line, only when in one), «<race> <N>-го уровня (игрок)», the
  class («Друид», feminine forms for women: «Чернокнижница», «Разбойница»), the faction («Альянс»). All plain: no
  guild, level or class data in the lines; read them from the unit (`unitToken`: `UnitLevel`, `UnitClass`,
  `GetGuildInfo`, `UnitFactionGroup`).
- **NPC:** name (2, in its reaction colour), «Уровень 50», its faction («Штормград»), «PvP» (plain).
- **Pet:** name (2), owner (16, the owner's `guid`: «Прислужник |3-1(…)» for a warlock's, «Питомец |3-1(…)» for a
  hunter's: the case code again), «Уровень 15».
- **Kind 4** also covers labels on the world (a building's name, «Аптека Песта»): one gold plain line.

## What it means for our tooltips

- **Structured (no text parsing):** name and quality (22), binding (20), slot and type and whether you can use it
  (21), required level, profession or stance and whether you meet it (43), «Использование:» and chance-on-hit effects and their spells (44, 46), sell
  price (11), blank lines (1).
- **Plain text (read with Blizzard's format strings, as SpellStats does):** armor, damage, speed, DPS, durability,
  primary stats, resistances («Устойчивость: +N <school>», not «к сопротивлению»), most «Если на персонаже:» effects
  (white for a bonus stat like «+140 к броне», green for an effect: type 0, **no spell ID**; only real equip spells
  are type 45 with one: stat-like effects (attack power, spell power, defense, hit, regen «восполняет 15 ед. здоровья
  раз в 5 сек.») are type 0, procs and auras type 45), a shield's block («Вероятность блока: 30», the block value
  under that label), the set's header, «Уникальный использующийся», a bag's or quiver's size.
- **Recipes:** the recipe's name (22), then a nested block (19, `tooltipID` = the item it makes) followed by that
  item's whole tooltip inline, then «Использование: Обучает изготовлению …» (38, the learned spell), the reagents as
  one plain line («Толстая кожа (6), Цитрин (2)»), and the profession requirement (43). The made item can be our side
  tooltip (like the set), by `tooltipID`.
- **Ammo:** slot · type «Боеприпасы» \| «Стрелы» (21), then «Добавляет 13 ед. урона в секунду» (plain).
- **Auction-only line:** «Предметы этой группы обладают разными характеристиками и внешним видом. Проверьте подсказку
  аукциона…» (plain, gold, after a blank line) on browse results.
- **Bags, quivers, ammo pouches** have no slot · type line (21): one plain line «Сумка (12 |4ячейка:ячейки:ячеек;)»,
  «Колчан (16 …)», «Подсумок (16 …)» (`CONTAINER_SLOTS`-like, with the plural code).
- **Not in the tooltip at all:** item level (Forever doesn't print it on gear): read it from the item's info by ID.
- **Grammar codes in the text:** set bonus lines carry the plural code (`|4one:few:many;`), wand damage the case code
  (`|3-6(природа)`): render them before showing the text anywhere of our own.
- **School damage (wands, elemental weapons)** has no «Урон:» prefix: «36 - 67 ед. |3-6(природа)» \| «Скорость 1,90»
  (`DAMAGE_TEMPLATE_WITH_SCHOOL`, `SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL`, the school from `DAMAGE_SCHOOL2`…`7`); plain
  physical damage is «Урон: 7-13» (`DAMAGE_TEMPLATE`).
- **«Уникальный»** and «Уникальный использующийся» are plain lines after the binding (`ITEM_UNIQUE`,
  `ITEM_UNIQUE_EQUIPPABLE`).
- **Nested tooltips:** a spell tooltip for types 38, 44, 45 and 46 (their `spellID`); an item for type 19 (`tooltipID`); the owner for type 16 (`guid`); set pieces have no
  IDs (look them up by name); stats and «Если на персонаже:» have nothing behind them: our own text or Blizzard's stat
  strings below.

## Blizzard's stat strings (ruRU values)

The character tab's tooltips use these; they are translated by the game, so nested stat tooltips can use them as is.
Functions behind the numbers (all in the API dump): `GetAttackPowerForStat`, `PaperDollFrame_GetArmorReduction`,
`GetUnitMaxHealthModifier`, `GetManaRegen`, `GetDodgeChance`.

| global | value |
|---|---|
| `SPELL_STAT1_NAME` … `SPELL_STAT5_NAME` | Сила, Ловкость, Выносливость, Интеллект, Дух |
| `RESISTANCE0_NAME` … `RESISTANCE6_NAME` | Броня; Сопротивление светлой магии, огню, силам природы, магии льда, темной магии, тайной магии |
| `DEFAULT_STAT2_TOOLTIP`, `STAT_TOOLTIP_BONUS_AP` | Увеличивает мощность ваших атак и способностей. |
| `DEFAULT_STAT3_TOOLTIP` | Увеличивает запас здоровья на %s. |
| `DEFAULT_STAT4_TOOLTIP` | Увеличивает мощность ваших заклинаний. |
| `STAT_ARMOR_TOOLTIP` | Уменьшает получаемый \|cFFFFFFFFфизический урон\|r на %0.2f%% … Бонус от ловкости |
| `STAT_ARMOR_TOTAL_TOOLTIP` | Общее уменьшение физического урона за счет брони: %0.2F%% |
| `STAT_ARMOR_TARGET_TOOLTIP` | Снижение на %0.2f%% в бою с текущей целью |
| `ARMOR_TOOLTIP` | Снижает урон от оружия в зависимости от уровня нападающего. Если уровень нападающего %d, то урон будет: %.1f%% |
| `MELEE_ATTACK_POWER_TOOLTIP` | Увеличивает урон в секунду от оружия ближнего боя на %s … Каждые 14 ед. силы атаки увеличивают урон в секунду на 1 ед. |
| `RANGED_ATTACK_POWER_TOOLTIP` | the same for ranged weapons and agility |
| `STAT_ATTACK_POWER` | Сила атаки |
| `ATTACK_SPEED_TOOLTIP1` | Длительность атаки (в секундах) |
| `STAT_ATTACK_SPEED_BASE_TOOLTIP` | Скорость атаки повышена на +%s%%. |
| `DAMAGE_TOOLTIP`, `DAMAGE_PER_SECOND` | Урон от оружия; Урон в секунду |
| `STAT_BLOCK_TOOLTIP` | Увеличивает блокируемый урон на %d. |
| `CR_BLOCK_TOOLTIP` | Блокирование уменьшает получаемый от атаки урон на %0.2f%%. (В бою с равным по силе врагом) |
| `CR_CRIT_MELEE_TOOLTIP` | Вероятность нанести дополнительный урон при атаке. Показатель крит. удара: %s (вероятность +%.2F%%). |
| `CR_DODGE_TOOLTIP` | Показатель уклонения %d повышает вероятность уклонения на %.2F%%. … |
| `STAT_HEALTH_TOOLTIP` | … 1 ед. выносливости добавляет 10 ед. здоровья |
| `STAT_MANA_TOOLTIP` | … 1 ед. интеллекта добавляет 15 ед. маны |
| `RESISTANCE_TOOLTIP_SUBTEXT` | Повышает устойчивость персонажа к заклинаниям, навыкам и атакам, в ходе которых используется %s. Сопротивление атакам противников %d-го уровня: %s%% |
| `STAT_MOVEMENT_GROUND_TOOLTIP` | Скорость бега: %d%% |
| `STAT_NO_BENEFIT_TOOLTIP` | Эта характеристика бесполезна для вас (grey) |
| `STAT_USELESS_TOOLTIP` | Эта характеристика бесполезна для вашего класса (grey) |
| `STAT_AVERAGE_ITEM_LEVEL_TOOLTIP` | Средний уровень предметов вашего снаряжения. |
| `ITEM_LEVEL` | Уровень предмета: %d |
| `ITEM_BIND_ON_EQUIP`, `ITEM_BIND_ON_PICKUP`, `ITEM_UNIQUE`, `DURABILITY` | Становится персональным при надевании; Становится персональным при поднятии; Уникальный; Прочность |

## The character tab's stat tooltips (this character)

Blizzard's own output for the character, on the stat frames under `CharacterStatsPane` (and its
`CharacterStatsPaneScrollBox`): `.tooltip` (the header) and `.tooltip2` (the text). They exist only after the
character tab was opened once. Measured on a level 10 warrior:

| `.tooltip` | `.tooltip2` |
|---|---|
| Сила 35 | Повышает силу атаки на 70 · Повышает вероятность блокирования на 1 |
| Ловкость 22 | Повышает вероятность критического удара на 4.2% · Повышает силу атаки в дальнем бою на 44 · Укрепляет броню на 44 · Повышает вероятность уклонения на 4.2% |
| Выносливость 37 (34+3) | Увеличивает запас здоровья на 190 |
| Интеллект 20 | Повышает скорость развития навыка владения оружием (a warrior: no mana) |
| Дух 22 | Повышает скорость восполнения здоровья вне боя на 27 ед. раз в 5 сек. · Восстановление здоровья ускоряется на 33%, пока персонаж сидит… |
| Броня: 452 | Уменьшает получаемый физический урон на 26.56% · Бонус от ловкости |
| Здоровье: 291 | `STAT_HEALTH_TOOLTIP` |
| Ярость: 100 | Ресурс для применения способностей … Вне боя вы теряете 1,25 ед. ярости раз в 1 сек. |
| Сила атаки: 105 (80+25) | Увеличивает урон в секунду от оружия ближнего боя на 7,5 … (`MELEE_ATTACK_POWER_TOOLTIP`) |
| Сила атаки дальнего боя:: 34 | Увеличивает урон в секунду от оружия дальнего боя на 2,4 … |

The texts depend on the class (intellect for a warrior; agility gives attack power only to some classes). A nested
tooltip for an item's stat computes the same numbers for the item's own amount with the API above and these strings
(e.g. «+7 к силе»: +14 к силе атаки, +1 к блоку for this warrior), rather than reading the frames.

## Still to measure

Class restriction («Классы: …»), reputation requirement; the character tab's texts for a caster class; hostile,
elite, rare, quest and critter NPCs.
