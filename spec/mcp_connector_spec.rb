RSpec.describe Foobara::McpConnector do
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
    let(:mcp_inputs) do
      h = {
        jsonrpc: jsonrpc_version,
        method:,
        params:
      }

      if request_id
        h[:id] = request_id
      end

      h
    end
    let(:tool_name) { command_class.full_command_name }
    let(:method) { "tools/call" }
    let(:params) do
      h = {
        name: tool_name
      }

      if arguments
        h[:arguments] = arguments
      end

      h
    end
    let(:arguments) { inputs }
    let(:jsonrpc_version) { "2.0" }
    let(:request_id) { 100 }
    let(:request_json) do
      JSON.generate(mcp_inputs)
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

        description "Computes an exponent"

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
      command_connector.run(request_json)
    end
    let(:response_body) do
      JSON.parse(response)
    end

    before do
      connect_command
    end

    context "when performing 'initialize' request part of handshake" do
      let(:method) { "initialize" }
      let(:params) do
        {
          protocolVersion: "2025-03-26",
          clientInfo: { name: "Some Client", version: "1.0.0" },
          capabilities: {}
        }
      end

      it "results in the expected and sets a session" do
        expect(response_body.keys).to match_array(%w[id jsonrpc result])
        expect(response_body["id"]).to eq(request_id)
        expect(response_body["jsonrpc"]).to eq("2.0")

        result = response_body["result"]
        expect(result["capabilities"]).to eq("tools" => { "listChanged" => false })
        expect(result["instructions"]).to be_a(String)
      end
    end

    context "when listing tools (commands)" do
      let(:method) { "tools/list" }
      let(:params) { nil }

      it "gives an array of tools" do
        expect(response_body.keys).to match_array(%w[id jsonrpc result])
        expect(response_body["id"]).to eq(request_id)
        expect(response_body["jsonrpc"]).to eq("2.0")

        result = response_body["result"]
        expect(result["tools"]).to eq(
          [
            {
              "name" => "SomeOrg::SomeDomain::ComputeExponent",
              "description" => "Computes an exponent",
              "inputSchema" => {
                "type" => "object",
                "properties" => {
                  "base" => { "type" => "number" },
                  "exponent" => { "type" => "number" }
                },
                "required" => %w[base exponent]
              }
            }
          ]
        )
      end
    end

    it "executes the command and returns a response" do
      expect(response_body).to eq("jsonrpc" => "2.0", "result" => 8, "id" => request_id)
    end

    context "when it is a notification" do
      let(:request_id) { nil }

      it "does not return a response" do
        expect {
          expect(response).to be_nil
        }.to change(command_class, :called_with).from([]).to([inputs])
      end
    end

    context "when it's a batch of commands" do
      let(:mcp_inputs) do
        [
          { jsonrpc: "2.0", method: "tools/call",
            params: { name: command_class.full_command_name, arguments: { base: 2, exponent: 2 } }, id: 10 },
          { jsonrpc: "2.0", method: "tools/call",
            params: { name: command_class.full_command_name, arguments: { base: 2, exponent: 3 } } },
          { jsonrpc: "2.0", method: "tools/call",
            params: { name: command_class.full_command_name, arguments: { base: "asdf", exponent: 4 } }, id: 20 },
          { bad_request: "really bad" },
          { jsonrpc: "2.0", method: "tools/call",
            params: { name: command_class.full_command_name, arguments: { base: 2, exponent: 5 } }, id: 30 }
        ]
      end

      it "returns an array of results but does not include the notifications" do
        expect(response_body.size).to eq(4)
        expect(response_body[0]).to eq("jsonrpc" => "2.0", "result" => 4, "id" => 10)

        error = response_body[1]["error"]
        expect(error["code"]).to eq(-32_602)
        expect(error["message"]).to be_a(String)
        expect(error["data"]).to be_a(Hash)

        error = response_body[2]["error"]
        expect(error["code"]).to eq(-32_600)
        expect(error["message"]).to be_a(String)

        expect(response_body[3]).to eq("jsonrpc" => "2.0", "result" => 32, "id" => 30)
      end
    end

    context "with a bad jsonrpc version" do
      let(:jsonrpc_version) { "asdf" }

      it "gives an error" do
        expect(response_body).to eq(
          "jsonrpc" => "2.0",
          "error" => {
            "code" => -32_600,
            "message" => "Unsupported jsonrpc version: #{jsonrpc_version}"
          },
          "id" => request_id
        )
      end
    end

    context "with invalid json" do
      let(:request_json) { "{ asdfasdfasdf" }

      it "gives an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to be_nil

        error = response_body["error"]

        expect(error.keys).to match_array(%w[code message])

        expect(error["code"]).to eq(-32_700)
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

      context "when inputs are an array which Foobara commands don't support at this time" do
        let(:inputs) { [1, 2, 3] }

        it "gives an error" do
          expect(response_body.keys).to match_array(%w[jsonrpc error id])
          expect(response_body["jsonrpc"]).to eq("2.0")
          expect(response_body["id"]).to be(100)

          error = response_body["error"]

          expect(error.keys).to match_array(%w[code message])

          expect(error["code"]).to eq(-32_602)
          expect(error["message"]).to be_a(String)
        end
      end
    end

    context "with a bad command name" do
      let(:tool_name) { "BadCommandName" }

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
