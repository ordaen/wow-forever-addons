---
name: text-ru
description: How to write Russian (ruRU) player-facing text for Ordaen addons. Use whenever you add or change a string in any addons/*/locales/ruRU.json, a ruRU line in addon.jsonc (notes, title) or ordaen.jsonc, or Russian text on a CurseForge page, changelog or popup. Pair with the text-en skill for the English string.
---

# Russian player-facing text

The user plays on a ruRU client. Every Russian string is read by players in the game, so it has to be short,
exact and natural Russian, never a word-for-word translation of the English.

## Rules

1. **Mouse buttons are ЛКМ and ПКМ.** Hints read `ЛКМ: открыть панель`, `ПКМ: настройки`, `Shift+ЛКМ: …`,
   `Перетащить ЛКМ: …` (or `Перетаскивание: …` where only one button drags). Never "щелчок", "правый щелчок",
   "клик", "нажмите левой кнопкой мыши".
2. **No fluff.** Say what it is or what it does, nothing else: no "Эта настройка позволяет…", "Здесь вы можете…",
   "пожалуйста", exclamation marks, marketing words ("удобный", "мощный"). The first words carry the meaning.
3. **Clear instructions.** One action per sentence, in the imperative (`Введите /reload`, `Выключите одну из них`).
   Say the result or the reason only when the player needs it (`…, чтобы вернуть кнопки на миникарту`).
4. **The game's own words.** Use the terms Blizzard's ruRU client uses for its UI (Миникарта, Календарь, Карта мира,
   Модификации in the AddOns list, Настройки), so players find what we name. Prefer Blizzard's translated globals
   (`CLOSE`, `OKAY`, `CANCEL`, `RESET`, `SETTINGS`) over our own strings when they fit (CLAUDE.md, Localization).
5. **Same thing, same word.** Once a thing has a name (`панель кнопок`), every string uses that name.
6. **Form.** Labels and buttons: a noun or a short phrase, capital first letter, no full stop (`Стиль рамки`).
   Tooltips and messages: full sentences with a full stop. Hint lines `Действие: результат`, no full stop.
   Use `ё` where Russian needs it (`её`). Quotes «ёлочки». A dash is ` — ` with spaces.
7. **Length.** Russian runs about 20–30% longer than English: keep the meaning, cut the words, so a label still fits
   where the English one does. Text in our UI wraps but never truncates (the framework), so a long string costs
   space, not words.
8. **Placeholders.** `%s`, `%d` stay in the same order and count as in enUS (the build refuses a mismatch); build
   the sentence so case endings work for any value (`Модификация %s` rather than `%s модификации`).
9. **NPC stays NPC:** write the English abbreviation `NPC` in Russian text, never «НПЦ»
   (`Подсказки NPC`).
10. **CD in compact places:** where room is short (a tooltip line, a label, a bar) a
    cooldown reads `CD 15 сек.`, the English abbreviation; in sentences it stays «восстановление»
    (`Время восстановления сбрасывается при смерти`).

## Examples

| Bad | Good |
|---|---|
| Щелчок: открыть или закрыть панель | ЛКМ: открыть или закрыть панель |
| Правый щелчок: настройки часов | ПКМ: настройки часов |
| Эта опция позволяет вам скрыть кнопку модификаций | Скрыть кнопку модификаций Blizzard |
| Пожалуйста, перезагрузите интерфейс! | Введите /reload. |
| Подсказки НПЦ | Подсказки NPC |
| Восст.: 15 сек. (в строке подсказки) | CD 15 сек. |
