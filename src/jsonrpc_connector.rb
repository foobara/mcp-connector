module Foobara
  class JsonrpcConnector < CommandConnector
    def initialize(*, **, &)
      default_serializers = [Foobara::CommandConnectors::Serializers::JsonSerializer]

      super(*, default_serializers:, **, &)
    end

    def build_response(request)
      super.body
    end

    def set_response_body(response)
      request = response.request
      outcome = request.outcome

      body = { jsonrpc: "2.0", id: request.request_id }

      response.body = if outcome.success?
                        body.merge(result: outcome.result)
                      else
                        error = {
                          message: outcome.error_sentence,
                          data: outcome.errors_hash,
                          code: response.status
                        }

                        body.merge(error:)
                      end
    end

    def set_response_status(response)
      request = response.request

      response.status = if request.error
                          -32_700
                        elsif request.success?
                          0
                        else
                          errors = request.error_collection.error_array
                          error = errors.first

                          # Going to steal some http codes to be less confusing
                          case error
                          when CommandConnector::NotFoundError
                            -32_601
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
                            # :nocov:
                            -32_603
                            # :nocov:
                          when Foobara::DataError
                            -32_602
                          end || -32_600
                        end
    end
  end
end
