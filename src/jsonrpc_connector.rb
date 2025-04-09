module Foobara
  class McpConnector < CommandConnector
    def initialize(*, capture_unknown_error: true, **, &)
      super
    end

    # TODO: maybe introduce a Runner interface?
    def run(*args, **opts, &)
      super.body
    end

    def run_request(request)
      if request.batch? && !request.error
        request.batch.each do |batch_request|
          super(batch_request)
        end

        build_response(request)
      else
        super
      end
    end

    # We add a serializer to the top-level request but not to the children of a batch requests
    def build_request(*, serializers: json_serializer, **, &)
      super(*, **, serializers:, &)
    end

    def json_serializer
      @json_serializer ||= Foobara::CommandConnectors::Serializers::JsonSerializer.new
    end

    # TODO: Should this be implemented on response object instead??
    def set_response_body(response)
      request = response.request

      return if request.notification?

      response.body = if request.valid_batch?
                        request.batch.map do |batched_request|
                          batched_request.response.body
                        end.compact
                      else
                        body = { jsonrpc: "2.0", id: request.request_id }

                        if request.error
                          body.merge(error: { message: request.error.message, code: response.status })
                        else
                          outcome = request.outcome

                          if outcome.success?
                            body.merge(result: outcome.result)
                          else
                            body.merge(error: {
                                         message: outcome.errors_sentence,
                                         data: outcome.errors_hash,
                                         code: response.status
                                       })
                          end
                        end
                      end

      if request.serializer
        response.body = request.serializer.process_value!(response.body)
      end
    end

    def request_to_response(request)
      response = self.class::Response.new(request:)
      # TODO: push this up??
      request.response = response
      response
    end

    def set_response_status(response)
      return if response.request.valid_batch?

      request = response.request

      response.status = if request.error
                          case request.error
                          when Request::InvalidJsonrpcVersionError, Request::InvalidJsonrpcMethodError,
                            Request::InvalidJsonrpcParamsError, Request::EmptyBatchError,
                            Request::InvalidJsonrpcRequestStructureError
                            -32_600
                          when Request::InvalidJsonError
                            -32_700
                          when CommandConnector::NotFoundError
                            -32_601
                          when Request::FoobaraCommandsDoNotAcceptArraysError
                            -32_602
                          else
                            -32_603
                          end
                        elsif request.success?
                          0
                        else
                          errors = request.error_collection.error_array
                          error = errors.first

                          # Going to steal some http codes to be less confusing
                          case error
                          when Foobara::Entity::NotFoundError
                            # TODO: we should not be coupled to Entities here...
                            # :nocov:
                            404
                            # :nocov:
                          when CommandConnector::UnauthenticatedError
                            # :nocov:
                            401
                            # :nocov:
                          when CommandConnector::NotAllowedError
                            # :nocov:
                            403
                            # :nocov:
                          when CommandConnector::UnknownError
                            -32_603
                          when Foobara::DataError
                            -32_602
                          end || -32_600
                        end
    end

    def request_to_command(request)
      super
    rescue CommandConnector::NoCommandFoundError => e
      request.error = e
      nil
    end
  end
end
