return function()
  local log = require("doom.extras.logging")
  local utils = require("doom.utils")
  local nvim_lsp = require("lspconfig")
  local lua_lsp = require("lua-dev").setup({
    lspconfig = {
      settings = {
        Lua = {
          workspace = {
            preloadFileSize = 200,
          },
        },
      },
    },
  })

  local lspinstall = require("lspinstall")
  lspinstall.setup()

  -- Load langs from doomrc and install servers with +lsp
  local function install_servers()
    local installed_servers = lspinstall.installed_servers()
    local available_servers = lspinstall.available_servers()

    local doomrc = require("doom.core.config.doomrc").load_doomrc()
    local langs = doomrc.langs

    for _, lang in ipairs(langs) do
      local lang_str = lang
      lang = lang:gsub("%s+%+lsp", ""):gsub("%s+%+debug", "")

      -- If the +lsp flag exists and the language server is not installed yet
      if lang_str:find("%+lsp") and (not utils.has_value(installed_servers, lang)) then
        -- Try to install the server only if there is a server available for
        -- the language, oterwise raise a warning
        if utils.has_value(available_servers, lang) then
          lspinstall.install_server(lang)
        else
          log.warn(
            "The language " .. lang .. ' does not have a server, please remove the "+lsp" flag'
          )
        end
      end
    end
  end

  install_servers()

  local on_attach = function(client, bufnr)
    -- format on save
    if client.resolved_capabilities.document_formatting then
      vim.api.nvim_command [[augroup Format]]
      vim.api.nvim_command [[autocmd! * <buffer>]]
      vim.api.nvim_command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
      vim.api.nvim_command [[augroup END]] end
  end

  -- https://github.com/kabouzeid/nvim-lspinstall#advanced-configuration-recommended
  local function setup_servers()
    -- Provide the missing :LspInstall
    local servers = require("lspinstall").installed_servers()
    for _, server in pairs(servers) do
      -- Configure sumneko for neovim lua development
      if server == "lua" then
        nvim_lsp.lua.setup(lua_lsp)
      elseif server == "elixirls" then
        nvim_lsp.elixirls.setup {
          on_attach = on_attach,
          flags = {
            debounce_text_changes = 150,
          },
          settings = {
            elixirLS = {
              -- I choose to disable dialyzer for personal reasons, but
              -- I would suggest you also disable it unless you are well
              -- aquainted with dialzyer and know how to use it.
              dialyzerEnabled = false,
              -- I also choose to turn off the auto dep fetching feature.
              -- It often get's into a weird state that requires deleting
              -- the .elixir_ls directory and restarting your editor.
              fetchDeps = false
            }
          }
        }
      else
        -- Use default settings for all the other language servers
        nvim_lsp[server].setup({
          on_attach = on_attach
        })
      end
    end
  end

  setup_servers()

  -- Automatically reload after `:LspInstall <server>` so we don't have to restart neovim
  require("lspinstall").post_install_hook = function()
    setup_servers() -- reload installed servers
    vim.cmd("bufdo e") -- this triggers the FileType autocmd that starts the server
  end
end
