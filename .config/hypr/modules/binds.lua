hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = "scroll_move" })
hl.gesture({ fingers = 3, direction = "down", action = "scroll_move" })
hl.gesture({ fingers = 4, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
hl.gesture({ fingers = 4, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
hl.gesture({ fingers = 4, direction = "up", action = "special" })
hl.gesture({ fingers = 4, direction = "down", action = "special" })
hl.gesture({ fingers = 2, direction = "pinchin", action = "cursor_zoom" })
hl.gesture({ fingers = 2, direction = "pinchout", action = "cursor_zoom" })


local hs = require("plugins.hyprsplit")

hs.config({
    num_workspaces = 5,
    persistent_workspaces = false,
    force_monitor_priority = true,
})

hs.monitor_priority({ "VGA-1", "LVDS-1" })
-- Цикл для автоматического создания биндов 1..5
for i = 1, 5 do
    -- Переключение воркспейса на активном мониторе (SUPER + 1..5)
    hl.bind(mainMod .. "+" .. i, hs.dsp.focus({ workspace = i }))

    -- Перенос окна на воркспейс на активном мониторе (SUPER + SHIFT + 1..5)
    hl.bind(mainMod .. "+SHIFT+" .. i, hs.dsp.window.move({ workspace = i }))
end

local function toggle_layout()
    if hl.get_config("general.layout") == "scrolling" then
        hl.config({ general = { layout = "dwindle" } })
    else
        hl.config({ general = { layout = "scrolling" } })
    end
end

hl.bind(mainMod .. "+K", hl.dsp.exec_cmd(terminal), { description = "Открыть терминал" })
hl.bind(mainMod .. "+E", hl.dsp.exec_cmd(fileManager), { description = "Открыть файловый менеджер" })
hl.bind(mainMod .. "+SPACE", hl.dsp.exec_cmd(menu), { description = "Открыть меню приложений" })
hl.bind(mainMod .. "+V", hl.dsp.exec_cmd(home .. ".config/hypr/top/scripts/clipboard.sh"),
    { description = "Открыть историю буфера обмена" })
hl.bind(mainMod .. "+L", hl.dsp.exec_cmd("quickshell ipc call lockscreen lock"), { description = "Заблокировать экран" })
hl.bind(mainMod .. "+SHIFT+C", hl.dsp.exec_cmd("hyprpicker"), { description = "Выбрать цвет с экрана" })
hl.bind(mainMod .. "+SHIFT+S", hl.plugin.hyprcapture.open, { description = "Сделать снимок экрана" })
hl.bind(mainMod .. "+SHIFT+R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.lua"),
    { description = "Перезагрузить конфигурацию Hyprland" })
hl.bind(mainMod .. "+W", hl.dsp.window.close(), { description = "Закрыть активное окно" })
hl.bind(mainMod .. "+F", hl.dsp.window.fullscreen({ mode = 0 }), { description = "Переключить полноэкранный режим" })
hl.bind(mainMod .. "+SHIFT+F", hl.dsp.window.float({ action = "toggle" }), { description = "Переключить плавающее окно" })
hl.bind(mainMod .. "+SHIFT+M", hl.dsp.window.fullscreen({ mode = 1 }), { description = "Переключить максимизацию окна" })
hl.bind(mainMod .. "+Y", hl.dsp.window.pin({ action = "toggle" }), { description = "Закрепить окно поверх остальных" })
hl.bind(mainMod .. "+LEFT", hl.dsp.focus({ direction = "l" }), { description = "Переместить фокус на окно слева" })
hl.bind(mainMod .. "+RIGHT", hl.dsp.focus({ direction = "r" }), { description = "Переместить фокус на окно справа" })
hl.bind(mainMod .. "+UP", hl.dsp.focus({ direction = "u" }), { description = "Переместить фокус на окно сверху" })
hl.bind(mainMod .. "+DOWN", hl.dsp.focus({ direction = "d" }), { description = "Переместить фокус на окно снизу" })
hl.bind(mainMod .. "+SHIFT+LEFT", hl.dsp.window.swap({ direction = "l" }),
    { description = "Поменять активное окно местами с левым" })
hl.bind(mainMod .. "+SHIFT+RIGHT", hl.dsp.window.swap({ direction = "r" }),
    { description = "Поменять активное окно местами с правым" })
hl.bind(mainMod .. "+SHIFT+UP", hl.dsp.window.swap({ direction = "u" }),
    { description = "Поменять активное окно местами с верхним" })
hl.bind(mainMod .. "+SHIFT+DOWN", hl.dsp.window.swap({ direction = "d" }),
    { description = "Поменять активное окно местами с нижним" })
hl.bind(mainMod .. "+ALT+LEFT", hl.dsp.window.resize({ x = -40, y = 0, relative = true }),
    { repeating = true, description = "Уменьшить ширину окна" })
hl.bind(mainMod .. "+ALT+RIGHT", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),
    { repeating = true, description = "Увеличить ширину окна" })
hl.bind(mainMod .. "+ALT+UP", hl.dsp.window.resize({ x = 0, y = -40, relative = true }),
    { repeating = true, description = "Уменьшить высоту окна" })
hl.bind(mainMod .. "+ALT+DOWN", hl.dsp.window.resize({ x = 0, y = 40, relative = true }),
    { repeating = true, description = "Увеличить высоту окна" })
hl.bind(mainMod .. "+EQUAL", hl.dsp.layout("colresize +conf"), { description = "Увеличить размер колонки" })
hl.bind(mainMod .. "+MINUS", hl.dsp.layout("colresize -conf"), { description = "Уменьшить размер колонки" })
hl.bind(mainMod .. "+H", hl.dsp.layout("fit expand"), { description = "Расширить текущую раскладку" })
hl.bind(mainMod .. "+SHIFT+H", hl.dsp.layout("fit all"), { description = "Вместить все окна в экран" })
hl.bind(mainMod .. "+P", hl.dsp.layout("promote"), { description = "Переместить окно в главный слот" })
hl.bind(mainMod .. "+SHIFT+L", toggle_layout, { description = "Переключить scrolling и dwindle" })
hl.bind(mainMod .. "+SHIFT+N",
    hl.dsp.exec_cmd("hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/NightLight.frag"),
    { description = "Включить ночной свет" })
hl.bind(mainMod .. "+CONTROL+N", hl.dsp.exec_cmd("hyprctl keyword decoration:screen_shader none"),
    { description = "Выключить ночной свет" })
hl.bind(mainMod .. "+1", hl.dsp.focus({ workspace = 1 }), { description = "Перейти на рабочий стол 1" })
hl.bind(mainMod .. "+2", hl.dsp.focus({ workspace = 2 }), { description = "Перейти на рабочий стол 2" })
hl.bind(mainMod .. "+3", hl.dsp.focus({ workspace = 3 }), { description = "Перейти на рабочий стол 3" })
hl.bind(mainMod .. "+4", hl.dsp.focus({ workspace = 4 }), { description = "Перейти на рабочий стол 4" })
hl.bind(mainMod .. "+5", hl.dsp.focus({ workspace = 5 }), { description = "Перейти на рабочий стол 5" })
hl.bind(mainMod .. "+6", hl.dsp.focus({ workspace = 6 }), { description = "Перейти на рабочий стол 6" })
hl.bind(mainMod .. "+7", hl.dsp.focus({ workspace = 7 }), { description = "Перейти на рабочий стол 7" })
hl.bind(mainMod .. "+8", hl.dsp.focus({ workspace = 8 }), { description = "Перейти на рабочий стол 8" })
hl.bind(mainMod .. "+9", hl.dsp.focus({ workspace = 9 }), { description = "Перейти на рабочий стол 9" })
hl.bind(mainMod .. "+0", hl.dsp.focus({ workspace = 10 }), { description = "Перейти на рабочий стол 10" })
hl.bind(mainMod .. "+SHIFT+1", hl.dsp.window.move({ workspace = 1 }),
    { description = "Переместить окно на рабочий стол 1" })
hl.bind(mainMod .. "+SHIFT+2", hl.dsp.window.move({ workspace = 2 }),
    { description = "Переместить окно на рабочий стол 2" })
hl.bind(mainMod .. "+SHIFT+3", hl.dsp.window.move({ workspace = 3 }),
    { description = "Переместить окно на рабочий стол 3" })
hl.bind(mainMod .. "+SHIFT+4", hl.dsp.window.move({ workspace = 4 }),
    { description = "Переместить окно на рабочий стол 4" })
hl.bind(mainMod .. "+SHIFT+5", hl.dsp.window.move({ workspace = 5 }),
    { description = "Переместить окно на рабочий стол 5" })
hl.bind(mainMod .. "+SHIFT+6", hl.dsp.window.move({ workspace = 6 }),
    { description = "Переместить окно на рабочий стол 6" })
hl.bind(mainMod .. "+SHIFT+7", hl.dsp.window.move({ workspace = 7 }),
    { description = "Переместить окно на рабочий стол 7" })
hl.bind(mainMod .. "+SHIFT+8", hl.dsp.window.move({ workspace = 8 }),
    { description = "Переместить окно на рабочий стол 8" })
hl.bind(mainMod .. "+SHIFT+9", hl.dsp.window.move({ workspace = 9 }),
    { description = "Переместить окно на рабочий стол 9" })
hl.bind(mainMod .. "+SHIFT+0", hl.dsp.window.move({ workspace = 10 }),
    { description = "Переместить окно на рабочий стол 10" })
hl.bind(mainMod .. "+GRAVE", hl.dsp.workspace.toggle_special("magic"),
    { description = "Переключить специальный рабочий стол magic" })
hl.bind(mainMod .. "+SHIFT+GRAVE", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Переместить окно на специальный рабочий стол magic" })
hl.bind(mainMod .. "+G", hl.dsp.group.toggle(), { description = "Переключить группу окон" })
hl.bind(mainMod .. "+TAB", hl.dsp.group.next(), { description = "Перейти к следующему окну в группе" })
hl.bind(mainMod .. "+SHIFT+TAB", hl.dsp.group.prev(), { description = "Перейти к предыдущему окну в группе" })
hl.bind(mainMod .. "+SHIFT+G", hl.dsp.group.lock({ action = "toggle" }),
    { description = "Заблокировать или разблокировать группу" })
hl.bind(mainMod .. "+CONTROL+E", hl.dsp.window.move({ out_of_group = true }), { description = "Вынести окно из группы" })
hl.bind(mainMod .. "+CONTROL+LEFT", hl.dsp.window.move({ into_or_create_group = "l" }),
    { description = "Переместить окно в группу слева" })
hl.bind(mainMod .. "+CONTROL+RIGHT", hl.dsp.window.move({ into_or_create_group = "r" }),
    { description = "Переместить окно в группу справа" })
hl.bind(mainMod .. "+CONTROL+UP", hl.dsp.window.move({ into_or_create_group = "u" }),
    { description = "Переместить окно в группу сверху" })
hl.bind(mainMod .. "+CONTROL+DOWN", hl.dsp.window.move({ into_or_create_group = "d" }),
    { description = "Переместить окно в группу снизу" })
hl.bind(mainMod .. "+SLASH", hl.dsp.exec_cmd("qs -p ~/.config/hypr/quickshell/shell.qml ipc call binds toggle"),
    { description = "Список горячих клавиш" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { repeating = true, locked = true, description = "Увеличить громкость" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { repeating = true, locked = true, description = "Уменьшить громкость" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, description = "Включить или выключить звук" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, description = "Включить или выключить микрофон" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true, description = "Воспроизведение или пауза" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Следующий трек" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Предыдущий трек" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"),
    { repeating = true, locked = true, description = "Увеличить яркость экрана" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),
    { repeating = true, locked = true, description = "Уменьшить яркость экрана" })
hl.bind(mainMod .. "+mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Перемещать окно мышью" })
hl.bind(mainMod .. "+mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Изменять размер окна мышью" })
hl.bind("ALT+TAB", function() hl.plugin.scrolloverview.overview("toggle all") end,
    { description = "Открыть обзор окон" })
hl.bind(mainMod .. "+SHIFT+W", hl.dsp.exit(), { description = "Выйти из Hyprland" })
hl.bind(mainMod .. "+ALT+S", hl.dsp.exec_cmd("~/.config/hypr/scripts/freeze.lua"))
hl.bind(mainMod .. "+mouse_down", hl.dsp.focus({ direction = "r" }),
    { description = "Сфокусировать следующее окно на ленте" })
hl.bind(mainMod .. "+mouse_up", hl.dsp.focus({ direction = "l" }),
    { description = "Сфокусировать предыдущее окно на ленте" })
hl.bind(mainMod .. "+SHIFT+mouse_down", hl.dsp.focus({ workspace = "+1" }),
    { description = "Перейти на следующий рабочий стол" })
hl.bind(mainMod .. "+SHIFT+mouse_up", hl.dsp.focus({ workspace = "-1" }),
    { description = "Перейти на предыдущий рабочий стол" })
