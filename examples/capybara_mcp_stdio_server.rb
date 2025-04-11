#!/usr/bin/env ruby

require "foobara/mcp_connector"
require_relative "create_initial_capybaras"

mcp_connector = Foobara::McpConnector.new(
  default_serializers: Foobara::CommandConnectors::Serializers::AtomicSerializer
)
mcp_connector.connect(FindAllCapybaras)

mcp_connector.run_stdio_server

# rubocop:disable Layout/LineLength
#
# some example requests:
# initialize
# {"method":"initialize","params":{"protocolVersion":"2025-03-26","clientInfo":{"name":"Some Client","version":"1.0.0"},"capabilities":{}},"id":1,"jsonrpc":"2.0"}
#
# list tools
# {"method":"tools/list","jsonrpc":"2.0","id":2}
#
# invoke tool
# {"method":"tools/call","params":{"name":"FindAllCapybaras","arguments":{}},"jsonrpc":"2.0","id":3}
#
# rubocop:enable Layout/LineLength
