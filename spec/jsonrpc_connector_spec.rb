RSpec.describe Foobara::JsonrpcConnector do
  after { Foobara.reset_alls }

  context "with a super basic command connected" do
    let(:command_connector) { described_class.new(capture_unknown_error:) }
    let(:connect_command) do
      command_connector.connect(command_class)
    end
    let(:capture_unknown_error) { true }
    let(:inputs) do
      { base: 2, exponent: 3 }
    end
    let(:jsonrpc_inputs) do
      { jsonrpc: json_rpc_version, method:, params: inputs, id: request_id }
    end
    let(:method) { command_class.full_command_name }
    let(:json_rpc_version) { "2.0" }
    let(:request_id) { 100 }
    let(:input_json) do
      JSON.generate(jsonrpc_inputs)
    end

    let(:command_class) do
      stub_module("SomeOrg") { foobara_organization! }
      stub_module("SomeOrg::SomeDomain") { foobara_domain! }
      stub_class "SomeOrg::SomeDomain::ComputeExponent", Foobara::Command do
        class << self
          # Used to test notifications which the spec says should have no response
          def called_with
            @called_with ||= []
          end
        end

        inputs do
          base :integer, :required
          exponent :integer, :required
        end

        result :integer

        def execute
          self.class.called_with << inputs
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
      connect_command
    end

    it "executes the command and returns a response" do
      expect(response_body).to eq("jsonrpc" => "2.0", "result" => 8, "id" => request_id)
    end

    context "with a bad jsonrpc version" do
      let(:json_rpc_version) { "asdf" }

      it "gives an error" do
        expect(response_body).to eq(
          "jsonrpc" => "2.0",
          "error" => {
            "code" => -32_700,
            "message" => "Unsupported jsonrpc version: #{json_rpc_version}"
          },
          "id" => request_id
        )
      end
    end

    context "with invalid json" do
      let(:input_json) { "{ asdfasdfasdf" }

      it "gives an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to be_nil

        error = response_body["error"]

        expect(error.keys).to match_array(%w[code message])

        expect(error["code"]).to eq(-32_600)
        expect(error["message"]).to match(/Could not parse request: /)
      end
    end

    context "with bad inputs" do
      let(:inputs) do
        { base: 2, exponent: "asdf" }
      end

      it "gives an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to be(100)

        error = response_body["error"]

        expect(error.keys).to match_array(%w[code message data])

        expect(error["code"]).to eq(-32_602)
        expect(error["message"]).to be_a(String)
        expect(error["data"].keys).to eq(["data.exponent.cannot_cast"])
      end
    end

    context "with a bad command name" do
      let(:method) { "BadCommandName" }

      it "gives an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to be(100)

        error = response_body["error"]

        expect(error.keys).to match_array(%w[code message])
        expect(error["code"]).to eq(-32_601)
        expect(error["message"]).to be_a(String)
      end
    end

    context "when command explodes unexpectedly" do
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
            raise "kaboom!!"
          end
        end
      end

      it "gives an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to be(100)

        error = response_body["error"]

        expect(error.keys).to match_array(%w[code message])
        expect(error["code"]).to eq(-32_603)
        expect(error["message"]).to be_a(String)
      end

      context "when not capturing unknown errors by default" do
        let(:capture_unknown_error) { false }

        it "raises" do
          expect { response }.to raise_error("kaboom!!")
        end

        context "when configuring capturing unknown error when connecting" do
          let(:connect_command) do
            command_connector.connect(command_class, capture_unknown_error: true)
          end

          it "does not raise" do
            expect(response_body.keys).to match_array(%w[jsonrpc error id])
            expect(response_body["jsonrpc"]).to eq("2.0")
            expect(response_body["id"]).to be(100)

            error = response_body["error"]

            expect(error.keys).to match_array(%w[code message data])
            expect(error["data"]).to be_a(Hash)
            expect(error["code"]).to eq(-32_603)
            expect(error["message"]).to be_a(String)
          end
        end
      end
    end
  end
end
