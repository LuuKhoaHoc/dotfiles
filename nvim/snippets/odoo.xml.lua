local ls = require "luasnip"
local s = ls.snippet

return {
  s("odoo_template", {
    t { "", "<odoo>", "  <data>" },
    i(0, "<!-- Your XML content here -->"),
    t { "", "  </data>", "</odoo>" },
  }),
}
