#!/usr/bin/env ruby

require "foobara/jsonrpc_connector"

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

connector = Foobara::JsonrpcConnector.new
connector.connect(ComputeExponent)

puts connector.run('{"jsonrpc": "2.0",
                     "method": "ComputeExponent",
                     "params": {"base": 2, "exponent": 3},
                     "id": 100}')
