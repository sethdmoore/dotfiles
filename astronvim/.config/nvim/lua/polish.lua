-- This will run last in the setup process and is a good place to configure
-- things like custom filetypes. This just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Set up custom filetypes
-- vim.filetype.add {
--   extension = {
--     foo = "fooscript",
--   },
--   filename = {
--     ["Foofile"] = "fooscript",
--   },
--   pattern = {
--     ["~/%.config/foo/.*"] = "fooscript",
--   },
-- }
vim.filetype.add {
  extension = {
    jenkinsfile = "groovy"
  },
}
-- 2025-01-02 workaround for terraformls not detecting bare terraform files
vim.filetype.add {
  extension = {
    tf = "terraform"
  }
}
