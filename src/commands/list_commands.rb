require "foobara/json_schema_generator"
require_relative "../request"

module Foobara
  class McpConnector < CommandConnector
    module Commands
      class ListCommands < CommandConnector::Commands::ListCommands
        inputs do
          request Request, :required
        end

        result do
          tools :array do
            name :string, :required
            description :string, :allow_nil
            # TODO: make sure attributes can be used as a type without extension
            inputSchema :duck, :required
            # TODO: implement annotations!!
          end
        end

        def execute
          build_list
          build_tools_array

          tools_list
        end

        attr_accessor :tools_array

        def build_tools_array
          self.tools_array = list.map do |command|
            inputs_type = command.inputs_type ||
                          Domain.current.foobara_type_from_declaration({})

            h = {
              name: command.full_command_name,
              inputSchema: Foobara::JsonSchemaGenerator.to_json_schema_structure(inputs_type)
            }

            description = command.description

            if description
              h[:description] = description
            end

            h
          end
        end

        def tools_list
          { tools: tools_array }
        end
      end
    end
  end
end
