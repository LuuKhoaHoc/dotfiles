local ls = require "luasnip"
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node

return {
  s("odoo_model", {
    t { "from odoo import models, fields, api", "", "class " },
    i(1, "ModelName"),
    t { "(models.Model):", '    """Description"""', "" },
    t { "    _name = '" },
    i(2, "model.name"),
    t { "'", "    _description = " },
    i(3, "Model Description"),
    t { "", "" },
    t { "    name = fields.Char(string=" },
    i(4, "Name"),
    t { ")", "    _sql_constraints = [", '        ("unique_name", "unique(name)", "Name must be unique!"),', "    ]" },
  }),
  s("odoo_view", {
    t { "", "<odoo>", "  <data>", '    <record id="view_' },
    i(1, "view_id"),
    t { '" model="' },
    i(2, "model.name"),
    t { '" view_mode="tree">', "      <field name=" },
    i(3, "field_name"),
    t { '"/>', "    </record>", "  </data>", "</odoo>" },
  }),
}
