module Foobara
  class JsonrpcConnector < CommandConnector
    class Request < CommandConnector::Request
      attr_accessor :raw_request_json, :parsed_request_body, :request_id

      def initialize(request_json)
        self.raw_request_json = request_json
        self.parsed_request_body = JSON.parse(request_json)

        validate_jsonrpc_version!

        self.request_id = parsed_request_body["id"]

        full_command_name = parsed_request_body["method"]
        inputs = parsed_request_body["params"]

        super(full_command_name:, inputs:, action: "run")
      end

      def validate_jsonrpc_version!
        # TODO: provide specification-defined error codes for situations that apply
        unless parsed_request_body["jsonrpc"] == "2.0"
          raise "Unsupported JSONRPC version #{parsed_request_body["jsonrpc"]}"
        end
      end
    end
  end
end
