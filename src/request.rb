module Foobara
  class JsonrpcConnector < CommandConnector
    class Request < CommandConnector::Request
      class InvalidJsonrpcVersionError < StandardError; end
      class InvalidJsonError < StandardError; end

      attr_accessor :raw_request_json, :parsed_request_body, :request_id

      def initialize(request_json)
        self.raw_request_json = request_json
        self.parsed_request_body = begin
          JSON.parse(request_json)
        rescue => e
          self.error = InvalidJsonError.new("Could not parse request: #{e.message}")
          error.set_backtrace(caller)
          return
        end

        self.request_id = parsed_request_body["id"]

        unless parsed_request_body["jsonrpc"] == "2.0"
          self.error = InvalidJsonrpcVersionError.new("Unsupported jsonrpc version: #{parsed_request_body["jsonrpc"]}")
          error.set_backtrace(caller)
          return
        end

        full_command_name = parsed_request_body["method"]
        inputs = parsed_request_body["params"]

        super(full_command_name:, inputs:, action: "run")
      end

      def validate_jsonrpc_version!
      end
    end
  end
end
