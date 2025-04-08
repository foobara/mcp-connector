#!/usr/bin/env ruby

require "foobara/jsonrpc_connector"

module SomeOrg
  foobara_organization!

  module Math
    foobara_domain!

    class ComputeExponent < Foobara::Command
      inputs do
        base :integer, :required
        exponent :integer, :required
      end

      result :integer

      def execute
        calculate_exponent

        calculation
      end

      attr_accessor :calculation

      def calculate_exponent
        self.calculation = base**exponent
      end
    end
  end
end

connector = Foobara::JsonrpcConnector.new
connector.connect(SomeOrg)

puts connector.run('[
  {"jsonrpc": "2.0", "method": "SomeOrg::Math::ComputeExponent", "params": {"base": 2, "exponent": 3}, "id": 10},
  {"jsonrpc": "2.0", "method": "SomeOrg::Math::ComputeExponent", "params": {"base": 2, "exponent": 3}},
  {"jsonrpc": "2.0", "method": "SomeOrg::Math::ComputeExponent", "params": {"base": 2, "exponent": 3}, "id": 20}
]')
