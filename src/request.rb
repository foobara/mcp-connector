require_relative "jsonrpc_request"

module Foobara
  class McpConnector < CommandConnector
    class Request < JsonrpcRequest
      class FoobaraCommandsDoNotAcceptArraysError < StandardError; end
      class MethodNotYetSupportedError < StandardError; end

      def full_command_name
        return if error || batch?

        return @full_command_name if defined?(@full_command_name)

        @full_command_name = parsed_request_body&.[]("params")&.[]("name")
      end

      def inputs
        return if error || batch?

        return @inputs if defined?(@inputs)

        @inputs = parsed_request_body&.[]("params")&.[]("arguments") || {}

        unless inputs.is_a?(::Hash)
          self.error = if inputs.is_a?(::Array)
                         FoobaraCommandsDoNotAcceptArraysError.new(
                           "Foobara commands do not accept arrays as inputs"
                         )
                       else
                         InvalidJsonrpcParamsError.new(
                           "Invalid MCP arguments structure. Expected a hash got a #{inputs.class}"
                         )
                       end

          error.set_backtrace(caller)
        end

        inputs
      end

      def tool_call?
        !batch? && method == "tools/call"
      end

      def success?
        !error && super
      end

      def action
        case method
        when "tools/call"
          "run"
        when "tools/list"
          "list"
        when "initialize", "ping",
          "notifications/initialized", "notifications/cancelled", "notifications/progress",
          "notifications/roots/list_changed"
          method
        when "completion/complete", "logging/setLevel", "prompts/get", "prompts/list",
          "resources/list", "resources/read", "resources/subscribe", "resources/unsubscribe"
          raise MethodNotYetSupportedError, "#{method} not yet supported!"
        else
          self.error = InvalidJsonrpcMethodError.new("Unknown method: #{method}")
          error.set_backtrace(caller)
          nil
        end
      end
    end
  end
end
