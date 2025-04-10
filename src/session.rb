module Foobara
  class McpConnector < CommandConnector
    class Session
      attr_accessor :initialized_with

      def initialize(initialized_with)
        self.initialized_with = initialized_with
      end
    end
  end
end
