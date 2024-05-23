return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>\\"] = {"<cmd>vsplit<cr>", desc = "Vertical Split"},
          ["<Leader>-"] = {"<cmd>split<cr>", desc = "Horizontal Split"},
          [";"] = {":", desc = "Command Mode"},
        }
      }
    }
  }
}
