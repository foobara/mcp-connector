# Foobara::McpConnector

Exposes Foobara commands according to the Model Context Protocol specification

## Installation

Typical stuff: add `gem "foobara-mcp-connector` to your Gemfile or .gemspec file. Or even just
`gem install foobara-mcp-connector` if just playing with it directly in scripts.

## Usage

You can find examples in `examples/`

Let's create a simple Foobara command:

```ruby
class BuildSuperDuperSecret < Foobara::Command
  inputs do
    seed :integer, :required
  end
  result :integer

  def execute
    seed * seed * seed
  end
end
```

This just cubes the integer we pass to it. You can run it with `BuildSuperDuperSecret.run!(seed: 3)` which
would give `27`. See the foobara gem for more info about Foobara commands.

Now, let's connect it to an McpConnector:

```ruby
require "foobara/mcp_connector"

mcp_connector = Foobara::McpConnector.new
mcp_connector.connect(BuildSuperDuperSecret)
```

And we can start a stdio server like so:

```ruby
mcp_connector.run_stdio_server
```

Putting it all together in a single script called simple-mcp-server-example we get:

```ruby
#!/usr/bin/env ruby

require "foobara/mcp_connector"

class BuildSuperDuperSecret < Foobara::Command
  inputs do
    seed :integer, :required
  end
  result :integer

  def execute
    seed * seed * seed
  end
end

mcp_connector = Foobara::McpConnector.new
mcp_connector.connect(BuildSuperDuperSecret)
mcp_connector.run_stdio_server
```

We can now add it to programs that can consume MCP servers. For example, with claude code, we can
tell claude code about it by running ```claude mcp add``` and following the instructions or we
can create a .mcp.json file like this:

```json
{
  "mcpServers": {
    "mcp-test": {
      "type": "stdio",
      "command": "simple-mcp-server-example",
      "args": [],
      "env": {}
    }
  }
}
```

You need to set `"command"` to the path of your script.

Now when we run claude, we can ask it a question that would result in it running our command:

```
$ claude
> Hi! Could you please build me a super duper secret using a seed of 5?
● mcp-test:BuildSuperDuperSecret (MCP)(seed: 5)…
  ⎿  125
● 125
> Thanks!
● You're welcome!
╭───────────────────────────────────────────────────────────────────────╮
│ >                                                                     │
╰───────────────────────────────────────────────────────────────────────╯
```

Please see the examples/ directory for more examples

## Contributing

Bug reports and pull requests are welcome on GitHub
at https://github.com/foobara/mcp-connector

## License

This project is licensed under the MPL-2.0 license. Please see LICENSE.txt for more info.
