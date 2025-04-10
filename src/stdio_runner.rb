module Foobara
  class McpConnector < CommandConnector
    class StdioRunner
      attr_accessor :mcp_connector

      def initialize(mcp_connector)
        self.mcp_connector = mcp_connector
      end

      def run(io_in: $stdin, io_out: $stdout, io_err: $stderr)
        io_in.each_line do |request|
          response = mcp_connector.run(request)
          io_out.puts response
        rescue => e
          io_err.puts e.message
          io_err.puts e.backtrace
        end
      end
    end
  end
end
