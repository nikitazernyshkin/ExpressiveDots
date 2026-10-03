#!/usr/bin/env lua

-- 1. Запрашиваем JSON активного окна через hyprctl
local handle = io.popen("hyprctl activewindow -j")
local result = handle:read("*a")
handle:close()

-- 2. Достаем PID процесса средствами регулярных выражений Lua
local pid = result:match('"pid":%s*(%d+)')

if pid and pid ~= "0" then
    -- 3. Проверяем текущее состояние процесса (Т — процесс остановлен/заморожен)
    local state_handle = io.popen("ps -o state= -p " .. pid)
    local state = state_handle:read("*a"):gsub("%s+", "")
    state_handle:close()

    -- 4. Переключаем состояние в зависимости от флага
    if state == "T" then
        os.execute("kill -CONT " .. pid)  -- Разморозить
    else
        os.execute("kill -STOP " .. pid)  -- Заморозить
    end
end
