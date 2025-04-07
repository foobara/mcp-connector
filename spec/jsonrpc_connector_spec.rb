RSpec.describe Foobara::JsonrpcConnector do
  context "with a super basic command connected" do
    let(:command_connector) { described_class.new }
    let(:inputs) do
      { base: 2, exponent: 3 }
    end
    let(:jsonrpc_inputs) do
      { jsonrpc: "2.0", method: command_class.full_command_name, params: inputs, id: request_id }
    end
    let(:request_id) { 100 }
    let(:input_json) do
      JSON.generate(jsonrpc_inputs)
    end

    let(:command_class) do
      stub_module("SomeOrg") { foobara_organization! }
      stub_module("SomeOrg::SomeDomain") { foobara_domain! }
      stub_class "SomeOrg::SomeDomain::ComputeExponent", Foobara::Command do
        inputs do
          base :integer, :required
          exponent :integer, :required
        end

        result :integer

        def execute
          base**exponent
        end
      end
    end

    let(:response) do
      command_connector.run(input_json)
    end
    let(:response_body) do
      JSON.parse(response)
    end

    before do
      command_connector.connect(command_class)
    end

    it "executes the command" do
      expect(response_body).to eq("jsonrpc" => "2.0", "result" => 8, "id" => request_id)
    end
  end
end
