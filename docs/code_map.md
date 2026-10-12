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

- **chores** «Утро в Нахарро»: scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/ded.json
- **forest** «Дары леса»: scripts/locations/encounter.gd, scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/ded.json
- **fire** «Пожар»: scripts/locations/nakharro.gd, tools/smoke_test.gd
- **barn_junk** «Хлам в амбаре»: scripts/locations/nakharro.gd, tools/smoke_test.gd, data/dialogs/varvara.json
- **elder** «До черты»: tools/smoke_test.gd, data/dialogs/elder.json
- **dosimeter** «Щёлкающая коробка»: data/dialogs/smith.json
- **hunter** «Проверка тайгой»: data/dialogs/hunter.json
- **range** «Уроки стрельбы»: data/dialogs/shooter.json, data/weapons.json
- **pack** «Собраться в дорогу»: scripts/locations/nakharro.gd, tools/smoke_test.gd
- **bootur** «Найти Боотура»: scripts/locations/kresty.gd, scripts/locations/nakharro.gd, scripts/locations/sungar_center.gd, scripts/locations/sungar_district.gd, tools/smoke_test.gd, data/dialogs/enc_road_trader.json, data/dialogs/kr_brewer.json, data/dialogs/kr_drunk.json, data/dialogs/kr_head.json, data/dialogs/sg_archylan.json, data/dialogs/sg_barman.json, data/dialogs/sg_clerk.json, data/dialogs/sg_gunsmith.json, data/dialogs/sg_hostess.json, data/dialogs/sg_innkeeper.json, data/dialogs/sg_market_boss.json
- **who** «Кто сжёг Нахарро»: scripts/locations/nakharro.gd, scripts/locations/ruin.gd, scripts/locations/ruin_bunker.gd, scripts/main.gd, scripts/ui/world_map.gd, tools/smoke_test.gd, data/dialogs/camp_boss.json
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
- **cellar** «Подпол деда»: scripts/locations/nakharro_cellar.gd, tools/smoke_test.gd, data/dialogs/ded.json
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
- **sg_power** «Двоевластие»: scripts/locations/sungar_admin.gd, tools/smoke_test.gd, data/dialogs/sg_head.json
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
- nyurba «Нью-Рба»: — 
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
- ded: tools/build_nakharro.gd:472, tools/build_nakharro.gd:527, tools/build_scenes.gd:717, tools/build_scenes.gd:722
- defender: tools/build_nakharro.gd:533
- ebee: tools/build_nakharro.gd:1038
- elder: tools/build_nakharro.gd:489
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
- gambler: tools/build_nakharro.gd:501
- girl: tools/build_nakharro.gd:500
- guard: tools/build_nakharro.gd:479
- hay_quarrel: tools/build_nakharro.gd:1185, tools/build_nakharro.gd:1186
- hermit: tools/build_act1.gd:796
- hs_kid1: tools/build_nakharro.gd:1182
- hs_kid2: tools/build_nakharro.gd:1183
- hs_kid3: tools/build_act1.gd:1433
- hunter: tools/build_nakharro.gd:503
- kid: tools/build_nakharro.gd:475, tools/build_scenes.gd:720
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
- rumors: tools/build_nakharro.gd:492, tools/build_nakharro.gd:494, tools/build_nakharro.gd:496, tools/build_nakharro.gd:507, tools/build_nakharro.gd:509, tools/build_nakharro.gd:511, tools/build_nakharro.gd:513
- sg_archylan: tools/build_sungar.gd:1316
- sg_barman: tools/build_sungar.gd:957
- sg_brawler: tools/build_sungar.gd:958
- sg_butcher: tools/build_sungar.gd:608
- sg_chief: tools/build_sungar.gd:636
- sg_clerk: tools/build_sungar.gd:819
- sg_collector: tools/build_sungar.gd:961, tools/build_sungar.gd:962
- sg_cop: tools/build_sungar.gd:471
- sg_dealer: tools/build_sungar.gd:818
- sg_fishwife: tools/build_sungar.gd:609
- sg_granny: tools/build_sungar.gd:963
- sg_guard: tools/build_sungar.gd:604
- sg_guest: tools/build_sungar.gd:1302
- sg_gunsmith: tools/build_sungar.gd:959
- sg_head: tools/build_sungar.gd:1415
- sg_hostess: tools/build_sungar.gd:817
- sg_innkeeper: tools/build_sungar.gd:621
- sg_market_boss: tools/build_sungar.gd:606
- sg_merchant: tools/build_sungar.gd:813
- sg_mother: tools/build_sungar.gd:1346
- sg_operator: tools/build_sungar.gd:1421
- sg_passport: tools/build_sungar.gd:844
- sg_radio: tools/build_sungar.gd:1353
- sg_rival: tools/build_sungar.gd:814
- sg_runaway: tools/build_sungar.gd:960
- sg_stoker: tools/build_sungar.gd:976
- sg_storekeeper: tools/build_sungar.gd:624
- sg_teacher: tools/build_sungar.gd:1339
- sg_thief: tools/build_sungar.gd:1394
- sg_watchwoman: tools/build_sungar.gd:973
- shooter: tools/build_nakharro.gd:504
- sick: tools/build_nakharro.gd:521
- smith: tools/build_nakharro.gd:483
- stepan: tools/build_nakharro.gd:473, tools/build_scenes.gd:718
- teacher: tools/build_act1.gd:1473
- thoughts: —
- varvara: tools/build_nakharro.gd:474, tools/build_scenes.gd:719
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

### scripts/core/game_state.gd (495)
Автозагрузка Game: состояние героя и мира, журнал, сохранения.
`_ready:20` `new_hero:27` `hero_max:49` `effective_stats:54` `hero_hp:62` `set_hero_hp:67` `rep:72` `change_rep:77` `stat_pool:93` `skill_pool:97` `stat_cap:101` `grant_xp:105` `log_line:121` `flag:126` `flag_value:130` `set_flag:134` `quest_stage:140` `set_quest:146` `add_note:170` `item_count:178` `add_item:188` `remove_item:209` `hero_wkey:237` `hero_weapon:241` `auto_reload:246` `wstate:262` `check_chance:277` `skill_check:283` `knows_sakha:302` `hero_stat:310` `cas_working:320` `cas_info:324` `is_cassette:328` `cas_active:333` `cas_has_tag:338` `cas_insert:345` `cas_eject:359` `stat_bonus:372` `skill_bonus:381` `worn:396` `effective_skills:405` `save_game:414` `has_save:424` `save_info:428` `load_game:438` `_fix_numbers:464` `_load_settings:480` `save_settings:491`

### scripts/core/graphics.gd (108) · class Graphics
Настройки графики: хранятся в Game.settings (user://settings.json),

### scripts/core/radiation.gd (118)
Радиация (автозагрузка Rad). Накопленная доза — Game.hero.rad (рады).

### scripts/core/rules.gd (405) · class Rules
Правила игры: характеристики, навыки, броски, бой — по дизайн-документу (docs/design.md):
`rep_label:68` `rep_title:76` `trade_mults:86` `all_skills:122` `stat_name:130` `norm_stat:137` `norm_skill:141` `normalize_stats:147` `normalize_skills:162` `weapon_stat:171` `empty_stats:175` `empty_skills:182` `sum_stats:189` `sum_skill_points:196` `r1:204` `roll_dice:208` `sum_arr:219` `roll_hit:227` `max_hp:244` `ap_for:249` `wound_dmg_penalty:254` `calc_ae:262` `level_reward:279` `xp_for_level:283` `earned:290` `random_core:301` `_build_hit_dist:335` `hit_chance:356` `atk_mods:368` `def_mods:391` `zone_by_name:400`

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

### scripts/locations/nakharro.gd (1584)
Пролог: деревня Нахарро.
`_ready:35` `_exit_tree:43` `phase:52` `on_new_game:66` `on_world_state_applied:91` `_apply_sacred:97` `on_enter:104` `_restore_barn:118` `can_leave_edge:135` `edge_tip:139` `_apply_phase:143` `_apply_light:203` `uses_clock_light:224` `schedule_active:229` `_set_on:233` `status_line:249` `food_count:255` `objective:259` `food_portions:288` `has_travel:296` `pack_ready:303` `pack_line:311` `_check_pack:321` `_process:332` `on_hero_moved:373` `can_pick:425` `_is_theft:446` `_witness:453` `_steal:468` `on_picked:487` `_dusk:508` `_gone_home:531` `_start_ambush:541` `_behind:579` `_ambush_hit:585` `_ambush_heard:608` `_prowl_arrived:619` `_prowl_tick:640` `_prowl_leave:667` `_prowl_gone:677` `leave_hide:690` `_gate_enemies_left:697` `_gate_scene:705` `_gate_fight:755` `_nobody_left:767` `_kill_npc:777` `_gate_round:789` `_doomed_alive:810` `_barn_tick:826` `_cleaners_leave:854` `_cleaner_gone:868` `on_looted:881` `_on_hour:891` `_on_quest:895` `bonfire_lit:901` `_apply_life:907` `_bonfire:925` `_tower:940` `on_interact:955` `on_dialog_action:1042` `on_combat_round:1111` `_ded_shoot:1126` `on_fighter_down:1145` `on_combat_end:1151` `_ded_falls:1184` `_ded_near:1207` `_fighting_cleaners:1217` `_fighting_squad:1221` `_cleaners_hear:1230` `_alive_cleaner:1241` `_shoot_ded:1248` `_quest_item:1273` `_update_quest_marks:1289` `_mark_label:1311` `_chest:1329` `_open_chest:1367` `item_actions:1375` `describe:1418` `_mend_fence:1451` `_apply_fence:1475` `_set_solid:1497` `_on_hero_changed:1504` `_assemble_kpk:1519` `_absorb_modules:1542` `_update_exit_guard:1563` `_exit_guard_alive:1581`

### scripts/locations/nakharro_cellar.gd (115)
Подпол избы деда — второй уровень Нахарро. Темно: свечу надо зажечь спичками.

### scripts/locations/nakharro_upper.gd (182)
Вторые этажи двухэтажных изб Нахарро. Светёлки лежат в одной сцене рядом
`_ready:14` `room_at:19` `status_line:26` `uses_clock_light:30` `on_world_state_applied:34` `on_enter:39` `_show:44` `_allowed:65` `on_dialog_action:73` `on_interact:83` `_antenna:120` `item_actions:142` `describe:156` `can_leave_edge:180`

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

### scripts/locations/sungar_center.gd (112)
Сунгар, центр: торговые ряды (купчиха Дария и её соперник Хоточчу),

### scripts/locations/sungar_district.gd (99) · class SungarDistrict
Общее для трёх районов Сунгара: переходы между районами (To* → другая локация),

### scripts/locations/sungar_dom.gd (53)
Дом на площади (ул. Ленина, 3), 2–4 этажи. Учительница Сахая учит старому языку;

### scripts/locations/sungar_hotel.gd (83)
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

### scripts/main.gd (1518)
Главный узел игры: камера, загрузка локаций, ввод мышью, окна интерфейса.
`_ready:81` `_on_level_up:102` `_build_ui:113` `space:186` `ui_blocked:190` `sfx:195` `think:220` `_on_menu:225` `_load_slot:253` `_on_sheet_closed:268` `_on_slides_done:277` `_unload:287` `load_location:305` `autosave:350` `quicksave:357` `show_game_over:366` `show_end:370` `status_text:376` `objective_text:382` `_on_hud_action:395` `open_kpk:440` `use_item:466` `_swap_hands:541` `_open_pause:553` `_move_speed:561` `_sneak_radius:572` `on_combat_start:581` `is_filler:597` `filler_bark:602` `talk_to:643` `say:668` `_on_dialog_action:678` `open_trade:717` `_on_dialog_closed:723` `start_fight:728` `_unhandled_input:749` `wait_time:811` `begin_cutscene:816` `end_cutscene:824` `_enemies_near:829` `open_wait:837` `wait_hours:847` `_pick:864` `_click:905` `_may_attack:948` `_near_edge:958` `_can_leave:963` `_walk_to_hex:975` `_walk_clear:1018` `_smooth_path:1033` `_go_then:1047` `_do_pending:1079` `interact:1107` `loot:1131` `_body_entries:1149` `open_loot:1170` `pickpocket:1191` `examine:1222` `_open_actions:1238` `_on_action_picked:1284` `_process:1303` `_update_xray:1365` `_set_alpha:1430` `_check_aggro:1437` `_look_around:1467` `_look_text:1489`

### scripts/ui/char_sheet.gd (368) · class CharSheet
«Дело» — лист персонажа. Новая игра начинается с выбора одного из четырёх готовых
`setup:24` `_build_pick:131` `presets:176` `pick:181` `_show_pick:198` `_show_main:205` `open:214` `close:223` `_randomize:235` `can_s:244` `can_k:256` `ch_stat:268` `ch_skill:277` `_pm:286` `render:307` `_fixed:359` `_unhandled_key_input:364`

### scripts/ui/dialog_box.gd (494) · class DialogBox
Окно разговора. Реплики берутся из data/dialogs/<файл>.json.
`setup:25` `open:80` `open_data:92` `close:100` `show_node:106` `_node_text:144` `_sakha_noticed:154` `_pick_text:160` `_build_options:167` `_choose:214` `_checks:252` `_check_key:258` `_check_done:264` `_with_chance:269` `_apply_effects:282` `_cond_ok:317` `_subst:363` `rep_tier:368` `addr:383` `_greet_line:391` `_avoids:408` `_avoid_node:418` `_a_trinket:426` `_rep_greet:435` `_finish_typing:460` `_on_text_click:465` `_process:470` `_unhandled_key_input:480`

### scripts/ui/hud.gd (644) · class HUD
Приборная панель внизу экрана (как в прототипе): журнал, герой, оружие, кнопки.
`setup:52` `_build:65` `_make_slot:346` `refresh:370` `_slot_text:434` `refresh_objective:443` `_on_log:449` `_esc:465` `clear_log:469` `_mini_line:476` `think:496` `thought_visible:505` `_place_thought:509` `_draw_marks:527` `show_tip:552` `hide_tip:558` `flash_tip:564` `toast:570` `hurt_flash:580` `float_text:586` `show_zones:604` `hide_zones:618` `_process:623` `mouse_over_ui:639`

### scripts/ui/kpk.gd (440) · class KPK
Карманный компьютер на браслете. Пока браслета нет — просто «Сумка».
`setup:19` `open:76` `close:83` `has_tab:88` `render:94` `_g:128` `_item_btn:134` `_render_inv:158` `_equip:261` `_render_stat:274` `_open_sheet:342` `_render_cas:351` `_render_map:400` `_render_quests:410` `_render_notes:427` `_unhandled_key_input:436`

### scripts/ui/loot_window.gd (150) · class LootWindow
Окно обыска: что лежит в теле, сундуке или чужом кармане. Каждую вещь можно
`setup:18` `open:66` `entries:75` `_render:79` `take:109` `take_all:121` `close:132` `_unhandled_key_input:141`

### scripts/ui/map_view.gd (38) · class MapView
Карта локации на экране КПК: проходимые места, ты, люди, отметки.

### scripts/ui/menu.gd (291) · class GameMenu
Меню на весь экран в стиле ЭЛТ: главное, пауза, смерть, конец пролога.
`setup:16` `open:59` `_slider:132` `_item:156` `_on:180` `_unhandled_key_input:219`

### scripts/ui/model_view.gd (76) · class ModelView
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

### scripts/world/character.gd (1247) · class Character
Персонаж на локации: герой, жители, враги, звери.
`_ready:108` `uid:147` `_rebuild_preview:151` `_build_visual:183` `move_along:223` `stop:241` `bark:253` `barking:273` `apply_hero_skin:278` `fov:295` `in_view:305` `show_cone:321` `face_towards:355` `_process:361` `_patrol:405` `act:420` `set_held:428` `_chest_attach:472` `_low_ready:493` `_two_handed:500` `_setup_two_hands:504` `_update_two_hands:546` `_make_weapon_mesh:598` `muzzle_flash:637` `_animate:649` `_animate_clips:786` `_act_clip:831` `_clip_act:848` `_fire_cb_once:894` `_end_act:903` `show_bracelet:917` `_plain:951` `_plug_tick:961` `_sound:988` `_plug_build:994` `_plug_update:1043` `_seg:1065` `_plug_clear:1074` `_collect_meshes:1090` `_mark_kind:1097` `_update_marks:1119` `_set_ghost:1162` `_stencil_write:1187` `_stencil_mat:1207` `_sil_mat:1222` `_ring_mat:1233` `_sound_bolt:1245`

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

### scripts/world/interactable.gd (53) · class Interactable
Предмет или место, по которому можно кликнуть: подобрать, обыскать, выйти.

### scripts/world/location.gd (219) · class Location
Корневой скрипт любой локации.
`setup:22` `spawn_point:31` `characters:38` `character:48` `items:52` `item:62` `ws:66` `_apply_world_state:70` `scatter_table:94` `scatter_count:98` `_scatter_loot:109` `on_world_state_applied:159` `on_enter:163` `on_hero_moved:167` `on_dialog_action:172` `on_interact:177` `can_leave_edge:182` `edge_tip:187` `can_pick:192` `on_picked:196` `on_looted:200` `on_combat_round:204` `on_fighter_down:208` `on_combat_end:212` `dialog_cond:217`

### scripts/world/scatter.gd (38) · class Scatter
Россыпь одинаковых мелочей (трава, камыш, кочки, лужи) — одна отрисовка на всех.

### scripts/world/social.gd (439) · class Social
Жизнь вокруг героя: жители сами бросают реплики, с ними можно поболтать
`setup:24` `_st:29` `key:35` `affinity:39` `tier_text:44` `talks:54` `can_fight:64` `_pick:72` `_barks:76` `_peaceful:80` `_process:86` `_idle_step:117` `ambient_line:157` `archetype:181` `can_parley:202` `_squad:213` `parley:223` `_calm:250` `gifts_on_hand:265` `can_chat:273` `chatted_today:277` `chat:281` `_tier_note:311` `gift:320` `_add_aff:329` `provoke:352` `flee:377` `apply_hostile:391` `on_action:406`

### scripts/world/target_body.gd (41) · class TargetBody
Мишень для стрельбы: столб и соломенный щит с кругами.

### tools/audit_interact.gd (84)
Проверка: у каждого места в каждой локации каждое действие из меню даёт отклик

### tools/build_act1.gd (1979)
Генератор локаций первого акта: Кресты (живое поселение у реки) и
`_build:17` `_begin:40` `_finish:59` `_water_mats:71` `_river_plane:83` `_slot_of:99` `_homely:105` `_ground_for:124` `_paint:160` `_woods:190` `_blocked:228` `_free2:239` `_boxes_of:248` `_dress:272` `_cross:307` `_mound:324` `_net_rack:331` `_tent:351` `_lean_to:366` `_boat:381` `_exit:390` `_use:401` `_spawn:412` `_kresty:427` `_camp:637` `_encounter:713` `_spawn_mark:722` `_zaimka:734` `_truck:824` `_convoy:846` `_block:884` `_ruin:901` `_bunker_portal:991` `_radio_post:1053` `_dark_env:1186` `_lamp:1204` `_room_walls:1219` `_floor:1258` `_cellar:1263` `_glow:1321` `_upper:1330` `_bunker:1479` `_bunker_mats:1565` `_bk_panels:1592` `_hazard:1624` `_collapse:1636` `_bk_shaft:1651` `_bk_gate:1666` `_bk_corridor:1708` `_console:1741` `_reel_unit:1764` `_bk_control:1776` `_bk_barracks:1825` `_bk_generator:1856` `_bk_archive:1877` `_river_south:1904` `_stall:1914` `_signboard:1934` `_lamp_post:1954` `_laundry:1968`

### tools/build_city.gd (1227)
Каменный Сунгар (бывший посёлок городского типа): дома в 2–4 этажа из штукатурки
`_ready:18` `_city_materials:81` `_glow_mat:146` `swin:161` `balcony:202` `entry:237` `open_door:252` `roof:262` `stone_block:297` `_wkind:396` `_wear:415` `_shop_window:473` `_portico:485` `_shell:501` `_lining:525` `stair_flight:540` `partition_z:554` `_table:566` `_bed:583` `_wardrobe:594` `_counter:600` `_shelf_goods:606` `_stove:620` `_rug:626` `_plant:630` `_interior:638` `heat_pipes:823` `boiler_house:861` `water_tower:887` `garages:900` `kiosk:915` `bus_stop:931` `conc_fence:951` `paz_wreck:962` `bins:979` `furniture:991` `_stair_piece:1055` `_crt:1068` `cassette_props:1077` `ruin_props:1163`

### tools/build_hero_skin.gd (78)
Собирает сетку героя с новой развёрткой из assets/models/hero_skin_mesh.bin

### tools/build_nakharro.gd (1197)
Генератор большой деревни Нахарро (по референсу «Нахарра», ~40 человек):
`_ready:43` `_build:63` `_env:93` `_ground:134` `strip:186` `_ground_material:195` `_paint_splat:212` `_sd_rect:246` `_seg_dist:254` `_ring_dist:261` `_ditch_h:268` `_village:282` `_forest:368` `_forest_edge:421` `_raid:449` `_characters:467` `_seat:572` `_items:579` `_fence_mend:651` `_clear_overlaps:668` `_is_plant:736` `_inside:743` `_pal:752` `_moat:760` `_ditch_mesh:815` `_bridge:841` `_multi:858` `_xf:872` `_free_spot:876` `_details:885` `_building_boxes:975` `_tutorial_extras:1003` `_sacred_tree:1043` `_village_life:1117`

### tools/build_props.gd (1531)
Генератор построек и растительности в стиле референса «Нахарра».
`_ready:31` `_houses:67` `_tex_mat:81` `_card_mat:100` `_decal_mat:117` `_plain_mat:133` `_materials:145` `begin:214` `add:224` `rough:233` `rsphere:257` `rcone:266` `save_mesh:277` `box:293` `cyl:299` `prism:309` `solid:315` `finish:319` `_merge:377` `log_walls:405` `gable_roof:427` `window:471` `_window:477` `door:500` `wall_colliders:517` `plinth:531` `izba_interior:541` `porch:586` `chimney:601` `house:608` `hall:713` `tower:775` `barn:817` `shed:877` `workshop:892` `gate:917` `barricade:934` `greenhouse:950` `wind_turbine:975` `card:1001` `leaf:1019` `spruce:1026` `pine:1065` `birch:1099` `bush:1122` `dead_tree:1136` `rocks:1150` `tractor:1171` `palisades:1228` `small_props:1271` `scatter_meshes:1402` `travel_items:1449` `_item:1501` `junk:1509` `locked_box:1522`

### tools/build_rural.gd (903)
Деревня и дорога: постройки и вещи для Крестов (баня, часовня, коптильня, нужник,
`_ready:10` `village_props:43` `personal_items:165` `wreck_props:237` `_an2:353` `_cwing:452` `_rivets:471` `_mi8:479` `_scorch:575` `_grime:583` `_bb:593` `_rbox_mesh:608` `_rotor:633` `_vtol:647` `_drone:731` `_duct:782` `_ring_mesh:802` `_jet:816` `_tw:891` `beam:897`

### tools/build_scenes.gd (775)
Генератор стартовых сцен: материалы, пропсы (избы, амбар, деревья…),
`_ready:17` `_mat:30` `_materials:44` `_own:74` `box:80` `cyl:94` `sphere:110` `prism:125` `collider:137` `save_prop:153` `_props:167` `_izba:193` `_barn:214` `_shed:231` `_fence:244` `_well:261` `_woodpile:274` `_birch:285` `_larch:295` `_dead_tree:305` `_bush:315` `_border_post:323` `_sign:332` `_tractor:361` `_table:375` `_garden:387` `_fire:397` `_item_base:404` `_mushroom:411` `_berries:421` `_planks_item:432` `_basket:441` `_bandage:451` `_rock:458` `_main_scene:467` `fit_label:484` `_label_fits:504` `put:513` `group:526` `character:534` `item:552` `marker:559` `strip:569` `_nakharro:575`

### tools/build_sungar.gd (1427)
Сунгар — бывший посёлок городского типа: три района (ворота и рынок, центр,
`_build:20` `_edges:54` `_junk_fence:139` `_place_sentries:202` `_ep:210` `_bld:223` `_slot:228` `_face:237` `_pipes:242` `_pavement:251` `_stele:257` `_honor_board:283` `_sign_on:312` `_clear_town:323` `_clutter:340` `_broken_road:351` `_power_line:392` `_neon:423` `_graffiti:439` `_info_screen:453` `_cop:470` `_stairs_item:479` `_sungar:488` `_barge:676` `_sungar_center:715` `_sungar_quarter:881` `_house_begin:1010` `_house_finish:1038` `_finish:1043` `_lw:1053` `_lw_gaps:1073` `_bulb:1099` `_door_no:1110` `_corridor_floor:1126` `_furnish:1202` `_rp:1277` `_to_door:1284` `_hotel_floors:1291` `_dom_floors:1326` `_obshaga_floors:1366` `_admin_floors:1403`

### tools/build_weapons.gd (260)
Собирает модели оружия из загруженных файлов в assets/models/weapons/<ключ>/
`_init:48` `_cfg:56` `_source_meshes:70` `_material:90` `_build_proc:125` `_build:178` `_painted:244`

### tools/check_scripts.gd (115)
Проверка: загружает все скрипты проекта и сообщает об ошибках.

### tools/decimate_mesh.gd (62)
Упрощает тяжёлую модель: берёт первую сетку из .glb/.fbx, строит уровни детализации

### tools/preview_prop.gd (26)
Превью одного пропа: тот же свет, что в деревне, изометрическая камера.

### tools/render_shots.gd (110)
Скриншоты для проверки (нужен рендер, не --headless):

### tools/screenshots.gd (107)
Снимки экрана для проверки интерфейса (нужен рендер, не --headless).

### tools/smoke_test.gd (2791)
Автотест пролога: проходит всю цепочку без участия человека и печатает, что сломалось.
`new_enc:12` `ok:17` `wait:25` `frames:29` `close_dialogs:34` `shut:43` `choose:48` `opt_texts:54` `find_opt:61` `tp:69` `fight:76` `wait_loading:118` `unreachable:127` `go_upstairs:156` `go_downstairs:166` `nakharro_life_tests:177` `kresty_life_tests:355` `encounter_lore_tests:434` `city_tests:502` `admin_tests:695` `weather_tests:773` `social_tests:840` `sungar_tests:930` `_ready:1087`

## Данные (data/)

- data/barks.json (459 строк)
- data/characters.json (129 строк)
- data/dialogs/camp_boss.json (368 строк)
- data/dialogs/camp_nyurgun.json (194 строк)
- data/dialogs/camp_rumors.json (109 строк)
- data/dialogs/camp_thug.json (210 строк)
- data/dialogs/camp_trader.json (198 строк)
- data/dialogs/camp_wounded.json (230 строк)
- data/dialogs/ded.json (390 строк)
- data/dialogs/defender.json (14 строк)
- data/dialogs/ebee.json (228 строк)
- data/dialogs/elder.json (255 строк)
- data/dialogs/enc_accused.json (23 строк)
- data/dialogs/enc_carter.json (131 строк)
- data/dialogs/enc_deserter.json (179 строк)
- data/dialogs/enc_jaeger.json (118 строк)
- data/dialogs/enc_lost_kid.json (104 строк)
- data/dialogs/enc_pilgrim.json (68 строк)
- data/dialogs/enc_postman.json (83 строк)
- data/dialogs/enc_refugee.json (70 строк)
- data/dialogs/enc_road_trader.json (135 строк)
- data/dialogs/enc_shaman.json (152 строк)
- data/dialogs/enc_trapped_hunter.json (117 строк)
- data/dialogs/enc_trial.json (118 строк)
- data/dialogs/gambler.json (176 строк)
- data/dialogs/girl.json (212 строк)
- data/dialogs/guard.json (119 строк)
- data/dialogs/hay_quarrel.json (151 строк)
- data/dialogs/hermit.json (457 строк)
- data/dialogs/hs_kid1.json (28 строк)
- data/dialogs/hs_kid2.json (28 строк)
- data/dialogs/hs_kid3.json (28 строк)
- data/dialogs/hunter.json (180 строк)
- data/dialogs/kid.json (239 строк)
- data/dialogs/kr_banya.json (99 строк)
- data/dialogs/kr_brewer.json (587 строк)
- data/dialogs/kr_drunk.json (372 строк)
- data/dialogs/kr_fisher.json (259 строк)
- data/dialogs/kr_guard.json (168 строк)
- data/dialogs/kr_head.json (429 строк)
- data/dialogs/kr_herder.json (83 строк)
- data/dialogs/kr_kid.json (95 строк)
- data/dialogs/kr_motryona.json (104 строк)
- data/dialogs/kr_old.json (271 строк)
- data/dialogs/kr_rumors.json (140 строк)
- data/dialogs/kr_smith.json (117 строк)
- data/dialogs/kr_trader.json (367 строк)
- data/dialogs/radio_kid.json (106 строк)
- data/dialogs/road.json (1268 строк)
- data/dialogs/rumors.json (54 строк)
- data/dialogs/sg_archylan.json (88 строк)
- data/dialogs/sg_barman.json (164 строк)
- data/dialogs/sg_brawler.json (47 строк)
- data/dialogs/sg_butcher.json (117 строк)
- data/dialogs/sg_chief.json (239 строк)
- data/dialogs/sg_clerk.json (204 строк)
- data/dialogs/sg_collector.json (76 строк)
- data/dialogs/sg_cop.json (244 строк)
- data/dialogs/sg_dealer.json (125 строк)
- data/dialogs/sg_fishwife.json (58 строк)
- data/dialogs/sg_granny.json (64 строк)
- data/dialogs/sg_guard.json (347 строк)
- data/dialogs/sg_guest.json (143 строк)
- data/dialogs/sg_gunsmith.json (122 строк)
- data/dialogs/sg_head.json (136 строк)
- data/dialogs/sg_hostess.json (229 строк)
- data/dialogs/sg_innkeeper.json (180 строк)
- data/dialogs/sg_market_boss.json (198 строк)
- data/dialogs/sg_merchant.json (122 строк)
- data/dialogs/sg_mother.json (150 строк)
- data/dialogs/sg_operator.json (81 строк)
- data/dialogs/sg_passport.json (149 строк)
- data/dialogs/sg_radio.json (104 строк)
- data/dialogs/sg_rival.json (64 строк)
- data/dialogs/sg_runaway.json (117 строк)
- data/dialogs/sg_stoker.json (172 строк)
- data/dialogs/sg_storekeeper.json (46 строк)
- data/dialogs/sg_teacher.json (112 строк)
- data/dialogs/sg_thief.json (145 строк)
- data/dialogs/sg_watchwoman.json (46 строк)
- data/dialogs/shooter.json (179 строк)
- data/dialogs/sick.json (138 строк)
- data/dialogs/smith.json (302 строк)
- data/dialogs/stepan.json (132 строк)
- data/dialogs/teacher.json (107 строк)
- data/dialogs/thoughts.json (442 строк)
- data/dialogs/varvara.json (250 строк)
- data/dialogs/water.json (113 строк)
- data/elley.json (15 строк)
- data/intro.json (18 строк)
- data/items.json (99 строк)
- data/lore.json (115 строк)
- data/observations.json (81 строк)
- data/presets.json (22 строк)
- data/quests.json (562 строк)
- data/rep_greet.json (34 строк)
- data/schedules.json (451 строк)
- data/weapons.json (20 строк)
- data/world.json (2967 строк)
