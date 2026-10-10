# Нахарро / Project Doomsday — памятка для Claude

Изометрическая RPG на Godot 4.7.2 (GDScript). Сюжет, мир, механики — `docs/design.md` (читать только нужный раздел, файл большой).

## Как работаем
- Пользователь — новичок, пишет по-русски. Всё делаю сам: правки, проверка тестами и скриншотами, коммит и пуш.
- Ветка — **`beta`** (не main). Push: `git push -u origin beta`.
- Подпись коммита в конце сообщения:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: <ссылка на текущую сессию>
  ```
  Идентификатор модели в коммиты и код не писать.
- После каждой партии: 2–4 ключевых скриншота + сборка Windows (zip из трёх частей < 30 МБ) через SendUserFile, итог по-русски коротко.
- Экономим токены: не читать большие файлы целиком (grep / sed -n), смотреть только нужные скриншоты, в логах тестов — только `FAIL|ИТОГ|SCRIPT ERROR`.

## Godot
- Установка (если нет): `tools/setup_godot.sh` → `G=~/godot/Godot_v4.7.2-stable_linux.x86_64`.
- После новых ассетов / class_name: `$G --headless --path . --import`.
- Проверка скриптов (должно быть «Проверено, ошибок: 0»): `$G --headless --path . res://tools/check.tscn`.
- Синтаксис скрипта сборщика до запуска: `$G --headless --check-only --script tools/<файл>.gd` — ошибка разбора в headless-сборке вешает процесс.
- GDScript: тип при выводе из элемента массива/Variant указывать явно (`var p: Vector3 = arr[i]`), иначе ошибка разбора.

## Сборщики (генерируют сцены — руками .tscn не править)
| Что | Запуск (`$G --headless --path . res://tools/…`) |
|---|---|
| Постройки и растения (`scenes/props`) | `build_props.tscn`; только избы: `build_props.tscn -- houses` |
| Городские / сельские пропсы | `build_city.tscn`, `build_rural.tscn` |
| Нахарро | `build_nakharro.tscn` |
| Кресты, лагерь, встречи, заимка, конвой, база, подпол, светёлки, бункер, Сунгар | `build_act1.tscn` (всё) / `build_sungar.tscn` (только Сунгар) |

После сборки: `tools/revert_churn.sh` — откатывает сцены, где изменились только `unique_id`.
Новая локация — добавить путь в `LOCATIONS` в `scripts/main.gd`.

## Тесты
- Смоук-тест всей игры (~10 мин, запускать в фоне, оба варианта):
  `timeout 1700 $G --headless --path . res://tools/smoke_test.tscn > sm1.log` и то же с `-- stealth`. Итог: `=== ИТОГ: ошибок 0 ===`.
- Аудит откликов: `res://tools/audit_interact.tscn` → «молчаливых: 0».
- В тестах `Clock.force_day = true` (все на работе). Хелпер проходимости `unreachable(loc, start, only)` в `tools/smoke_test.gd`. Проёмы — не уже 1,9 м.
- Новое содержимое — сразу дописывать проверки в smoke_test.gd.

## Скриншоты
`xvfb-run -a -s "-screen 0 1600x900x24" $G --rendering-driver opengl3 --resolution 1600x900 --path . res://tools/render_shots.tscn -- "кадры" префикс`
Формат кадров — в шапке `tools/render_shots.gd` (локация|x|z|zoom|час|флаги, MAP, WAIT). Один проп: `tools/preview_prop.tscn`.

## Сборка Windows
```
$G --headless --path . --export-release "Windows" build/windows/Nakharro.exe
cd build && zip -q -9 -r -s 25m Nakharro_split.zip windows   # → .zip .z01 .z02
```
`build/` в .gitignore.

## Данные (`data/`)
- `characters.json`, `items.json` — одна запись на строку; править через `tools/data_lib.py` (load/dump сохраняют стиль).
- Диалоги `data/dialogs/*.json`: условия `if` (flag, not_flag, flags, quest+stage/stage_min/stage_max, item, cond → `dialog_cond` локации, rep_min/max), эффекты (take, give, xp, quest, set_flags, note, rep, action, check/success/fail), `text_if`.
- Расписание жителей — `schedules.json` (from/to, home_node, sleep, plan [[с,до,x,z,поза,поворот]]).
- Карта мира, встречи, тропы — `world.json`; клочки лора — `lore.json`; реплики — `barks.json`.

## Устройство кода
- `scripts/main.gd` — загрузка локаций, ввод, разговоры, ожидание (`wait_hours`).
- `scripts/core/` — `game_state.gd` (Game: флаги, задания, предметы), `clock.gd` (время, свет, расписание/сон), `graphics.gd`, `rules.gd`.
- `scripts/locations/*.gd` — логика локаций (on_interact, item_actions, describe, objective).
- `scripts/ui/` — HUD, диалоги, КПК, карта мира, окно ожидания.
