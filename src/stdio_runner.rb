module Foobara
  class McpConnector < CommandConnector
    class StdioRunner
      attr_accessor :mcp_connector, :last_unexpected_error

      def initialize(mcp_connector)
        self.mcp_connector = mcp_connector
      end

      def run(io_in: $stdin, io_out: $stdout, io_err: $stderr)
        io_in.each_line do |request|
          response = mcp_connector.run(request)

          if response
            io_out.puts response
            io_out.flush
          end
        rescue => e
          # simplecov:disable
          self.last_unexpected_error = e
          io_err.puts e.message
          io_err.puts e.backtrace
          io_err.flush
          # simplecov:enable
        end
      end
    end
  end
end
