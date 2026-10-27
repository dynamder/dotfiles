-- 主题（colorscheme）配置
--
-- Catppuccin 系列：catppuccin-latte / catppuccin-frappe / catppuccin-macchiato / catppuccin-mocha
-- Rosé Pine 系列：rose-pine / rose-pine-moon / rose-pine-dawn
--
-- 切换主题：<leader>uC（LazyVim 自带的选择器，支持实时预览）
-- 修改默认主题：改下面 "LazyVim/LazyVim" 里的 opts.colorscheme

return {
  -- 让 LazyVim 在启动时加载指定主题；换成 "rose-pine" 等即可换默认主题
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },

  -- Catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha", -- mocha(最深) | macchiato | frappe | latte(浅色)
      -- 跟随 `:set background=dark/light` 自动换变体
      background = { light = "latte", dark = "mocha" },
      transparent_background = false, -- 想透明背景就改成 true
      term_colors = true,
      styles = {
        comments = { "italic" },
        keywords = { "italic" },
      },
      lsp_styles = {
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        mini = true,
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        snacks = true,
        telescope = true,
        treesitter_context = true,
        which_key = true,
      },
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.special.bufferline").get_theme()
          end
        end,
      },
    },
  },

  -- Rosé Pine
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      -- auto: 跟随 `background`（dark 用 dark_variant，light 用 dawn）
      -- 也可以写死成 main / moon / dawn
      variant = "auto",
      dark_variant = "main",
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      enable = {
        terminal = true,
        legacy_highlights = true, -- 兼容旧版本 Neovim
        migrations = true, -- 自动处理废弃选项
      },
      styles = {
        bold = true,
        italic = true,
        transparency = false, -- 想透明背景就改成 true
      },
    },
  },
}
