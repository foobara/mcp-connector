# Foobara::JsonrpcConnector

Provides a way to invoke Foobara commands over Jsonrpc version 2.0.

This does not provide a transport mechanism as jsonrpc itself is transport-agnostic.

Implements the full spec including batched requests, errors, and "notifications" as defined by the spec located here:
https://www.jsonrpc.org/specification

## Installation

Typical stuff: add `gem "foobara-jsonrpc-connector` to your Gemfile or .gemspec file. Or even just
`gem install foobara-jsonrpc-connector` if just playing with it directly in scripts.

## Usage

Here's an example of exposing a ComputeExponent command via jsonrpc:

```ruby
#!/usr/bin/env ruby

require "foobara/jsonrpc_connector"

class ComputeExponent < Foobara::Command
  inputs do
    base :integer, :required
    exponent :integer, :required
  end

  result :integer

  def execute
    calculate_exponent

    calculation
  end

  attr_accessor :calculation

  def calculate_exponent
    self.calculation = base ** exponent
  end
end

connector = Foobara::JsonrpcConnector.new
connector.connect(ComputeExponent)

puts connector.run('{"jsonrpc": "2.0",
                     "method": "ComputeExponent",
                     "params": {"base": 2, "exponent": 3},
                     "id": 100}')
```

This script outputs:

```
$ ./compute_exponent.rb 
{"jsonrpc":"2.0","id":100,"result":8}
```

Here's an example of a batch of commands:

```ruby
puts connector.run('[
  {"jsonrpc": "2.0", "method": "SomeOrg::Math::ComputeExponent", "params": {"base": 2, "exponent": 3}, "id": 10},
  {"jsonrpc": "2.0", "method": "SomeOrg::Math::ComputeExponent", "params": {"base": 2, "exponent": 3}},
  {"jsonrpc": "2.0", "method": "SomeOrg::Math::ComputeExponent", "params": {"base": 2, "exponent": 3}, "id": 20}
]')
```

Which outputs:

```
./compute_exponent_batch.rb 
[{"jsonrpc":"2.0","id":10,"result":8},{"jsonrpc":"2.0","id":20,"result":8}]
```

Note that we don't get a result for the request in the batch without an ID. This is a "notification" according to the
spec and is to have no response.

Jsonrpc errors are also implemented. Here's an example:

```ruby
puts connector.run('{"jsonrpc": "2.0",
                     "method": "ComputeExponent",
                     "params": {"exponent": 3},
                     "id": 100}')
```

Which outputs:

```
$ ./compute_exponent_error.rb 
{"jsonrpc":"2.0","id":100,"error":
  {"code":-32602,
   "message":"Missing required attribute base",
   "data":{"data.base.missing_required_attribute":{
     "key":"data.base.missing_required_attribute",
     "path":["base"],
     "runtime_path":[],
     "category":"data",
     "symbol":"missing_required_attribute",
     "message":"Missing required attribute base",
     "context":{"attribute_name":"base"},
     "is_fatal":true}
   }
  }
}
```

## Contributing

Bug reports and pull requests are welcome on GitHub
at https://github.com/foobara/jsonrpc-connector

## License

This project is licensed under the MPL-2.0 license. Please see LICENSE.txt for more info.
