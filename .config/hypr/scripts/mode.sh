#!/bin/bash

# 1. Сразу при старте проверяем текущий submap и выводим его
CURRENT=$(hyprctl activeworkspace -j | jq -r '.submap')
if [ -z "$CURRENT" ] || [ "$CURRENT" = "null" ]; then
    echo "INSERT"
else
    echo "$CURRENT" | tr '[:lower:]' '[:upper:]'
fi

# 2. Дальше запускаем бесконечный поток прослушивания событий
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | stdbuf -o0 awk -F '>>' '/submap/{if($2=="") print "INSERT"; else print toupper($2)}'
