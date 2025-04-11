module Foobara
  # TODO: somehow give a way to specify an association depth when registering commands?
  class McpConnector < CommandConnector
    attr_accessor :current_session, :server_name, :server_version, :instructions

    def initialize(
      *,
      capture_unknown_error: true,
      server_name: default_server_name,
      server_version: default_server_version,
      instructions: default_instructions,
      **,
      &
    )
      self.server_name = server_name
      self.server_version = server_version
      self.instructions = instructions

      super(*, capture_unknown_error:, **, &)
    end

    def default_server_name
      "Foobara MCP Command connector"
    end

    def default_server_version
      require_relative "../version"

      Foobara::McpConnectorVersion::VERSION
    end

    def default_instructions
      "This is a Foobara MCP command connector which exposes Foobara commands to you as tools that you can invoke."
    end

    # TODO: how to stream content out instead of buffering it up?
    def run(*args, **opts, &)
      super.body
    end

    def run_stdio_server(io_in: $stdin, io_out: $stdout, io_err: $stderr)
      StdioRunner.new(self).run(io_in: io_in, io_out: io_out, io_err: io_err)
    end

    def request_to_command(request)
      action = request.action

      return if request.error?

      case action
      when "initialize"
        command_class = find_builtin_command_class("Initialize")
      when "notifications/initialized", "notifications/cancelled", "notifications/progress",
        "notifications/roots/list_changed"
        command_class = find_builtin_command_class("Noop")
      else
        return super
      end

      full_command_name = command_class.full_command_name
      inputs = (request.params || {}).merge(request:)

      transformed_command_class = transformed_command_from_name(full_command_name) ||
                                  transform_command_class(command_class)

      transformed_command_class.new(inputs)
    rescue CommandConnector::NoCommandFoundError => e
      request.error = e
      nil
    end

    # TODO: figure out how to support multiple sessions
    def session_created(session)
      self.current_session = session
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

    def build_request(*, **, &)
      request = super

      # We add a serializer to the top-level request but not to the children of a batch requests

      request.serializers = [*request.serializers, json_serializer]

      request
    end

    def json_serializer
      @json_serializer ||= Foobara::CommandConnectors::Serializers::JsonSerializer.new
    end

    # TODO: feels awkward needing to override this for such basic/typical behavior
    # TODO: fix this interface/pattern higher-up
    def serialize_response_body(response)
      super

      request = response.request

      unless request.notification?
        # TODO: total hack, clean this up somehow...
        if request.tool_call? && request.success?
          result = response.body[:result]

          result = json_serializer.serialize(result)

          response.body[:result] = { content: [{ type: "text", text: result }] }
        end

        if request.serializer
          response.body = request.serializer.process_value!(response.body)
        end
      end
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
  end
end
