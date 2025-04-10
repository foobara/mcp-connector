require_relative "../request"

module Foobara
  class McpConnector < CommandConnector
    module Commands
      class Initialize < Command
        inputs do
          request Request, :required
          # TODO: Implement some kind of camelize serializer/result transformer/response mutator
          protocolVersion :string, :required
          # TODO: support :attributes without extending it which should work but I think doesn't
          # so using :duck for now
          capabilities :duck, :required
          clientInfo :required do
            name :string, :required
            version :string, :required
          end
        end

        result do
          protocolVersion :string, :required
          capabilities :required do
            # experimental :attributes, :allow_nil
            # logging :attributes, :allow_nil
            # completions :attributes, :allow_nil
            prompts do
              listChanged :boolean
            end
            resources do
              subscribe :boolean
              listChanged :boolean
            end
            tools do
              listChanged :boolean
            end
          end
          serverInfo :required do
            name :string, :required
            version :string, :required
          end
          instructions :string, :allow_nil
        end

        def execute
          create_session
          notify_connector_of_session

          build_result
        end

        attr_accessor :session

        def create_session
          self.session = Session.new(inputs.except(:request))
        end

        def notify_connector_of_session
          command_connector.session_created(session)
        end

        def command_connector
          request.command_connector
        end

        # Just hard-coding a bunch of these values to a limited set of abilities for now
        def build_result
          {
            protocolVersion: "2025-03-26",
            capabilities: {
              # We only support tools for now and don't yet support updating lists of tools
              tools: { listChanged: false }
            },
            serverInfo: {
              name: command_connector.server_name,
              version: command_connector.server_version
            },
            instructions: command_connector.instructions
          }
        end
      end
    end
  end
end
