{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "enum": ["setTheme", "toggleWidget", "addPackage", "mkWidget"]
    },
    "theme": {
      "type": "string",
      "enum": ["tokyo-night", "catppuccin"]
    },
    "widget": {
      "type": "string",
      "enum": ["pomodoro", "clock"]
    },
    "package": {
      "type": "string"
    }
  },
  "required": ["action"],
  "examples": [
    {
      "action": "setTheme",
      "theme": "matte-black",
      "_comment": "Sets omanix.theme = \"matte-black\" in configuration.nix"
    },
    {
      "action": "mkWidget",
      "widget": "pomodoro",
      "_comment": "Fills lib/mkWidget template for pomodoro timer"
    }
  ]
}
