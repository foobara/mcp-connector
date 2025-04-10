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

        unless full_command_name.is_a?(String)
          self.error = InvalidJsonrpcMethodError.new(
            "Invalid jsonrpc method. Expected a string got #{full_command_name}"
          )
          error.set_backtrace(caller)
        end

        full_command_name
      end

      def inputs
        return if error || batch?

        return @inputs if defined?(@inputs)

        @inputs = parsed_request_body&.[]("params")&.[]("arguments")

        unless inputs.is_a?(::Hash)
          self.error = if inputs.is_a?(::Array)
                         FoobaraCommandsDoNotAcceptArraysError.new(
                           "Foobara commands do not accept arrays as inputs"
                         )
                       else
                         InvalidJsonrpcParamsError.new("Invalid jsonrpc params. Expected a hash got #{inputs}")
                       end

          error.set_backtrace(caller)
        end

        inputs
      end

      def action
        case method
        when "tools/call"
          "run"
        when "tools/list"
          "list"
        when "initialize", "ping"
          method
        when "completion/complete", "logging/setLevel", "prompts/get", "prompts/list",
          "resources/list", "resources/read", "resources/subscribe", "resources/unsubscribe"
          raise MethodNotYetSupportedError, "#{method} not yet supported!"
        else
          raise "Unknown method #{method}"
        end
      end
    end
  end
end
