module Foobara
  class JsonrpcConnector < CommandConnector
    def initialize(*, capture_unknown_error: true, **, &)
      super
    end

    def build_response(request)
      # TODO: We should be able to just set a default serializer on the connector!!
      # But we can't because if we fail to create a command then the serializer won't be called.
      # This shows that the serializers more properly belong on the command connector and not the
      # exposed/transformed command!
      json_serializer.process_value!(super.body)
    end

    def json_serializer
      @json_serializer ||= Foobara::CommandConnectors::Serializers::JsonSerializer.new
    end

    def set_response_body(response)
      request = response.request
      body = { jsonrpc: "2.0", id: request.request_id }

      response.body = if request.error
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

    def set_response_status(response)
      request = response.request

      response.status = if request.error
                          case request.error
                          when Request::InvalidJsonrpcVersionError
                            -32_700
                          when Request::InvalidJsonError
                            -32_600
                          when CommandConnector::NotFoundError
                            -32_601
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
