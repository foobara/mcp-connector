module Foobara
  class JsonrpcConnector < CommandConnector
    class Request < CommandConnector::Request
      class InvalidJsonrpcVersionError < StandardError; end
      class InvalidJsonError < StandardError; end

      attr_accessor :raw_request_json, :parsed_request_body, :request_id, :batch, :is_batch_child, :response

      def initialize(request_json, *, serializers: nil, is_batch_child: false, **, &)
        self.is_batch_child = is_batch_child
        self.raw_request_json = request_json

        set_parsed_json

        unless error
          if batch?
            self.batch = parsed_request_body.map do |request|
              self.class.new(request, *, is_batch_child: true, **, &)
            end
          else
            self.request_id = parsed_request_body["id"]

            verify_jsonrpc_version

            unless error
              full_command_name = parsed_request_body["method"]
              inputs = parsed_request_body["params"]
            end
          end
        end

        if batch? || error
          full_command_name = inputs = nil
        end

        super(*, full_command_name:, inputs:, action: "run", serializers:, **, &)
      end

      def set_parsed_json
        self.parsed_request_body = if batch_child?
                                     raw_request_json
                                   else
                                     begin
                                       JSON.parse(raw_request_json)
                                     rescue => e
                                       self.error = InvalidJsonError.new("Could not parse request: #{e.message}")
                                       error.set_backtrace(caller)
                                       nil
                                     end
                                   end
      end

      def verify_jsonrpc_version
        if parsed_request_body["jsonrpc"] != "2.0"
          self.error = InvalidJsonrpcVersionError.new("Unsupported jsonrpc version: #{parsed_request_body["jsonrpc"]}")
          error.set_backtrace(caller)
        end
      end

      def batch_child?
        is_batch_child
      end

      def notification?
        if parsed_request_body
          if batch?
            batch.all?(&:notification?)
          else
            !parsed_request_body.key?("id")
          end
        end
      end

      def batch?
        parsed_request_body.is_a?(::Array)
      end
    end
  end
end
