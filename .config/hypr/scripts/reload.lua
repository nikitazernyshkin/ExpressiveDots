#!/usr/bin/env lua

-- Функция для выполнения системных команд в фоновом режиме (аналог &)
local function run_bg(cmd)
    os.execute(cmd .. " &")
end

-- Функция для выполнения команд с ожиданием завершения
local function run(cmd)
    os.execute(cmd)
end

-- 1. Убиваем старые процессы (pkill)
run("pkill -f autolight.sh")
run("pkill -f dunst")
run("pkill awww-daemon")
run("pkill -f quickshell")

-- 3. Запускаем quickshell в фоне
run_bg("qs -p ~/.config/hypr/quickshell/shell.qml")

-- 4. Перезагружаем конфиг Hyprland
run("hyprctl reload")

-- 5. Запускаем dunst и awww-daemon в фоне
run_bg("dunst")
run_bg("awww-daemon")
