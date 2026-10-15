# Карта кода (сгенерировано tools/gen_code_map.py — руками не править)

Искать тему: `grep -n -i 'слово' docs/code_map.md`, потом читать только указанные строки: `sed -n 'a,bp' файл`.

## docs/design.md — разделы

Project Doomsday — 1–4
Сеттинг — 5–45
  Жанр, стиль и тон — 7–17
  Абсурд и светлые моменты — 18–27
  История мира — 28–45
Мир — 46–124
  Мир в 2062 году — 48–58
  Кто кем правит — 59–77
  Валюта — 78–90
  Снаряжение — 91–124
    Ступени оружия — 95–102
    Оружие по регионам — 103–115
    Броня и одежда — 116–124
Фракции — 125–191
  «Горизонт» (ООО «Системный анализ „Горизонт“») — 127–148
  Правительство и армия — 149–156
  Полис и йегеря — 157–176
  Задел на будущее: мутанты — 177–191
Персонажи — 192–250
  Главный герой — 194–203
  Спутники — 204–211
  Роберт Олегович Кирш — 212–233
  Ключевые персонажи — 234–250
Сюжет — 251–286
  Нахарро — 260–286
Акты — 287–567
  Пролог. Гибель Нахарро — 289–302
  Акт I. Чистильщики — 303–389
    Кресты — 307–323
    Как темнеет след Боотура — 324–329
    Локации: 3 большие и 4 небольшие — 330–341
    Сюжетная линия — 342–349
    Сунгар — 350–381
    Мар-Кун — 382–389
  Акт II. Нью-Рба — 390–437
    Город — 394–401
    Верхушка — 402–410
    Четыре якорные локации — 411–419
    Боотур — 420–431
    Корпорация и сделка — 432–437
  Акт III. Ток — 438–512
    Локации — 442–448
    Мирный: город контрастов — 449–474
    ГЭС: последняя дежурная смена — 475–496
    Главное откровение — 497–500
    Выбор: кому достанется ГЭС — 501–512
  Акт IV. Мерзлота и концовки — 513–567
    Рубикон — 520–531
    Горный — 532–537
    Комплекс под ГРЭС-2 — 538–547
    Расклад по выбору ГЭС — 548–557
    Финал — 558–567
Механика — 568–730
  Игровой цикл — 572–581
  Персонаж — 582–623
    Характеристики — 589–599
    Навыки — 600–623
  КПК и кассеты-перки — 624–637
  Молва — 638–650
  Время суток и расписание — 651–658
  Поле зрения — 659–662
  Обычные жители — 663–666
  Тропы на карте мира — 667–670
  Пост связи — 671–679
  Бункер «Сытыган-14» — 680–693
  Случайные встречи: ориентиры и лор — 694–704
  Выбор героя — 705–714
  Старый язык — саха тыла — 715–722
  Радио — 723–726
  Бой — 727–730
Открытые вопросы — 731–742

## Задания (data/quests.json) — где упоминаются

- **chores** «Утро в Нахарро»: scripts/locations/nakharro.gd, scripts/world/tutor.gd, tools/smoke_test.gd, data/dialogs/ded.json
- **forest** «Дары леса»: scripts/locations/encounter.gd, scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/ded.json
- **fire** «Пожар»: scripts/locations/nakharro.gd, tools/smoke_test.gd
- **barn_junk** «Хлам в амбаре»: scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/varvara.json
- **elder** «До черты»: tools/smoke_test.gd, data/dialogs/elder.json
- **dosimeter** «Щёлкающая коробка»: data/dialogs/smith.json
- **hunter** «Проверка тайгой»: data/dialogs/hunter.json
- **range** «Уроки стрельбы»: data/dialogs/shooter.json, data/weapons.json
- **pack** «Собраться в дорогу (по желанию)»: scripts/locations/nakharro.gd, tools/smoke_test.gd
- **bootur** «Найти Боотура»: scripts/locations/kresty.gd, scripts/locations/nakharro.gd, scripts/locations/sungar_center.gd, scripts/locations/sungar_district.gd, scripts/locations/sungar_hotel.gd, tools/smoke_test.gd, data/dialogs/enc_road_trader.json, data/dialogs/kr_brewer.json, data/dialogs/kr_drunk.json, data/dialogs/kr_head.json, data/dialogs/sg_archylan.json, data/dialogs/sg_barman.json, data/dialogs/sg_clerk.json, data/dialogs/sg_gunsmith.json, data/dialogs/sg_innkeeper.json, data/dialogs/sg_market_boss.json
- **who** «Кто сжёг Нахарро»: scripts/locations/nakharro.gd, scripts/locations/ruin.gd, scripts/locations/ruin_bunker.gd, scripts/main.gd, scripts/ui/world_map.gd, tools/smoke_test.gd, data/dialogs/camp_boss.json, data/dialogs/sg_clerk.json
- **kr_dogs** «Псы у выгона»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/kr_head.json, data/dialogs/kr_herder.json
- **kr_nets** «Порванные сети»: scripts/locations/camp.gd, scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/camp_nyurgun.json, data/dialogs/kr_fisher.json
- **camp_wounded** «Пуля в бедре»: tools/smoke_test.gd, data/dialogs/camp_boss.json, data/dialogs/camp_wounded.json
- **caravan** «Пропавший караван»: scripts/locations/convoy.gd, tools/smoke_test.gd, data/dialogs/kr_trader.json
- **traps** «Капканы Дьаакыпа»: scripts/locations/zaimka.gd, tools/smoke_test.gd, data/dialogs/hermit.json
- **lost_kid** «Мальчишка из Крестов»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/enc_lost_kid.json, data/dialogs/kr_rumors.json
- **debt** «Долг Сэмэна»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/kr_drunk.json, data/dialogs/kr_trader.json
- **camp_cough** «Кашель в лагере»: tools/smoke_test.gd, data/dialogs/camp_wounded.json
- **rematch** «Реванш Дуолана»: scripts/locations/camp.gd, tools/smoke_test.gd, data/dialogs/camp_thug.json
- **hops** «Хмель для Дьулуса»: scripts/locations/kresty.gd, scripts/locations/zaimka.gd, tools/smoke_test.gd, data/dialogs/kr_brewer.json
- **cellar** «Подпол деда»: scripts/locations/nakharro.gd, scripts/locations/nakharro_cellar.gd, tools/smoke_test.gd, data/dialogs/ded.json
- **well** «Ведро в колодце»: scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/water.json
- **lunch** «Обед часовому»: tools/smoke_test.gd, data/dialogs/guard.json, data/dialogs/varvara.json
- **comb** «Гребень Нюргуяны»: scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/gambler.json, data/dialogs/girl.json
- **barrel** «Пропавший бочонок»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/camp_trader.json, data/dialogs/kr_brewer.json, data/dialogs/kr_kid.json
- **salama** «Сэлэ для лиственницы»: scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/ebee.json
- **son_gun** «Ружьё под лиственницей»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/kr_old.json
- **arangas** «Араҥас»: scripts/locations/zaimka.gd, tools/smoke_test.gd, data/dialogs/hermit.json
- **sg_toll** «Плата за вход»: scripts/locations/sungar.gd, tools/smoke_test.gd, data/dialogs/sg_guard.json
- **sg_scales** «Кривые весы»: scripts/locations/sungar.gd, tools/smoke_test.gd, data/dialogs/sg_butcher.json, data/dialogs/sg_market_boss.json
- **sg_caravan** «Караван купчихи»: tools/smoke_test.gd, data/dialogs/sg_merchant.json, data/dialogs/sg_rival.json
- **sg_fight** «Кулачный бой за «Шалманом»»: scripts/locations/sungar_quarter.gd, tools/smoke_test.gd, data/dialogs/sg_barman.json, data/dialogs/sg_brawler.json
- **sg_spring** «Пружина для оружейника»: scripts/locations/sungar_quarter.gd, tools/smoke_test.gd, data/dialogs/sg_gunsmith.json
- **sg_runaway** «Беглый подёнщик»: scripts/locations/sungar_quarter.gd, tools/smoke_test.gd, data/dialogs/sg_collector.json, data/dialogs/sg_fishwife.json, data/dialogs/sg_runaway.json
- **sg_guide** «Комната проводника»: scripts/locations/sungar_quarter.gd, tools/smoke_test.gd, data/dialogs/sg_granny.json
- **sg_suitcase** «Чемодан торговца»: scripts/locations/sungar_hotel.gd, scripts/locations/sungar_obshaga.gd, tools/smoke_test.gd, data/dialogs/sg_guest.json, data/dialogs/sg_innkeeper.json, data/dialogs/sg_radio.json, data/dialogs/sg_thief.json, data/dialogs/sg_watchwoman.json
- **sg_note** «Девятый номер»: scripts/locations/sungar_hotel.gd, tools/smoke_test.gd, data/dialogs/sg_archylan.json, data/dialogs/sg_innkeeper.json
- **sg_medicine** «Жар»: scripts/locations/sungar_dom.gd, tools/smoke_test.gd, data/dialogs/sg_mother.json, data/dialogs/sg_teacher.json
- **sg_lessons** «Саха тыла»: scripts/locations/sungar_dom.gd, tools/smoke_test.gd, data/dialogs/sg_teacher.json
- **sg_arson** «Поджигатель»: scripts/locations/sungar.gd, tools/smoke_test.gd, data/dialogs/sg_chief.json, data/dialogs/sg_stoker.json
- **sg_permit** «Прописка»: tools/smoke_test.gd, data/dialogs/sg_cop.json, data/dialogs/sg_passport.json
- **sg_power** «Двоевластие»: scripts/locations/sungar_admin.gd, scripts/locations/sungar_center.gd, tools/smoke_test.gd, data/dialogs/sg_head.json
- **sg_archive** ««Искра-1030»»: scripts/locations/sungar_admin.gd, tools/smoke_test.gd, data/dialogs/sg_operator.json
- **kr_banya** «Баня по-чёрному»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/kr_banya.json
- **kr_iron** «Железо для кузни»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/kr_smith.json
- **kr_pilot** «Жетон лётчика»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/kr_motryona.json
- **kr_letter** «Письмо в Кресты»: scripts/locations/kresty.gd, tools/smoke_test.gd, data/dialogs/enc_postman.json, data/dialogs/kr_trader.json
- **geo_diary** «Дневник геолога»: scripts/locations/encounter.gd, tools/smoke_test.gd
- **radio** «Эфир»: scripts/locations/nakharro_upper.gd, tools/smoke_test.gd, data/dialogs/radio_kid.json, data/dialogs/smith.json
- **hide_seek** «Прятки»: scripts/locations/nakharro.gd, scripts/locations/nakharro_upper.gd, tools/smoke_test.gd, data/dialogs/hs_kid1.json, data/dialogs/hs_kid2.json, data/dialogs/hs_kid3.json, data/dialogs/kid.json
- **hay** «Ссора из-за сена»: tools/smoke_test.gd, data/dialogs/elder.json, data/dialogs/hay_quarrel.json
- **book** «Четвёртый том»: tools/smoke_test.gd, data/dialogs/elder.json, data/dialogs/teacher.json
- **lessons** «Уроки друга детства»: scripts/locations/nakharro.gd, scripts/world/tutor.gd, tools/smoke_test.gd

## Места карты мира (data/world.json → сцена → скрипт)

- nakharro «Нахарро»: scenes/locations/nakharro.tscn → scripts/locations/nakharro.gd
- kresty «Кресты»: scenes/locations/kresty.tscn → scripts/locations/kresty.gd
- camp «Лагерь оборванцев»: scenes/locations/camp.tscn → scripts/locations/camp.gd
- zaimka «Заимка Дьаакыпа»: scenes/locations/zaimka.tscn → scripts/locations/zaimka.gd
- convoy «Ржавый конвой»: scenes/locations/convoy.tscn → scripts/locations/convoy.gd
- ruin «База на Сытыгане»: scenes/locations/ruin.tscn → scripts/locations/ruin.gd
- tower «Пост связи»: scenes/locations/radio_post.tscn → scripts/locations/radio_post.gd
- sungar «Сунгар»: scenes/locations/sungar.tscn → scripts/locations/sungar.gd
- markun «Мар-Кун»: — 
- nyurba «Нью-Рба»: scenes/locations/nyurba.tscn → scripts/locations/nyurba.gd
- mirny «Мирный»: — 
- mir «Промзона МИР»: — 
- ges «Вилюйская ГЭС»: — 
- vilyuysk «Вилюйск»: — 
- gorny «Горный»: — 
- yakutsk «Якутск»: — 

## Жители: файл диалога → где поставлен (сборщик:строка)

- camp_boss: tools/build_act1.gd:687
- camp_nyurgun: tools/build_act1.gd:688
- camp_rumors: tools/build_act1.gd:692, tools/build_act1.gd:693, tools/build_act1.gd:694
- camp_thug: tools/build_act1.gd:685
- camp_trader: tools/build_act1.gd:690
- camp_wounded: tools/build_act1.gd:691
- ded: tools/build_nakharro.gd:472, tools/build_nakharro.gd:530, tools/build_scenes.gd:717, tools/build_scenes.gd:722
- defender: tools/build_nakharro.gd:536
- ebee: tools/build_nakharro.gd:1050
- elder: tools/build_nakharro.gd:492
- enc_accused: —
- enc_carter: —
- enc_deserter: —
- enc_jaeger: —
- enc_lost_kid: —
- enc_pilgrim: —
- enc_postman: —
- enc_refugee: —
- enc_road_trader: —
- enc_shaman: —
- enc_trapped_hunter: —
- enc_trial: —
- friend: tools/build_nakharro.gd:475, tools/build_nakharro.gd:476
- friend_dying: tools/build_nakharro.gd:540, tools/build_nakharro.gd:541
- gambler: tools/build_nakharro.gd:504
- girl: tools/build_nakharro.gd:503
- guard: tools/build_nakharro.gd:482
- hay_quarrel: tools/build_nakharro.gd:1197, tools/build_nakharro.gd:1198
- hermit: tools/build_act1.gd:796
- hs_kid1: tools/build_nakharro.gd:1194
- hs_kid2: tools/build_nakharro.gd:1195
- hs_kid3: tools/build_act1.gd:1433
- hunter: tools/build_nakharro.gd:506
- kid: tools/build_nakharro.gd:478, tools/build_scenes.gd:720
- kr_banya: tools/build_act1.gd:582
- kr_brewer: tools/build_act1.gd:565
- kr_drunk: tools/build_act1.gd:572
- kr_fisher: tools/build_act1.gd:567
- kr_guard: tools/build_act1.gd:563
- kr_head: tools/build_act1.gd:564
- kr_herder: tools/build_act1.gd:583
- kr_kid: tools/build_act1.gd:578
- kr_motryona: tools/build_act1.gd:573
- kr_old: tools/build_act1.gd:568
- kr_rumors: tools/build_act1.gd:574, tools/build_act1.gd:576, tools/build_act1.gd:585, tools/build_act1.gd:587, tools/build_act1.gd:588, tools/build_act1.gd:589, tools/build_act1.gd:590, tools/build_act1.gd:592
- kr_smith: tools/build_act1.gd:581
- kr_trader: tools/build_act1.gd:566
- radio_kid: tools/build_act1.gd:1407
- road: —
- rumors: tools/build_nakharro.gd:495, tools/build_nakharro.gd:497, tools/build_nakharro.gd:499, tools/build_nakharro.gd:510, tools/build_nakharro.gd:512, tools/build_nakharro.gd:514, tools/build_nakharro.gd:516
- sg_archylan: tools/build_sungar.gd:1286
- sg_barman: tools/build_sungar.gd:927
- sg_brawler: tools/build_sungar.gd:928
- sg_butcher: tools/build_sungar.gd:617
- sg_chief: tools/build_sungar.gd:645
- sg_clerk: tools/build_sungar.gd:789
- sg_collector: tools/build_sungar.gd:931, tools/build_sungar.gd:932
- sg_cop: tools/build_sungar.gd:478
- sg_fishwife: tools/build_sungar.gd:618
- sg_granny: tools/build_sungar.gd:933
- sg_guard: tools/build_sungar.gd:613
- sg_guest: tools/build_sungar.gd:1272
- sg_gunsmith: tools/build_sungar.gd:929
- sg_head: tools/build_sungar.gd:1385
- sg_innkeeper: tools/build_sungar.gd:630
- sg_market_boss: tools/build_sungar.gd:615
- sg_merchant: tools/build_sungar.gd:785
- sg_mother: tools/build_sungar.gd:1316
- sg_operator: tools/build_sungar.gd:1391
- sg_passport: tools/build_sungar.gd:814
- sg_radio: tools/build_sungar.gd:1323
- sg_rival: tools/build_sungar.gd:786
- sg_runaway: tools/build_sungar.gd:930
- sg_stoker: tools/build_sungar.gd:946
- sg_storekeeper: tools/build_sungar.gd:633
- sg_teacher: tools/build_sungar.gd:1309
- sg_thief: tools/build_sungar.gd:1364
- sg_watchwoman: tools/build_sungar.gd:943
- shooter: tools/build_nakharro.gd:507
- sick: tools/build_nakharro.gd:524
- smith: tools/build_nakharro.gd:486
- stepan: tools/build_nakharro.gd:473, tools/build_scenes.gd:718
- teacher: tools/build_act1.gd:1473
- thoughts: —
- varvara: tools/build_nakharro.gd:477, tools/build_scenes.gd:719
- water: —

## Скрипты и сборщики

Формат: файл (строк) — назначение. Ниже — функции `имя:строка` (для файлов от 150 строк).

### scripts/combat/combat_manager.gd (901) · class CombatManager
Пошаговый бой на гексах. Правила и ИИ перенесены из прототипа «Недострой»:
`setup:30` `grid:34` `clog:38` `whose_turn:43` `my_turn:49` `enemies:53` `occ:63` `mode_cost:71` `mode_name:77` `cycle_mode:81` `start:92` `begin_turn:177` `end_turn:218` `after_hero_action:243` `paint:254` `units_center:273` `best_adj:282` `hover:297` `hero_wkey:352` `hero_weapon:356` `click:360` `_world_path:433` `do_attack:440` `zone_picked:455` `exec_attack:465` `reload:509` `use_med:539` `give_up:566` `ai_turn:576` `ai_move:627` `ai_shoot:665` `ai_melee:683` `ai_flee:700` `resolve_attack:727` `ally_hit:802` `react:816` `kill:829` `check_end:846` `finish:861` `game_over:892`

### scripts/combat/fighter.gd (99) · class Fighter
Участник боя: герой или NPC. Хранит всё, что нужно правилам.

### scripts/combat/hex_overlay.gd (105) · class HexOverlay
Подсветка гексов в бою: куда можно дойти, путь, цели, контур поля боя.

### scripts/core/audio.gd (38) · class Audio
Громкость: шины Master («Общая»), SFX («Эффекты» — выстрелы, удары, щелчки)

### scripts/core/clock.gd (411)
Часы игры и смена дня и ночи.
`hours:24` `set_hours:30` `advance:35` `hour_of_day:42` `day:48` `is_night:53` `text:58` `until:64` `_process:72` `_tick_hour:86` `daylight:95` `dusk_tint:107` `apply_light:114` `on_duty:169` `schedule_for:181` `wanted_state:187` `update_schedules:204` `_home_of:251` `_house_at:278` `_near_hero:286` `_bed_spot:291` `_go_sleep:310` `_go_to:335` `_send_home:372` `_hide:385` `_route:396`

### scripts/core/db.gd (89)
Автозагрузка DB: читает все данные игры из папки data/.

### scripts/core/game_state.gd (508)
Автозагрузка Game: состояние героя и мира, журнал, сохранения.
`_ready:20` `new_hero:27` `gtext:51` `hero_max:62` `effective_stats:67` `hero_hp:75` `set_hero_hp:80` `rep:85` `change_rep:90` `stat_pool:106` `skill_pool:110` `stat_cap:114` `grant_xp:118` `log_line:134` `flag:139` `flag_value:143` `set_flag:147` `quest_stage:153` `set_quest:159` `add_note:183` `item_count:191` `add_item:201` `remove_item:222` `hero_wkey:250` `hero_weapon:254` `auto_reload:259` `wstate:275` `check_chance:290` `skill_check:296` `knows_sakha:315` `hero_stat:323` `cas_working:333` `cas_info:337` `is_cassette:341` `cas_active:346` `cas_has_tag:351` `cas_insert:358` `cas_eject:372` `stat_bonus:385` `skill_bonus:394` `worn:409` `effective_skills:418` `save_game:427` `has_save:437` `save_info:441` `load_game:451` `_fix_numbers:477` `_load_settings:493` `save_settings:504`

### scripts/core/graphics.gd (108) · class Graphics
Настройки графики: хранятся в Game.settings (user://settings.json),

### scripts/core/radiation.gd (118)
Радиация (автозагрузка Rad). Накопленная доза — Game.hero.rad (рады).

### scripts/core/rules.gd (415) · class Rules
Правила игры: характеристики, навыки, броски, бой — по дизайн-документу (docs/design.md):
`rep_label:78` `rep_title:86` `trade_mults:96` `all_skills:132` `stat_name:140` `norm_stat:147` `norm_skill:151` `normalize_stats:157` `normalize_skills:172` `weapon_stat:181` `empty_stats:185` `empty_skills:192` `sum_stats:199` `sum_skill_points:206` `r1:214` `roll_dice:218` `sum_arr:229` `roll_hit:237` `max_hp:254` `ap_for:259` `wound_dmg_penalty:264` `calc_ae:272` `level_reward:289` `xp_for_level:293` `earned:300` `random_core:311` `_build_hit_dist:345` `hit_chance:366` `atk_mods:378` `def_mods:401` `zone_by_name:410`

### scripts/core/weather.gd (341)
Погода (автозагрузка Weather): ясно, пасмурно, дождь, ливень, гроза, буря,
`_st:37` `kind:43` `info:47` `title:51` `vis_mult:56` `travel_mult:61` `shelter:66` `set_kind:70` `tick:83` `_announce:128` `outdoor:150` `setup:163` `_player:169` `attach:182` `_make_rain:198` `_make_dust:226` `refresh:259` `apply:292` `_process:318` `rad_step:339`

### scripts/locations/act1_location.gd (133) · class Act1Location
Общее для локаций первого акта: выходы на карту мира, еда для платы и подарков,

### scripts/locations/camp.gd (100)
Лагерь оборванцев у старой лесопилки: беженцы после налётов.

### scripts/locations/convoy.gd (88)
Ржавый конвой: разграбленный караван из Сунгара на старой дороге и засада.

### scripts/locations/encounter.gd (1214)
Случайная встреча в пути. Местность каждый раз собирается заново — по тому месту
`_ready:33` `_p:53` `_put:59` `_free:68` `_scatter_props:76` `_xf:90` `_multi:94` `_build:106` `_landmarks:176` `rad_level:244` `_m:248` `_cm:255` `_bx:265` `_cy:277` `_col:293` `_holder:306` `_asphalt:316` `_plane:357` `_vehicle:377` `_ruin_house:428` `_power_line:460` `_wreck_loot:512` `_seg_d:527` `_ground:534` `_ponds:589` `_edge:632` `_ring_point:652` `_spawn_people:662` `_char:711` `foes:723` `on_enter:732` `leave_hide:757` `_khoton:799` `_alas:841` `_bones:861` `_soft:883` `_burns:896` `_compound:918` `_lore:943` `_diary_page:954` `_reveal_from_tower:972` `on_interact:990` `_serge:1046` `item_actions:1059` `describe:1072` `on_dialog_action:1109` `_jaegers_leave:1164` `on_looted:1172` `_first_of:1179` `_walk_off:1186` `on_combat_end:1197` `objective:1204` `status_line:1212`

### scripts/locations/kresty.gd (293)
Кресты — первое живое поселение за чертой.
`_ready:10` `on_world_state_applied:17` `on_enter:21` `_kid_home:28` `_apply_dogs:40` `_dogs_left:56` `on_dialog_action:65` `on_combat_end:78` `on_interact:85` `_woodpile:132` `_steam:147` `on_interact_extra:158` `_tracks:165` `item_actions:186` `describe:205` `dialog_cond:233` `objective:248`

### scripts/locations/nakharro.gd (1894)
Пролог: деревня Нахарро.
`_ready:35` `friend:51` `_apply_friend:56` `_exit_tree:82` `phase:91` `on_new_game:105` `on_world_state_applied:130` `_apply_sacred:136` `on_enter:143` `_on_dialog_closed:158` `translator:177` `on_pocket:187` `_restore_barn:194` `can_leave_edge:211` `edge_tip:215` `_apply_phase:219` `_apply_light:280` `uses_clock_light:301` `schedule_active:306` `_set_on:310` `status_line:326` `food_count:332` `objective:336` `food_portions:382` `has_travel:390` `pack_ready:397` `pack_line:405` `_check_pack:415` `_process:426` `on_hero_moved:467` `can_pick:530` `is_theft:551` `theft_watch_radius:555` `_is_theft:559` `_witness:567` `_steal:587` `on_picked:612` `_dusk:635` `_gone_home:658` `_start_ambush:668` `_behind:707` `_ambush_hit:713` `_ambush_heard:736` `_prowl_arrived:747` `_prowl_tick:768` `_prowl_leave:795` `_prowl_gone:805` `leave_hide:818` `_gate_enemies_left:825` `_friend_gate_scene:837` `_gate_scene:870` `_gate_fight:920` `_nobody_left:932` `_close_village_quests:952` `_kill_npc:961` `_gate_round:973` `_doomed_alive:994` `_barn_tick:1010` `_cleaners_leave:1038` `_cleaner_gone:1052` `on_looted:1065` `_on_hour:1075` `_on_quest:1079` `_friend_say:1117` `has_fire:1136` `bonfire_lit:1141` `_apply_life:1147` `_friend_to_fire:1167` `dialog_cond:1185` `_bonfire:1193` `_tower:1208` `on_interact:1223` `on_dialog_action:1310` `on_combat_round:1404` `_ded_shoot:1419` `on_fighter_down:1438` `on_combat_end:1444` `_ded_falls:1492` `_ded_near:1515` `_fighting_cleaners:1525` `_fighting_squad:1529` `_cleaners_hear:1538` `_alive_cleaner:1549` `_shoot_ded:1556` `_quest_item:1581` `_update_quest_marks:1597` `_mark_label:1619` `_chest:1637` `_open_chest:1675` `item_actions:1683` `describe:1726` `_mend_fence:1759` `_apply_fence:1783` `_set_solid:1805` `_on_hero_changed:1812` `_assemble_kpk:1828` `_absorb_modules:1851` `_update_exit_guard:1872` `_exit_guard_alive:1891`

### scripts/locations/nakharro_cellar.gd (116)
Подпол избы деда — второй уровень Нахарро. Темно: свечу надо зажечь спичками.

### scripts/locations/nakharro_upper.gd (182)
Вторые этажи двухэтажных изб Нахарро. Светёлки лежат в одной сцене рядом
`_ready:14` `room_at:19` `status_line:26` `uses_clock_light:30` `on_world_state_applied:34` `on_enter:39` `_show:44` `_allowed:65` `on_dialog_action:73` `on_interact:83` `_antenna:120` `item_actions:142` `describe:156` `can_leave_edge:180`

### scripts/locations/nyurba.gd (117)
Нью-Рба, Проход — вход в город и низы: ворота с охраной, Алмазный банк, ломбард,

### scripts/locations/nyurba_district.gd (85) · class NyurbaDistrict
Общее для районов Нью-Рбы: переходы между районами по улицам (To* → другая локация).

### scripts/locations/nyurba_sewer.gd (36)
Нью-Рба, коллектор под Проходом: люк во дворе бара «Забой» — вниз; на том конце —

### scripts/locations/radio_post.gd (124)
Пост связи наёмников на сопке — источник сигнала из модуля «Связь».

### scripts/locations/ruin.gd (183)
База на Сытыгане — довоенный объект. Весной здесь сожгли стоянку оборванцев,
`_ready:7` `on_interact:14` `on_world_state_applied:84` `on_enter:89` `_animate_gate:95` `_apply_gate:112` `_descend_later:120` `on_combat_end:126` `item_actions:132` `describe:151` `objective:172` `rad_level:181`

### scripts/locations/ruin_bunker.gd (270)
Бункер «Сытыган-14» под базой на Сытыгане — второй уровень, наполовину обрушен.
`_ready:9` `on_world_state_applied:19` `_animate_gate:32` `_apply_power:45` `on_enter:58` `status_line:65` `_open_door:69` `on_interact:84` `on_combat_end:193` `item_actions:204` `describe:229` `objective:254` `rad_level:263` `can_leave_edge:268`

### scripts/locations/sungar.gd (169)
Сунгар, район у ворот: платный въезд (стражник Уйгулаан), рынок, рыбная пристань.
`_ready:9` `on_world_state_applied:17` `on_hero_moved:24` `on_interact:44` `_bank_path:70` `_stall:88` `item_actions:107` `describe:122` `objective:141` `_ashes:152`

### scripts/locations/sungar_admin.gd (86)
Администрация ПГТ Сунгар, 2–3 этажи. Глава посёлка Аграфена Семёновна воюет

### scripts/locations/sungar_center.gd (95)
Сунгар, центр: торговые ряды (купчиха Дария и её соперник Хоточчу),

### scripts/locations/sungar_district.gd (99) · class SungarDistrict
Общее для трёх районов Сунгара: переходы между районами (To* → другая локация),

### scripts/locations/sungar_dom.gd (53)
Дом на площади (ул. Ленина, 3), 2–4 этажи. Учительница Сахая учит старому языку;

### scripts/locations/sungar_hotel.gd (87)
Гостиница «Вилюй», 2–3 этажи. Номер 6 — герою, если заплатил дежурной (выспаться

### scripts/locations/sungar_house.gd (118) · class SungarHouse
Верхние этажи каменного дома Сунгара. Первый этаж — в самом районе (туда входишь

### scripts/locations/sungar_obshaga.gd (87)
Общежитие № 2, 2–4 этажи. На четвёртом — Сенька-Кепка и его каморка с краденым:

### scripts/locations/sungar_quarter.gd (172)
Сунгар, жилой квартал: бараки, бар «Шалман» (кулачные бои за домом), оружейная,
`_ready:6` `on_world_state_applied:13` `on_enter:22` `_apply_people:28` `_people_later:41` `_show:46` `on_dialog_action:51` `on_combat_end:78` `on_interact:95` `_scrap:110` `_guide_room:130` `item_actions:144` `describe:155` `objective:166`

### scripts/locations/zaimka.gd (140)
Заимка охотника Дьаакыпа. Задание «Капканы»: на севере что-то ломает капканы —

### scripts/main.gd (1555)
Главный узел игры: камера, загрузка локаций, ввод мышью, окна интерфейса.
`_ready:83` `_on_level_up:110` `_build_ui:121` `space:194` `ui_blocked:198` `sfx:203` `think:228` `_on_menu:233` `_load_slot:261` `_on_sheet_closed:276` `_on_slides_done:287` `_unload:297` `load_location:315` `autosave:360` `quicksave:367` `show_game_over:376` `show_end:380` `status_text:386` `objective_text:392` `_on_hud_action:405` `open_kpk:450` `use_item:476` `_swap_hands:551` `_open_pause:563` `_move_speed:571` `_sneak_radius:582` `on_combat_start:591` `is_filler:607` `filler_bark:612` `talk_to:653` `say:678` `_on_dialog_action:688` `open_trade:727` `_on_dialog_closed:733` `start_fight:738` `_unhandled_input:759` `wait_time:821` `begin_cutscene:826` `end_cutscene:834` `_enemies_near:839` `open_wait:847` `wait_hours:857` `_pick:874` `_click:915` `_may_attack:958` `_near_edge:968` `_can_leave:973` `_walk_to_hex:985` `_walk_clear:1028` `_smooth_path:1043` `_go_then:1057` `_do_pending:1089` `interact:1117` `loot:1141` `_body_entries:1159` `open_loot:1180` `pickpocket:1201` `examine:1236` `_open_actions:1252` `_on_action_picked:1298` `_process:1317` `_update_xray:1383` `_set_alpha:1449` `_update_glow:1461` `_check_aggro:1469` `_look_around:1504` `_look_text:1526`

### scripts/ui/char_sheet.gd (376) · class CharSheet
«Дело» — лист персонажа. Новая игра начинается с выбора одного из четырёх готовых
`setup:24` `_build_pick:131` `presets:179` `pick:184` `_show_pick:203` `_show_main:210` `open:222` `close:231` `_randomize:243` `can_s:252` `can_k:264` `ch_stat:276` `ch_skill:285` `_pm:294` `render:315` `_fixed:367` `_unhandled_key_input:372`

### scripts/ui/dialog_box.gd (634) · class DialogBox
Окно разговора. Реплики берутся из data/dialogs/<файл>.json.
`setup:29` `open:91` `open_data:104` `close:113` `show_node:119` `_dumb:173` `_understands:178` `_dumb_line:186` `mumble:197` `_node_text:231` `_sakha_noticed:250` `_pick_text:256` `_build_options:263` `_fit_opts:317` `_choose:327` `_checks:369` `_check_key:375` `_check_done:381` `_with_chance:386` `_apply_effects:399` `_cond_ok:434` `_node_has_options:486` `_subst:501` `rep_tier:508` `addr:523` `_greet_line:531` `_avoids:548` `_avoid_node:558` `_a_trinket:566` `_rep_greet:575` `_finish_typing:600` `_on_text_click:605` `_process:610` `_unhandled_key_input:620`

### scripts/ui/hud.gd (674) · class HUD
Приборная панель внизу экрана (как в прототипе): журнал, герой, оружие, кнопки.
`setup:52` `_build:65` `_make_slot:346` `refresh:370` `_slot_text:434` `refresh_objective:443` `_on_log:449` `_esc:465` `clear_log:469` `_mini_line:476` `think:496` `thought_visible:506` `_place_thought:510` `_draw_marks:528` `show_tip:553` `hide_tip:559` `flash_tip:565` `toast:571` `tutor_card:587` `tutor_text:606` `hurt_flash:610` `float_text:616` `show_zones:634` `hide_zones:648` `_process:653` `mouse_over_ui:669`

### scripts/ui/kpk.gd (442) · class KPK
Карманный компьютер на браслете. Пока браслета нет — просто «Сумка».
`setup:19` `open:76` `close:83` `has_tab:88` `render:94` `_g:128` `_item_btn:134` `_render_inv:158` `_equip:261` `_render_stat:274` `_open_sheet:342` `_render_cas:351` `_render_map:400` `_render_quests:410` `_render_notes:429` `_unhandled_key_input:438`

### scripts/ui/loot_window.gd (150) · class LootWindow
Окно обыска: что лежит в теле, сундуке или чужом кармане. Каждую вещь можно
`setup:18` `open:66` `entries:75` `_render:79` `take:109` `take_all:121` `close:132` `_unhandled_key_input:141`

### scripts/ui/map_view.gd (38) · class MapView
Карта локации на экране КПК: проходимые места, ты, люди, отметки.

### scripts/ui/menu.gd (291) · class GameMenu
Меню на весь экран в стиле ЭЛТ: главное, пауза, смерть, конец пролога.
`setup:16` `open:59` `_slider:132` `_item:156` `_on:180` `_unhandled_key_input:219`

### scripts/ui/model_view.gd (92) · class ModelView
Окошко с 3D-моделью героя: портрет (голова и плечи) или в полный рост, крутится на месте.

### scripts/ui/trade_window.gd (299) · class TradeWindow
Бартер: денег в первом акте нет, меняют вещь на вещь.
`setup:29` `_column:87` `open:113` `mine:127` `stock:146` `give_value:150` `take_value:154` `_sum_of:158` `offer:166` `withdraw:180` `can_exchange:190` `exchange:194` `_line:220` `_render:224` `_fill:243` `close:281` `_unhandled_key_input:290`

### scripts/ui/ui_theme.gd (216) · class UITheme
Кассетный футуризм: бежевый пластик, янтарные и зелёные ЭЛТ-экраны.
`mono:32` `head:38` `_font:46` `build_theme:66` `plastic:106` `screen:119` `paper:129` `panel:137` `label:143` `key:153` `style_key:163` `stripe:201` `full_rect:214`

### scripts/ui/wait_screen.gd (228) · class WaitScreen
Пропуск времени. Сначала — выбор, сколько ждать (час, три, шесть, до вечера,
`setup:21` `options:77` `ask:87` `_close_ask:101` `_choose:107` `_unhandled_key_input:113` `blackout:126` `play:150` `_update_lbl:195` `_draw_dial:201`

### scripts/ui/world_map.gd (986) · class WorldMap
Карта мира как в Fallout: по картинке (data/world.json → image) герой ходит сам,
`setup:62` `_layout:148` `set_zoom:164` `nodes:171` `node_pos:175` `known:180` `reveal:186` `can_go:201` `_fog_dims:219` `_fog_str:223` `explored:232` `explore:239` `_build_fog:260` `paths:272` `on_path:281` `hours:293` `time_text:297` `hours_to:301` `_build_nav:315` `_disc:338` `_cell:348` `seg_free:353` `_snap_free:362` `route:378` `open:405` `close:438` `_can_back:445` `go_node:452` `travel:461` `_go_to:470` `halt:481` `_process:487` `_save_pos:525` `_arrive:529` `_reveal_near:544` `_dir_word:561` `blast_k:570` `_locked_note:579` `enter:585` `_roll_encounter:614` `_roll_encounter_with:629` `biome_at:645` `pick_encounter:678` `_mark_seen:719` `start_road_event:726` `_on_dialog_closed:735` `on_action:744` `start_encounter:761` `select:783` `_refresh_time:790` `_refresh:794` `_to_px:818` `_from_px:822` `_text:826` `_smooth:833` `_draw_map:849` `_node_at:910` `_on_canvas_input:923` `_unhandled_key_input:965`

### scripts/world/anim_body.gd (162) · class AnimBody
Манекен из Universal Animation Library (Quaternius, CC0) с готовыми анимациями.
`build:23` `_skin:60` `_tint:79` `hand:94` `hand_l:98` `grip:106` `has:118` `length:122` `play:128` `_find:145` `_meshes:155`

### scripts/world/arm_length.gd (23) · class ArmLength
Укорачивает (или удлиняет) руки скелета UAL для модели с другими пропорциями:

### scripts/world/character.gd (1286) · class Character
Персонаж на локации: герой, жители, враги, звери.
`_ready:108` `uid:145` `_rebuild_preview:149` `_build_visual:181` `move_along:221` `stop:239` `bark:251` `barking:272` `_hero_tpl:279` `rebuild_hero_body:292` `apply_hero_skin:310` `fov:332` `in_view:342` `show_cone:358` `face_towards:394` `_process:400` `_patrol:444` `act:459` `set_held:467` `_chest_attach:511` `_low_ready:532` `_two_handed:539` `_setup_two_hands:543` `_update_two_hands:585` `_make_weapon_mesh:637` `muzzle_flash:676` `_animate:688` `_animate_clips:825` `_act_clip:870` `_clip_act:887` `_fire_cb_once:933` `_end_act:942` `show_bracelet:956` `_plain:990` `_plug_tick:1000` `_sound:1027` `_plug_build:1033` `_plug_update:1082` `_seg:1104` `_plug_clear:1113` `_collect_meshes:1129` `_mark_kind:1136` `_update_marks:1158` `_set_ghost:1201` `_stencil_write:1226` `_stencil_mat:1246` `_sil_mat:1261` `_ring_mat:1272` `_sound_bolt:1284`

### scripts/world/fire_fx.gd (98) · class FireFX
Огонь: мерцающий свет, языки пламени и столб дыма.

### scripts/world/hero_body.gd (74) · class HeroBody
Модель героя (assets/models/hero.glb) со скелетом.

### scripts/world/hex_grid.gd (195) · class HexGrid
Гексагональная сетка поверх локации (как в прототипе: гекс 0.72 м, «острый верх»).
`to_world:20` `from_world:24` `is_free:43` `distance:47` `neighbors:51` `build:61` `_edge:105` `_wall_between:110` `explore_path:120` `bfs:140` `path_to:160` `nearest_free:169` `line_clear:192`

### scripts/world/house.gd (55) · class House
Дом, в который можно войти. Постройку собирает tools/build_props.gd:

### scripts/world/human_body.gd (108) · class HumanBody
Процедурный человечек из брусков (как makeHuman в прототипе).

### scripts/world/interactable.gd (113) · class Interactable
Предмет или место, по которому можно кликнуть: подобрать, обыскать, выйти.

### scripts/world/location.gd (229) · class Location
Корневой скрипт любой локации.
`setup:22` `spawn_point:31` `characters:38` `character:48` `items:52` `item:62` `ws:66` `_apply_world_state:70` `scatter_table:94` `scatter_count:98` `_scatter_loot:109` `on_world_state_applied:159` `on_enter:163` `on_hero_moved:167` `on_dialog_action:172` `on_interact:177` `is_theft:182` `theft_watch_radius:187` `can_leave_edge:192` `edge_tip:197` `can_pick:202` `on_picked:206` `on_looted:210` `on_combat_round:214` `on_fighter_down:218` `on_combat_end:222` `dialog_cond:227`

### scripts/world/scatter.gd (38) · class Scatter
Россыпь одинаковых мелочей (трава, камыш, кочки, лужи) — одна отрисовка на всех.

### scripts/world/social.gd (460) · class Social
Жизнь вокруг героя: жители сами бросают реплики, с ними можно поболтать
`setup:24` `_st:29` `key:35` `affinity:39` `tier_text:44` `talks:54` `can_fight:64` `_pick:72` `_barks:76` `_peaceful:85` `_process:91` `_idle_step:125` `ambient_line:165` `temper:193` `archetype:202` `can_parley:223` `_squad:234` `parley:244` `_calm:271` `gifts_on_hand:286` `can_chat:294` `chatted_today:298` `chat:302` `_tier_note:332` `gift:341` `_add_aff:350` `provoke:373` `flee:398` `apply_hostile:412` `on_action:427`

### scripts/world/target_body.gd (41) · class TargetBody
Мишень для стрельбы: столб и соломенный щит с кругами.

### scripts/world/tutor.gd (299) · class Tutor
Утро в Нахарро: друг детства водит героя и учит — ходить, говорить, брать вещи,
`setup:38` `active:43` `step:48` `friend:52` `start:56` `skip:62` `_process:70` `_done:126` `_pick_target:163` `_dat:178` `_stalked:193` `_follow:212` `_lead:238` `_card:257` `comment:277` `_finish:290`

### tools/audit_interact.gd (84)
Проверка: у каждого места в каждой локации каждое действие из меню даёт отклик

### tools/build_act1.gd (1979)
Генератор локаций первого акта: Кресты (живое поселение у реки) и
`_build:17` `_begin:40` `_finish:59` `_water_mats:71` `_river_plane:83` `_slot_of:99` `_homely:105` `_ground_for:124` `_paint:160` `_woods:190` `_blocked:228` `_free2:239` `_boxes_of:248` `_dress:272` `_cross:307` `_mound:324` `_net_rack:331` `_tent:351` `_lean_to:366` `_boat:381` `_exit:390` `_use:401` `_spawn:412` `_kresty:427` `_camp:637` `_encounter:713` `_spawn_mark:722` `_zaimka:734` `_truck:824` `_convoy:846` `_block:884` `_ruin:901` `_bunker_portal:991` `_radio_post:1053` `_dark_env:1186` `_lamp:1204` `_room_walls:1219` `_floor:1258` `_cellar:1263` `_glow:1321` `_upper:1330` `_bunker:1479` `_bunker_mats:1565` `_bk_panels:1592` `_hazard:1624` `_collapse:1636` `_bk_shaft:1651` `_bk_gate:1666` `_bk_corridor:1708` `_console:1741` `_reel_unit:1764` `_bk_control:1776` `_bk_barracks:1825` `_bk_generator:1856` `_bk_archive:1877` `_river_south:1904` `_stall:1914` `_signboard:1934` `_lamp_post:1954` `_laundry:1968`

### tools/build_city.gd (1603)
Каменный Сунгар (бывший посёлок городского типа): дома в 2–4 этажа из штукатурки
`_ready:18` `_city_materials:109` `_glow_mat:176` `swin:191` `balcony:232` `entry:267` `open_door:282` `roof:292` `stone_block:327` `sandrik:455` `arch_win:468` `_stalin_decor:500` `_labaz_decor:543` `_balustrade:572` `_spire:589` `nyurba_props:607` `_wkind:731` `_wear:750` `_shop_window:808` `_portico:820` `_shell:836` `_lining:860` `stair_flight:875` `partition_z:889` `_table:901` `_bed:918` `_wardrobe:929` `_counter:935` `_shelf_goods:941` `_stove:955` `_rug:961` `_plant:965` `_interior:973` `heat_pipes:1199` `boiler_house:1237` `water_tower:1263` `garages:1276` `kiosk:1291` `bus_stop:1307` `conc_fence:1327` `paz_wreck:1338` `bins:1355` `furniture:1367` `_stair_piece:1431` `_crt:1444` `cassette_props:1453` `ruin_props:1539`

### tools/build_hero_skin.gd (78)
Собирает сетку героя с новой развёрткой из assets/models/hero_skin_mesh.bin

### tools/build_nakharro.gd (1209)
Генератор большой деревни Нахарро (по референсу «Нахарра», ~40 человек):
`_ready:43` `_build:63` `_env:93` `_ground:134` `strip:186` `_ground_material:195` `_paint_splat:212` `_sd_rect:246` `_seg_dist:254` `_ring_dist:261` `_ditch_h:268` `_village:282` `_forest:368` `_forest_edge:421` `_raid:449` `_characters:467` `_seat:579` `_items:586` `_fence_mend:663` `_clear_overlaps:680` `_is_plant:748` `_inside:755` `_pal:764` `_moat:772` `_ditch_mesh:827` `_bridge:853` `_multi:870` `_xf:884` `_free_spot:888` `_details:897` `_building_boxes:987` `_tutorial_extras:1015` `_sacred_tree:1055` `_village_life:1129`

### tools/build_nyurba.gd (469)
Нью-Рба — большой алмазный город на месте Нюрбы (Акт II). Город квадратный,
`_build:16` `_finish:39` `_wall:49` `_junk:71` `_junk_items:76` `_city_wall:86` `_city_gate:102` `_walk:127` `_proxod:135` `_sewer:369`

### tools/build_props.gd (1551)
Генератор построек и растительности в стиле референса «Нахарра».
`_ready:31` `_houses:67` `_tex_mat:81` `_card_mat:100` `_decal_mat:117` `_plain_mat:133` `_materials:145` `begin:214` `add:230` `rough:239` `rsphere:263` `rcone:272` `save_mesh:283` `box:299` `cyl:305` `prism:315` `solid:321` `finish:325` `_merge:397` `log_walls:425` `gable_roof:447` `window:491` `_window:497` `door:520` `wall_colliders:537` `plinth:551` `izba_interior:561` `porch:606` `chimney:621` `house:628` `hall:733` `tower:795` `barn:837` `shed:897` `workshop:912` `gate:937` `barricade:954` `greenhouse:970` `wind_turbine:995` `card:1021` `leaf:1039` `spruce:1046` `pine:1085` `birch:1119` `bush:1142` `dead_tree:1156` `rocks:1170` `tractor:1191` `palisades:1248` `small_props:1291` `scatter_meshes:1422` `travel_items:1469` `_item:1521` `junk:1529` `locked_box:1542`

### tools/build_rural.gd (903)
Деревня и дорога: постройки и вещи для Крестов (баня, часовня, коптильня, нужник,
`_ready:10` `village_props:43` `personal_items:165` `wreck_props:237` `_an2:353` `_cwing:452` `_rivets:471` `_mi8:479` `_scorch:575` `_grime:583` `_bb:593` `_rbox_mesh:608` `_rotor:633` `_vtol:647` `_drone:731` `_duct:782` `_ring_mesh:802` `_jet:816` `_tw:891` `beam:897`

### tools/build_scenes.gd (775)
Генератор стартовых сцен: материалы, пропсы (избы, амбар, деревья…),
`_ready:17` `_mat:30` `_materials:44` `_own:74` `box:80` `cyl:94` `sphere:110` `prism:125` `collider:137` `save_prop:153` `_props:167` `_izba:193` `_barn:214` `_shed:231` `_fence:244` `_well:261` `_woodpile:274` `_birch:285` `_larch:295` `_dead_tree:305` `_bush:315` `_border_post:323` `_sign:332` `_tractor:361` `_table:375` `_garden:387` `_fire:397` `_item_base:404` `_mushroom:411` `_berries:421` `_planks_item:432` `_basket:441` `_bandage:451` `_rock:458` `_main_scene:467` `fit_label:484` `_label_fits:504` `put:513` `group:526` `character:534` `item:552` `marker:559` `strip:569` `_nakharro:575`

### tools/build_sungar.gd (1397)
Сунгар — бывший посёлок городского типа: три района (ворота и рынок, центр,
`_build:20` `_street_out:56` `_edges:61` `_junk_fence:146` `_place_sentries:209` `_ep:217` `_bld:230` `_slot:235` `_face:244` `_pipes:249` `_pavement:258` `_stele:264` `_honor_board:290` `_sign_on:319` `_clear_town:330` `_clutter:347` `_broken_road:358` `_power_line:399` `_neon:430` `_graffiti:446` `_info_screen:460` `_cop:477` `_stairs_item:486` `_sungar:495` `_sungar_center:687` `_sungar_quarter:850` `_house_begin:980` `_house_finish:1008` `_finish:1013` `_lw:1023` `_lw_gaps:1043` `_bulb:1069` `_door_no:1080` `_corridor_floor:1096` `_furnish:1172` `_rp:1247` `_to_door:1254` `_hotel_floors:1261` `_dom_floors:1296` `_obshaga_floors:1336` `_admin_floors:1373`

### tools/build_weapons.gd (260)
Собирает модели оружия из загруженных файлов в assets/models/weapons/<ключ>/
`_init:48` `_cfg:56` `_source_meshes:70` `_material:90` `_build_proc:125` `_build:178` `_painted:244`

### tools/check_overlap.gd (75)
Проверка расстановки: какие постройки и крупные пропсы залезают друг в друга.

### tools/check_scripts.gd (115)
Проверка: загружает все скрипты проекта и сообщает об ошибках.

### tools/decimate_mesh.gd (62)
Упрощает тяжёлую модель: берёт первую сетку из .glb/.fbx, строит уровни детализации

### tools/preview_prop.gd (26)
Превью одного пропа: тот же свет, что в деревне, изометрическая камера.

### tools/render_shots.gd (167)
Скриншоты для проверки (нужен рендер, не --headless):
`_ready:11`

### tools/screenshots.gd (107)
Снимки экрана для проверки интерфейса (нужен рендер, не --headless).

### tools/smoke_test.gd (3011)
Автотест пролога: проходит всю цепочку без участия человека и печатает, что сломалось.
`new_enc:12` `ok:17` `wait:25` `frames:29` `close_dialogs:34` `shut:43` `choose:48` `opt_texts:54` `find_opt:61` `tp:79` `fight:86` `wait_loading:128` `unreachable:137` `go_upstairs:166` `go_downstairs:176` `nakharro_life_tests:187` `kresty_life_tests:365` `encounter_lore_tests:444` `city_tests:512` `admin_tests:705` `weather_tests:783` `social_tests:850` `nyurba_tests:947` `sungar_tests:1003` `_ready:1150`

## Данные (data/)

- data/barks.json (686 строк)
- data/characters.json (138 строк)
- data/dialogs/camp_boss.json (385 строк)
- data/dialogs/camp_nyurgun.json (194 строк)
- data/dialogs/camp_rumors.json (127 строк)
- data/dialogs/camp_thug.json (210 строк)
- data/dialogs/camp_trader.json (198 строк)
- data/dialogs/camp_wounded.json (230 строк)
- data/dialogs/ded.json (421 строк)
- data/dialogs/defender.json (24 строк)
- data/dialogs/ebee.json (228 строк)
- data/dialogs/elder.json (256 строк)
- data/dialogs/enc_accused.json (23 строк)
- data/dialogs/enc_carter.json (131 строк)
- data/dialogs/enc_deserter.json (179 строк)
- data/dialogs/enc_jaeger.json (119 строк)
- data/dialogs/enc_lost_kid.json (104 строк)
- data/dialogs/enc_pilgrim.json (68 строк)
- data/dialogs/enc_postman.json (101 строк)
- data/dialogs/enc_refugee.json (88 строк)
- data/dialogs/enc_road_trader.json (153 строк)
- data/dialogs/enc_shaman.json (170 строк)
- data/dialogs/enc_trapped_hunter.json (118 строк)
- data/dialogs/enc_trial.json (118 строк)
- data/dialogs/friend.json (263 строк)
- data/dialogs/friend_dying.json (48 строк)
- data/dialogs/gambler.json (176 строк)
- data/dialogs/girl.json (213 строк)
- data/dialogs/guard.json (120 строк)
- data/dialogs/hay_quarrel.json (151 строк)
- data/dialogs/hermit.json (474 строк)
- data/dialogs/hs_kid1.json (28 строк)
- data/dialogs/hs_kid2.json (28 строк)
- data/dialogs/hs_kid3.json (28 строк)
- data/dialogs/hunter.json (180 строк)
- data/dialogs/kid.json (257 строк)
- data/dialogs/kr_banya.json (100 строк)
- data/dialogs/kr_brewer.json (605 строк)
- data/dialogs/kr_drunk.json (389 строк)
- data/dialogs/kr_fisher.json (259 строк)
- data/dialogs/kr_guard.json (186 строк)
- data/dialogs/kr_head.json (446 строк)
- data/dialogs/kr_herder.json (101 строк)
- data/dialogs/kr_kid.json (96 строк)
- data/dialogs/kr_motryona.json (105 строк)
- data/dialogs/kr_old.json (272 строк)
- data/dialogs/kr_rumors.json (158 строк)
- data/dialogs/kr_smith.json (135 строк)
- data/dialogs/kr_trader.json (385 строк)
- data/dialogs/radio_kid.json (107 строк)
- data/dialogs/road.json (1268 строк)
- data/dialogs/rumors.json (72 строк)
- data/dialogs/sg_archylan.json (89 строк)
- data/dialogs/sg_barman.json (164 строк)
- data/dialogs/sg_brawler.json (47 строк)
- data/dialogs/sg_butcher.json (117 строк)
- data/dialogs/sg_chief.json (256 строк)
- data/dialogs/sg_clerk.json (219 строк)
- data/dialogs/sg_collector.json (77 строк)
- data/dialogs/sg_cop.json (262 строк)
- data/dialogs/sg_fishwife.json (59 строк)
- data/dialogs/sg_granny.json (65 строк)
- data/dialogs/sg_guard.json (347 строк)
- data/dialogs/sg_guest.json (143 строк)
- data/dialogs/sg_gunsmith.json (123 строк)
- data/dialogs/sg_head.json (154 строк)
- data/dialogs/sg_innkeeper.json (186 строк)
- data/dialogs/sg_market_boss.json (198 строк)
- data/dialogs/sg_merchant.json (123 строк)
- data/dialogs/sg_mother.json (150 строк)
- data/dialogs/sg_operator.json (82 строк)
- data/dialogs/sg_passport.json (150 строк)
- data/dialogs/sg_radio.json (122 строк)
- data/dialogs/sg_rival.json (64 строк)
- data/dialogs/sg_runaway.json (118 строк)
- data/dialogs/sg_stoker.json (173 строк)
- data/dialogs/sg_storekeeper.json (64 строк)
- data/dialogs/sg_teacher.json (113 строк)
- data/dialogs/sg_thief.json (146 строк)
- data/dialogs/sg_watchwoman.json (46 строк)
- data/dialogs/shooter.json (179 строк)
- data/dialogs/sick.json (138 строк)
- data/dialogs/smith.json (320 строк)
- data/dialogs/stepan.json (133 строк)
- data/dialogs/teacher.json (125 строк)
- data/dialogs/thoughts.json (443 строк)
- data/dialogs/varvara.json (251 строк)
- data/dialogs/water.json (114 строк)
- data/elley.json (15 строк)
- data/intro.json (18 строк)
- data/items.json (100 строк)
- data/lore.json (115 строк)
- data/observations.json (81 строк)
- data/presets.json (22 строк)
- data/quests.json (581 строк)
- data/rep_greet.json (34 строк)
- data/schedules.json (535 строк)
- data/weapons.json (20 строк)
- data/world.json (2967 строк)
