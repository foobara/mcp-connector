module Foobara
  class McpConnector < CommandConnector
    # Isolating jsonrpc specific logic to this abstract class
    class JsonrpcRequest < CommandConnector::Request
      class InvalidJsonrpcVersionError < StandardError; end
      class InvalidJsonrpcMethodError < StandardError; end
      class InvalidJsonrpcParamsError < StandardError; end
      class InvalidJsonrpcRequestStructureError < StandardError; end
      class EmptyBatchError < StandardError; end
      class InvalidJsonError < StandardError; end

      attr_accessor :raw_request_json, :parsed_request_body, :request_id, :batch, :is_batch_child

      def initialize(request_json, *, is_batch_child: false, **, &)
        self.is_batch_child = is_batch_child
        self.raw_request_json = request_json

        set_parsed_json

        unless error
          if batch?
            unless error
              self.batch = parsed_request_body.map do |request|
                self.class.new(request, *, is_batch_child: true, **, &)
              end
            end

            validate_batch_not_empty
          else
            validate_request_structure

            unless error
              self.request_id = parsed_request_body["id"]
              verify_jsonrpc_version
            end
          end
        end

        super(*, **, &)
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
        return false if response&.status == -32_600

        if parsed_request_body
          if valid_batch?
            batch.all?(&:notification?)
          else
            parsed_request_body.is_a?(::Hash) && !parsed_request_body.key?("id")
          end
        end
      end

      def batch?
        parsed_request_body.is_a?(::Array)
      end

      def valid_batch?
        batch? && batch && !batch.empty?
      end

      def validate_batch_not_empty
        if batch? && batch.empty?
          self.error = EmptyBatchError.new("An empty array/batch is not allowed")
          error.set_backtrace(caller)
        end
      end

      def validate_request_structure
        unless parsed_request_body.is_a?(::Hash)
          self.error = InvalidJsonrpcRequestStructureError.new(
            "Invalid jsonrpc request structure. Expected a hash but got #{parsed_request_body}"
          )
          error.set_backtrace(caller)
        end
      end
    end
  end
end
