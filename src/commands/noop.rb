require_relative "../request"

module Foobara
  class McpConnector < CommandConnector
    module Commands
      class Noop < Command
        inputs do
          request :duck, :allow_nil
        end

        def execute
        end
      end
    end
  end
end
