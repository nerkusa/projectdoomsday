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
- После каждой партии: 2–4 ключевых скриншота через SendUserFile, итог по-русски коротко. Сборку Windows **не присылать** (только если попросит).
- Крупные изменения внешнего вида — сначала показать превью и спросить, потом коммитить.
- Экономим токены: не читать большие файлы целиком (grep / sed -n), смотреть только нужные скриншоты, в логах тестов — только `FAIL|ИТОГ|SCRIPT ERROR`.
- **Где что читать — `docs/code_map.md`** (не читать целиком!): `grep -n -i 'тема' docs/code_map.md` → там файл и строки (разделы design.md, задание → файлы, место карты → сцена/скрипт, диалог → сборщик:строка, функции `имя:строка`). Потом `sed -n 'a,bp' файл`. Обновляется сама перед каждым `git commit` (хук `.claude/hooks/code_map.sh`); вручную — `python3 tools/gen_code_map.py`.

## Память (действует и после сжатия контекста)
- **Всегда по-русски**: ответы, итоги, сообщения коммитов, комментарии в коде. На английский не переходить, даже в длинной сессии.
- **Концепция — из design.md, не по памяти.** Перед работой над локацией/персонажем/заданием: `grep -n 'Название' docs/code_map.md` → прочитать свой раздел design.md. Черты одной локации на другую не переносить:
  - Нахарро — закрытая таёжная деревня беглецов «Горизонта», сожжена в прологе.
  - Кресты — первое живое поселение рядом, расспросы про Боотура.
  - Сунгар — торговый ПГТ на реке: рынок, платный вход, бюро йегерей (сбор «на защиту Полиса», самосуд), подёнщики. Деловой, а не «город грехов»: ни казино, ни конторы.
  - Мар-Кун — одичавшие внуки беглецов другой корпорации, скудная опасная земля.
  - Нью-Рба — большой «город грехов» на алмазах, продаётся всё; афера с фальшивыми алмазами.
  - Мирный — город контрастов и идей: центр (ничейная земля, мёртвый карьер «Мир», промзона ГОК, барахолка) и 4 района фракций отдельными локациями. «Промзона МИР» — часть Мирного, не отдельное место.
  - ГЭС — последняя дежурная смена, за неё борются фракции Мирного.
  - Горный — спокойное поселение под «Горизонтом»: свет, еда, порядок.

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
| Нью-Рба (4 района + коллектор) | `build_nyurba.tscn` |
| Мар-Кун, Мирный (центр + 4 района + карьер), ГЭС, Рубикон, Горный, ГРЭС-2 и комплекс | `build_east.tscn -- markun\|mirny\|ges\|rubikon\|gorny\|complex` |

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

## Свои модели персонажей (Tripo / Mixamo)
- Модель `.glb` со скелетом Mixamo — в `assets/models/<имя>/`; в её `.import` прописать перенос (`_subresources` → `PATH:Armature/Skeleton3D`: `retarget/bone_map` = `bonemap_mixamo.tres`, `make_unique` → `GeneralSkeleton`), как у `jaeger_elite.glb.import`. Карты костей — `tools/make_bonemaps.gd`.
- Анимации — общая библиотека `assets/models/anim_humanoid.glb` (копия манекена на «человеческом» скелете). В шаблоне персонажа: `look.model`, `look.model_scale` (Tripo ≈ 1 м → ~1,9), `look.anim_mask`: `"upright"` — без наклонов спины (у Tripo-моделей иначе сутулость), `"legs"` — только ноги; `look.own_weapon` — оружие вылеплено в модели, в руку не вешать. Проверка: `tools/preview_char.tscn -- out.png "res://модель.glb@Idle@1.95@upright"`.
- Превью: `tools/preview_char.tscn -- out.png "шаблон@клип,res://модель.glb@клип@масштаб" размер`.

Надписи на вывесках/экранах (Label3D) — через `fit_label(label, ширина, высота)` из build_scenes.gd: подгоняет масштаб под доску; «ВНИМАНИЕ: мелкая надпись» при сборке — сократить текст.

## Сборка Windows
```
$G --headless --path . --export-release "Windows" build/windows/Nakharro.exe
cd build && zip -q -9 -r -s 25m Nakharro_split.zip windows   # → .zip .z01 .z02
```
`build/` в .gitignore.

## Данные (`data/`)
- `characters.json`, `items.json` — одна запись на строку; править через `tools/data_lib.py` (load/dump сохраняют стиль).
- Диалоги `data/dialogs/*.json`: условия `if` (flag, not_flag, flags, quest+stage/stage_min/stage_max, item, cond → `dialog_cond` локации, rep_min/max), эффекты (take, give, xp, quest, set_flags, note, rep, action, check/success/fail), `text_if`.
- **Без метагейминга:** реплика, где герой отдаёт вещь и задание идёт дальше 1-го этапа, обязана проверять это задание (`"quest": id, "stage"…`). `check.tscn` ловит нарушения («МЕТАГЕЙМИНГ: …»). Деньги (rubles, salt) — оплата, не сдача. `Game.set_quest` этап назад не откатывает.
- Расписание жителей — `schedules.json` (from/to, home_node, sleep, plan [[с,до,x,z,поза,поворот]]).
- Карта мира, встречи, тропы, реки, переправы, места взрывов (`blasts`) — `world.json` (картинку 6400×3486 и `world_biome.png` перерисовывает `python3 tools/gen_world_map.py`, ~2 мин; реки непроходимы, места не должны стоять в воде); клочки лора — `lore.json`; реплики — `barks.json`.

## Устройство кода
- `scripts/main.gd` — загрузка локаций, ввод, разговоры, ожидание (`wait_hours`).
- `scripts/core/` — `game_state.gd` (Game: флаги, задания, предметы), `clock.gd` (время, свет, расписание/сон), `graphics.gd`, `rules.gd`.
- `scripts/locations/*.gd` — логика локаций (on_interact, item_actions, describe, objective).
- `scripts/ui/` — HUD, диалоги, КПК, карта мира, окно ожидания.
