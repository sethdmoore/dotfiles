-- 2026-05-09: disable polish, see if we miss it.
if true then return end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- 2026-05-09: these were disabled
-- vim.filetype.add {
--   extension = {
--     jenkinsfile = "groovy"
--   },
-- }
-- -- 2025-01-02 workaround for terraformls not detecting bare terraform files
-- vim.filetype.add {
--   extension = {
--     tf = "terraform"
--   }
-- }
