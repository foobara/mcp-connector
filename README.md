# Foobara::McpConnector

Exposes Foobara commands according to the Model Context Protocol (MCP) specification

<!-- TOC -->
* [Foobara::McpConnector](#foobaramcpconnector)
  * [Installation](#installation)
  * [Usage](#usage)
    * [Super basic example](#super-basic-example)
    * [An example with entities](#an-example-with-entities)
    * [A destructive example](#a-destructive-example)
    * [Moar examples](#moar-examples)
  * [Contributing](#contributing)
  * [License](#license)
<!-- TOC -->

## Installation

Typical stuff: add `gem "foobara-mcp-connector` to your Gemfile or .gemspec file. Or even just
`gem install foobara-mcp-connector` if just playing with it directly in scripts.

## Usage

You can find examples in `examples/`

### Super basic example

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
```

### An example with entities

Let's say we have a model (see examples/capybaras.rb):

```ruby
class Capybara < Foobara::Entity
  attributes do
    id :integer
    name :string, :required
    year_of_birth :integer, :required
  end

  primary_key :id
end
```

As well as some commands like `FindAllCapybaras`, `CreateCapybara`, and `UpdateCapybara`
(see examples/capybara_commands.rb)

We can write an MCP connector to expose those commands so we can ask questions that require
running those commands to answer:

```ruby
require "foobara/mcp_connector"
require_relative "capybara_commands"

CreateCapybara.run!(name: "Fumiko", year_of_birth: 2020)
CreateCapybara.run!(name: "Barbara", year_of_birth: 2019)
CreateCapybara.run!(name: "Basil", year_of_birth: 2021)

mcp_connector = Foobara::McpConnector.new
mcp_connector.connect(FindAllCapybaras)

mcp_connector.run_stdio_server
```

We can now ask a tool like claude a relevant question:

```
$ claude
> Which Capybara is the oldest?
● mcp-test:FindAllCapybaras (MCP)()…
  ⎿  [
       {
         "name": "Fumiko",
         "year_of_birth": 2020,
         "id": 1

     … +7 lines (ctrl+r to expand)

         "name": "Basil",
         "year_of_birth": 2021,
         "id": 3
       }
     ]

● Barbara (born in 2019)
> Thanks!
● You're welcome!
```

### A destructive example

Let's say we would like to mutate data. Let's pretend we've accidentally entered a year-of-birth
in a 2-digit format where a 4-digit format was expected. Let's do that and also expose our UpdateCapybara
command:

```ruby
# We will simulate a year accidentally being entered with a 2-digit format where a 4-digit format was expected
UpdateCapybara.run!(id: barbara.id, year_of_birth: 19)

mcp_connector = Foobara::McpConnector.new

mcp_connector.connect(FindAllCapybaras)
mcp_connector.connect(UpdateCapybara)

mcp_connector.run_stdio_server
```

Now we can ask a tool like claude to find and fix our data:

```
$ claude
> Hi! There's a Capybara whose birth year was entered incorrectly. Can you find which one
  and fix it? Thanks!
● I'll help find and fix the capybara with the incorrect birth year. Let me search for the
  capybaras first.
● mcp-test:FindAllCapybaras (MCP)()…
  ⎿  [
       {
         "name": "Fumiko",
         "year_of_birth": 2020,
         "id": 1

     … +7 lines (ctrl+r to expand)

         "name": "Basil",
         "year_of_birth": 2021,
         "id": 3
       }
     ]
● It looks like Barbara (id 2) has an incorrect birth year of 19, which is too low. Let me
  fix that to 2019.
● mcp-test:UpdateCapybara (MCP)(id: 2, year_of_birth: 2019)…
  ⎿  {
       "name": "Barbara",
       "year_of_birth": 2019,
       "id": 2
     }
● Fixed! Barbara's birth year has been updated from 19 to 2019.
> Great! Thanks!
● You're welcome!
```

### Moar examples

Please see the examples/ directory for executable scripts of these examples.

## Contributing

Bug reports and pull requests are welcome on GitHub
at https://github.com/foobara/mcp-connector

Feel free to reach out if you'd like help with this gem or if you'd like to help with this gem!

## License

This project is licensed under the MPL-2.0 license. Please see LICENSE.txt for more info.
