#!/bin/bash
# Скачать Godot 4.7.2 и шаблоны экспорта (один раз на новую машину/сессию).
# После: G=~/godot/Godot_v4.7.2-stable_linux.x86_64
set -e
V=4.7.2-stable
mkdir -p ~/godot && cd ~/godot
if [ ! -x Godot_v${V}_linux.x86_64 ]; then
  curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_linux.x86_64.zip
  unzip -oq g.zip && rm g.zip && chmod +x Godot_v${V}_linux.x86_64
fi
T=~/.local/share/godot/export_templates/4.7.2.stable
if [ ! -d "$T" ]; then
  curl -sSL -o t.tpz https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_export_templates.tpz
  mkdir -p "$T" && unzip -oq t.tpz -d tt && mv tt/templates/* "$T"/ && rm -rf tt t.tpz
fi
echo "Godot готов: ~/godot/Godot_v${V}_linux.x86_64"
