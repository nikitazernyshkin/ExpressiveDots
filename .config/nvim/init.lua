-- ==========================================
-- 1. БАЗОВЫЕ НАСТРОЙКИ И СИСТЕМНЫЙ БУФЕР ОБМЕНА
-- ==========================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.incsearch = true
opt.hlsearch = true
opt.mouse = "a"
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.wrap = false
opt.termguicolors = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.cursorline = true
opt.clipboard = "unnamedplus"

local keymap = vim.keymap.set
keymap("n", "<leader>w", ":w<CR>", { desc = "Сохранить" })
keymap("n", "<leader>q", ":q<CR>", { desc = "Выйти" })
keymap("n", "<S-l>", ":bnext<CR>", { desc = "Следующий буфер" })
keymap("n", "<S-h>", ":bprevious<CR>", { desc = "Предыдущий буфер" })
keymap("n", "<leader>x", ":bdelete<CR>", { desc = "Закрыть буфер" })
keymap("i", "jj", "<Esc>", { desc = "Выйти из режима вставки" })

-- ==========================================
-- 2. УСТАНОВКА LAZY.NVIM
-- ==========================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazypath)

-- ==========================================
-- 3. ПЛАГИНЫ И МАТЕРИАЛЬНЫЙ ДИЗАЙН (EXPRESSIVE)
-- ==========================================
require("lazy").setup({

    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        config = true
    },

    {
        "mfussenegger/nvim-jdtls",
        ft = { "java" },
        dependencies = { "williamboman/mason.nvim" },
        -- Запуск jdtls требует специфичного подхода (через автокоманду ftplugin),
        -- поэтому в mason-lspconfig его автоматически не стартуют.
        -- Для Java этот плагин — безальтернативный стандарт.
    },

    -- 2. Протокол отладки (DAP) — замена встроенного дебаггера Android Studio
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            -- Красивый UI для дебага (Переменные, стек вызовов, точки останова как в IDE)
            { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            dapui.setup()

            -- Автоматически открывать/закрывать UI дебаггера
            dap.listeners.before.attach.dapui_config = function() dapui.open() end
            dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
            dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

            -- Горячие клавиши для отладки
            vim.keymap.set("n", "<F5>", dap.continue, { desc = "Дебаг: Старт / Продолжить" })
            vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Дебаг: Шаг обойти" })
            vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Дебаг: Шаг внутрь" })
            vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Дебаг: Шаг наружу" })
            vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Дебаг: Точка останова" })
        end,
    },

    -- 3. Специализированный плагин для Android-разработки
    -- Умеет запускать эмуляторы, собирать проект через gradle, деплоить APK и читать Logcat
    {
        "iamironz/android-nvim-plugin",
        ft = { "kotlin", "java", "xml" },
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("android").setup({
                -- Укажите путь к вашему Android SDK, если он отличается от стандартного
                sdk_path = vim.fn.expand("~/Android/Sdk"),
            })

            -- Клавиши для сборки и запуска
            vim.keymap.set("n", "<leader>am", ":AndroidImageMenu<CR>", { desc = "Android: Меню эмуляторов" })
            vim.keymap.set("n", "<leader>ar", ":AndroidProjectRun<CR>", { desc = "Android: Запустить проект" })
            vim.keymap.set("n", "<leader>ab", ":AndroidProjectBuild<CR>", { desc = "Android: Собрать проект" })
            vim.keymap.set("n", "<leader>al", ":AndroidLogcat<CR>", { desc = "Android: Открыть Logcat" })
        end,
    },

    -- 4. Подсветка синтаксиса, структуры кода и XML макетов
    -- Без этого Neovim не поймет синтаксис Kotlin-файлов и разметку Android-экранов
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        -- С помощью opts мы безопасно передаем настройки.
        -- Пакетный менеджер сам применит их после того, как скачает плагин.
        opts = {
            ensure_installed = { "c", "cpp", "python", "lua", "kotlin", "java", "xml", "groovy", "html", "vim", "vimdoc", "query", "bash", "json", "yaml", "cmake", "make", "markdown" },
            highlight = { enable = true },
        },
    },
    -- Загрузка динамических цветов от Matugen без хардкода
    {
        dir = vim.fn.stdpath("config"),
        name = "matugen-theme",
        lazy = false,
        priority = 1000,
        config = function()
            local ok, colors = pcall(require, "config.colors")
            if ok and colors then
                vim.cmd(string.format("highlight Normal guibg=%s guifg=%s", colors.bg, colors.fg))
                vim.cmd(string.format("highlight CursorLine guibg=%s", colors.surface_container))
                vim.cmd(string.format("highlight Visual guibg=%s", colors.primary_container))
            end
        end,
    },

    -- Хлебные крошки (Breadcrumbs) вверху экрана
    {
        "utilyre/barbecue.nvim",
        name = "barbecue",
        version = "*",
        dependencies = {
            "SmiteshP/nvim-navic",
            "nvim-tree/nvim-web-devicons", -- optional dependency
        },
        opts = {
            -- configurations go here
        },
    },

    -- Файловое дерево
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
        keys = {
            { "<leader>e", ":Neotree toggle left filesystem<CR>", desc = "Файловое дерево" },
            { "<leader>b", ":Neotree toggle left buffers<CR>", desc = "Вертикальные вкладки (буферы)" },
        },
        config = function()
            require("neo-tree").setup({
                source_selector = {
                    winbar = false,
                    statusline = false,
                },
                filesystem = {
                    hijack_netrw = true,
                },
                buffers = {
                    follow_current_file = { enabled = true }, -- Подсвечивать файл, в котором мы сейчас сидим
                },
            })
        end
    },

    -- Поиск Telescope
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local builtin = require("telescope.builtin")
            vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Поиск файлов" })
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Поиск текста" })
        end,
    },

    -- Статусная строка со скруглениями (Material 3 Expressive капсулы)
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            local ok, c = pcall(require, "config.colors")
            -- Получаем системные fallback-цвета программно, если matugen не загрузился
            local normal_bg = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg#")
            local normal_fg = vim.fn.synIDattr(vim.fn.hlID("Normal"), "fg#")
            local cursorline_bg = vim.fn.synIDattr(vim.fn.hlID("CursorLine"), "bg#")

            -- Защита от пустых строк, если тема еще не инициализировала Normal
            if normal_bg == "" then normal_bg = "none" end
            if normal_fg == "" then normal_fg = "none" end
            if cursorline_bg == "" then cursorline_bg = "none" end

            local m_theme = {
                normal = {
                    a = {
                        fg = ok and c.bg or normal_bg,
                        bg = ok and c.primary or normal_fg,
                        gui = "bold"
                    },
                    b = {
                        fg = ok and c.fg or normal_fg,
                        bg = ok and c.surface_container or cursorline_bg
                    },
                    c = {
                        fg = ok and c.fg or normal_fg,
                        bg = ok and c.surface or normal_bg
                    },
                },
            }

            require("lualine").setup({
                options = {
                    theme = m_theme,
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" }, -- Скругленные края капсул
                    globalstatus = true,
                },
                sections = {
                    lualine_a = { { "mode", separator = { left = "", right = "" } } },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "encoding", "fileformat", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { { "location", separator = { left = "", right = "" } } },
                },
            })
        end,
    },

    -- Новое поколение автодополнения (красивое, быстрое, со скругленными меню)
    {
        "saghen/blink.cmp",
        lazy = false,
        dependencies = "rafamadriz/friendly-snippets",
        version = "v0.*",
        opts = {
            keymap = {
                preset = "default",
                ["<CR>"] = { "accept", "fallback" },
            },
            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = "mono"
            },
            completion = {
                menu = { border = "rounded" },
                documentation = { window = { border = "rounded" } },
            },
        },
    },

    -- Утилита для автоматической настройки Lua окружения (Neovim API, xplr, плагины)
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {
                { path = "xplr", words = { "xplr" } },
            },
        },
    },

    -- Единственный актуальный блок LSP (работает в связке с blink.cmp и lazydev)
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "saghen/blink.cmp",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = { "pyright", "lua_ls", "kotlin_language_server", "clangd", "qmlls", "jdtls" },
            })

            local capabilities = require("blink.cmp").get_lsp_capabilities()
            local servers = { "pyright", "kotlin_language_server", "clangd", "qmlls" }

            for _, lsp in ipairs(servers) do
                vim.lsp.config(lsp, { capabilities = capabilities })
                vim.lsp.enable(lsp)
            end

            -- Настройка lua_ls с поддержкой Hyprland, xplr и Neovim
            vim.lsp.config("lua_ls", {
                capabilities = capabilities,
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        diagnostics = { globals = { "vim", "hl", "xplr" } },
                        workspace = {
                            library = { vim.fn.expand("~/.config/hypr/stubs") },
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                    },
                },
            })
            vim.lsp.enable("lua_ls")
        end,
    },

    -- Перерисовка UI поиска и командной строки на старом месте (внизу)
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = {
            "MunifTanjim/nui.nvim",
            "stevearc/dressing.nvim",
        },
        config = function()
            require("noice").setup({
                lsp = {
                    override = {
                        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                        ["vim.lsp.util.stylize_markdown"] = true,
                        ["cmp.entry.get_documentation"] = true,
                    },
                },
                presets = {
                    bottom_search = true,
                    command_palette = false,
                    long_message_to_split = true,
                    inc_rename = false,
                },
                views = {
                    cmdline_popup = {
                        position = {
                            row = "100%",
                            col = 0,
                        },
                        size = {
                            width = "100%",
                            height = "auto",
                        },
                        border = {
                            style = "none",
                        },
                        win_options = {
                            winhighlight = "Normal:Normal,FloatBorder:Normal",
                        },
                    },
                },
            })
        end,
    },

    -- 2. Разноцветные скобки
    {
        "HiPhish/rainbow-delimiters.nvim",
        dependencies = "nvim-treesitter/nvim-treesitter",
    },

    -- 3. Красивые линии отступов
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        opts = {
            indent = { char = "│" },
            scope = { enabled = true },
        },
    },

    -- IDE: удобные клавиши и подсказки
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = { preset = "modern" },
    },

    -- Поиск ошибок и диагностики в отдельной панели
    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {},
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Ошибки проекта" },
            { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Ошибки текущего файла" },
            { "<leader>cs", "<cmd>Trouble symbols toggle<cr>", desc = "Структура кода" },
            { "<leader>cl", "<cmd>Trouble lsp toggle<cr>", desc = "LSP-ссылки" },
        },
    },

    -- Git: изменения рядом со строками и быстрые действия
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {},
        keys = {
            { "]c", function() require("gitsigns").next_hunk() end, desc = "Следующий Git hunk" },
            { "[c", function() require("gitsigns").prev_hunk() end, desc = "Предыдущий Git hunk" },
            { "<leader>gp", function() require("gitsigns").preview_hunk() end, desc = "Показать изменение" },
            { "<leader>gb", function() require("gitsigns").blame_line() end, desc = "Git blame строки" },
            { "<leader>gr", function() require("gitsigns").reset_hunk() end, desc = "Откатить изменение строки" },
        },
    },

    -- Форматирование кода (использует установленные clang-format, black, stylua и ktlint)
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        keys = {
            { "<leader>f", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, desc = "Форматировать файл" },
        },
        opts = {
            formatters_by_ft = {
                lua = { "stylua" },
                python = { "ruff_format", "black", stop_after_first = true },
                c = { "clang_format" },
                cpp = { "clang_format" },
                java = { "google_java_format" },
                kotlin = { "ktlint" },
                qml = { "qmlformat" },
            },
            format_on_save = function(bufnr)
                if vim.g.disable_autoformat then return end
                return { timeout_ms = 1500, lsp_format = "fallback", bufnr = bufnr }
            end,
        },
    },

    -- Быстрое переключение между .h/.cpp и похожими файлами
    {
        "tpope/vim-projectionist",
        event = "VeryLazy",
    },

    -- TODO/FIXME в проекте
    {
        "folke/todo-comments.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {},
        keys = {
            { "]t", function() require("todo-comments").jump_next() end, desc = "Следующий TODO" },
            { "[t", function() require("todo-comments").jump_prev() end, desc = "Предыдущий TODO" },
            { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Найти TODO/FIXME" },
        },
    },

    -- Терминал внутри Neovim
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        keys = {
            { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Встроенный терминал" },
            { "<leader>tt", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Терминал снизу" },
        },
        opts = {
            size = 12,
            open_mapping = [[<C-\>]],
            direction = "horizontal",
            shade_terminals = false,
            persist_size = true,
            start_in_insert = true,
        },
    },

    -- Тесты: интерфейс для запуска тестовых наборов
    {
        "nvim-neotest/neotest",
        cmd = { "Neotest", "NeotestSummary" },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
            "antoinemadec/FixCursorHold.nvim",
        },
        opts = {},
        keys = {
            { "<leader>tn", function() require("neotest").run.run() end, desc = "Запустить ближайший тест" },
            { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Тесты текущего файла" },
            { "<leader>to", function() require("neotest").summary.toggle() end, desc = "Панель тестов" },
        },
    },

})


-- ==========================================
-- 4. IDE: запуск файлов и проектов
-- ==========================================
-- Запуск в терминале Neovim. Команды не требуют shell-конкатенации пользовательского ввода.
local function notify_missing(command)
    vim.notify(
        ("Не найдена команда '%s'. Установи её и проверь PATH."):format(command),
        vim.log.levels.ERROR,
        { title = "Code Runner" }
    )
end

local function executable(command)
    if vim.fn.executable(command) == 1 then return true end
    notify_missing(command)
    return false
end

local function project_root(file)
    local markers = {
        "Makefile", "makefile", "CMakeLists.txt", "compile_commands.json",
        "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
        "pyproject.toml", "setup.py", "package.json", ".git",
    }
    local found = vim.fs.find(markers, { upward = true, path = vim.fs.dirname(file) })[1]
    return found and vim.fs.dirname(found) or vim.fs.dirname(file)
end

local function open_run_terminal(command, cwd)
    vim.cmd("write")
    vim.cmd("botright 12split")
    local buf = vim.api.nvim_get_current_buf()
    vim.fn.termopen(command, {
        cwd = cwd,
        on_exit = function(_, code)
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.notify(
                        code == 0 and "Программа завершилась успешно" or ("Код завершения: " .. code),
                        code == 0 and vim.log.levels.INFO or vim.log.levels.WARN,
                        { title = "Code Runner" }
                    )
                end
            end)
        end,
    })
    vim.cmd("startinsert")
end

local function run_current_file()
    local file = vim.fn.expand("%:p")
    local ft = vim.bo.filetype
    if file == "" or vim.bo.buftype ~= "" then
        vim.notify("Сначала открой обычный файл с кодом.", vim.log.levels.WARN)
        return
    end

    local root = project_root(file)
    local quoted_file = vim.fn.shellescape(file)
    local command

    if ft == "python" then
        if not executable("python3") then return end
        command = "python3 -u " .. quoted_file
    elseif ft == "lua" then
        if not executable("lua") then return end
        command = "lua " .. quoted_file
    elseif ft == "c" then
        if not executable("gcc") then return end
        local output = vim.fn.shellescape(root .. "/.nvim-run-" .. vim.fn.expand("%:t:r"))
        command = "gcc -std=c17 -Wall -Wextra -g " .. quoted_file ..
            " -o " .. output .. " && " .. output
    elseif ft == "cpp" or ft == "cuda" then
        if not executable("g++") then return end
        local output = vim.fn.shellescape(root .. "/.nvim-run-" .. vim.fn.expand("%:t:r"))
        command = "g++ -std=c++20 -Wall -Wextra -g " .. quoted_file ..
            " -o " .. output .. " && " .. output
    elseif ft == "kotlin" then
        if not executable("kotlinc") then return end
        if not executable("java") then return end
        local jar = vim.fn.shellescape(root .. "/.nvim-run-" .. vim.fn.expand("%:t:r") .. ".jar")
        command = "kotlinc " .. quoted_file .. " -include-runtime -d " .. jar ..
            " && java -jar " .. jar
    elseif ft == "sh" or ft == "bash" then
        if not executable("bash") then return end
        command = "bash " .. quoted_file
    elseif ft == "java" then
        if not executable("javac") or not executable("java") then return end
        command = "cd " .. vim.fn.shellescape(vim.fn.expand("%:p:h")) ..
            " && javac " .. vim.fn.shellescape(vim.fn.expand("%:t")) ..
            " && java " .. vim.fn.shellescape(vim.fn.expand("%:t:r"))
    else
        vim.notify("Для filetype '" .. ft .. "' запуск не настроен.", vim.log.levels.WARN, { title = "Code Runner" })
        return
    end

    open_run_terminal(command, root)
end

vim.api.nvim_create_user_command("RunCode", run_current_file, { desc = "Скомпилировать и запустить текущий файл" })
vim.keymap.set("n", "<F9>", run_current_file, { desc = "Запустить текущий файл" })
vim.keymap.set("n", "<leader>r", run_current_file, { desc = "Запустить текущий файл" })

vim.api.nvim_create_user_command("ProjectRoot", function()
    local root = project_root(vim.fn.expand("%:p"))
    vim.notify(root, vim.log.levels.INFO, { title = "Корень проекта" })
end, { desc = "Показать корень проекта" })

-- Удобная навигация по LSP и диагностике.
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Перейти к определению" })
vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Перейти к объявлению" })
vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Найти использования" })
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Найти реализацию" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Документация символа" })
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Переименовать символ" })
vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Диагностика строки" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Предыдущая ошибка" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Следующая ошибка" })
vim.keymap.set("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "Ошибки в quickfix" })

-- Дополнительные полезные команды.
vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Убрать подсветку поиска" })
vim.keymap.set("n", "<leader>.", "<cmd>Explore<cr>", { desc = "Встроенный файловый менеджер" })
vim.keymap.set("n", "<leader>=", "<C-w>=", { desc = "Выровнять окна" })
vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "Вертикальное разделение" })
vim.keymap.set("n", "<leader>sh", "<cmd>split<cr>", { desc = "Горизонтальное разделение" })
vim.keymap.set("n", "<leader>bd", "<cmd>%bd|e#|bd#<cr>", { desc = "Закрыть остальные буферы" })

-- Качество жизни: меньше случайных swap-файлов в проектах, но undo сохраняется между сессиями.
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }
opt.splitbelow = true
opt.splitright = true
opt.confirm = true

-- Сохраняем undo-историю в стандартной директории Neovim.
local undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir, "p")
opt.undodir = undo_dir
