RSpec.describe Foobara::McpConnector do
  after { Foobara.reset_alls }

  describe "with a super basic command connected" do
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
          protocolVersion: protocol_version,
          clientInfo: { name: "Some Client", version: "1.0.0" },
          capabilities: {}
        }
      end
      let(:protocol_version) { "2025-03-26" }

      it "results in the expected and sets a session" do
        expect(response_body.keys).to match_array(%w[id jsonrpc result])
        expect(response_body["id"]).to eq(request_id)
        expect(response_body["jsonrpc"]).to eq("2.0")

        result = response_body["result"]
        expect(result["capabilities"]).to eq("tools" => { "listChanged" => false })
        expect(result["instructions"]).to be_a(String)
        expect(result["protocolVersion"]).to eq("2025-03-26")
      end

      context "when 2024-11-05 is requested" do
        let(:protocol_version) { "2024-11-05" }

        it "chooses 2024-11-05" do
          expect(response_body["result"]["protocolVersion"]).to eq("2024-11-05")
        end
      end

      context "when an unsupported date is chosen" do
        let(:protocol_version) { "2023-01-01" }

        it "chooses the latest supported version" do
          expect(response_body["result"]["protocolVersion"]).to eq("2025-03-26")
        end
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

    context "when request is poorly structured" do
      let(:request_json) { "100" }

      it "is an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to be_nil

        expect(response_body["error"].keys).to match_array(%w[code message])
        expect(response_body["error"]["code"]).to eq(-32_600)
      end
    end

    context "when arguments are poorly structured" do
      let(:arguments) { 100 }

      it "is an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["jsonrpc"]).to eq("2.0")
        expect(response_body["id"]).to eq(request_id)

        expect(response_body["error"].keys).to match_array(%w[code message])
        expect(response_body["error"]["code"]).to eq(-32_600)
      end
    end

    context "when requesting an unsupported method" do
      let(:method) { "resources/list" }
      let(:params) { nil }

      it "is an error" do
        expect {
          response_body
        }.to raise_error(Foobara::McpConnector::Request::MethodNotYetSupportedError)
      end
    end

    context "when requesting a non-existent method" do
      let(:method) { "asdfasdf" }
      let(:params) { nil }

      it "is an error" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["id"]).to eq(request_id)

        expect(response_body["error"].keys).to match_array(%w[code message])
        expect(response_body["error"]["code"]).to eq(-32_600)
      end
    end

    context "when it is a noop request like notifications/initialized" do
      let(:method) { "notifications/initialized" }
      let(:params) { nil }
      let(:request_id) { nil }

      it "does not return a response" do
        expect(response).to be_nil
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

      context "when the batch is empty" do
        let(:mcp_inputs) { [] }

        it "is an error" do
          expect(response_body.keys).to match_array(%w[jsonrpc error id])
          expect(response_body["jsonrpc"]).to eq("2.0")
          expect(response_body["id"]).to be_nil

          expect(response_body["error"].keys).to match_array(%w[code message])
          expect(response_body["error"]["code"]).to eq(-32_600)
        end
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

    describe "#run_stdio_server" do
      let(:io_in_pipe) { IO.pipe }
      let(:io_out_pipe) { IO.pipe }
      let(:io_in_reader) { io_in_pipe.first }
      let(:io_in_writer) { io_in_pipe.last }
      let(:io_out_reader) { io_out_pipe.first }
      let(:io_out_writer) { io_out_pipe.last }

      let(:io_in) { io_in_reader }
      let(:io_out) { io_out_writer }
      let(:io_err) { StringIO.new }

      let(:command_that_explodes_class) do
        stub_class "CommandThatExplodes", Foobara::Command do
          def execute
            raise "kaboom!!"
          end
        end
      end

      before do
        command_connector.connect(command_that_explodes_class)
      end

      it "runs a stdio server and handles requests/responses" do
        Thread.new do
          command_connector.run_stdio_server(io_in:, io_out:, io_err:)
        end

        initialize_request = JSON.generate(
          jsonrpc: "2.0",
          method: "initialize",
          params: {
            protocolVersion: "2025-03-26",
            clientInfo: { name: "Some Client", version: "1.0.0" },
            capabilities: {}
          },
          id: 1
        )

        io_in_writer.puts initialize_request

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id result jsonrpc])
        expect(response["result"].keys).to match_array(%w[capabilities instructions protocolVersion serverInfo])

        expect(response["id"]).to eq(1)
        expect(response["result"]["capabilities"]).to eq("tools" => { "listChanged" => false })
        expect(response["result"]["instructions"]).to be_a(String)

        list_tools_request = JSON.generate(
          method: "tools/list", params: nil, id: 2, jsonrpc: "2.0"
        )
        io_in_writer.puts list_tools_request

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id result jsonrpc])
        expect(response["result"].keys).to match_array(%w[tools])

        expect(response["id"]).to eq(2)
        expect(response["result"]["tools"]).to contain_exactly(
          {
            "description" => "Computes an exponent",
            "inputSchema" => {
              "properties" => {
                "base" => { "type" => "number" },
                "exponent" => { "type" => "number" }
              },
              "required" => %w[base exponent],
              "type" => "object"
            },
            "name" => "SomeOrg::SomeDomain::ComputeExponent"
          },
          {
            "inputSchema" => { "type" => "object" },
            "name" => "CommandThatExplodes"
          }
        )

        name = command_class.full_command_name
        method = "tools/call"

        tools_call_request = JSON.generate(
          jsonrpc: "2.0",
          method:,
          params: { name:, arguments: { base: 2, exponent: 3 } },
          id: 3
        )
        io_in_writer.puts tools_call_request

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id result jsonrpc])
        expect(response["result"]).to eq(8)
        expect(response["id"]).to eq(3)

        # test that a notification gives no response
        tools_call_notification = JSON.generate(
          jsonrpc: "2.0",
          method:,
          params: {
            name: "SomeOrg::SomeDomain::ComputeExponent",
            arguments: { base: 2, exponent: 3 }
          }
        )
        io_in_writer.puts tools_call_notification
        # no response to check

        # Test a batch of tools/call requests

        batch_request = JSON.generate(
          [
            { jsonrpc: "2.0", method:,
              id: 3, params: { name:, arguments: { base: 2, exponent: 2 } } },
            { jsonrpc: "2.0", method:,
              params: { name:, arguments: { base: 2, exponent: 3 } } },
            { jsonrpc: "2.0", method:,
              id: 4, params: { name:, arguments: {} } },
            { bad_request: "really bad" },
            { jsonrpc: "2.0", method:,
              id: 5, params: { name:, arguments: { base: 2, exponent: 5 } } }
          ]
        )

        io_in_writer.puts batch_request

        response = JSON.parse(io_out_reader.readline)

        expect(response).to be_an(Array)
        expect(response.size).to eq(4)

        expect(response[0].keys).to match_array(%w[id result jsonrpc])
        expect(response[0]["result"]).to eq(4)
        expect(response[0]["id"]).to eq(3)

        expect(response[1].keys).to match_array(%w[id error jsonrpc])
        expect(response[1]["id"]).to eq(4)
        expect(response[1]["error"].keys).to match_array(%w[code data message])
        expect(response[1]["error"]["code"]).to eq(-32_602)

        expect(response[2].keys).to match_array(%w[id error jsonrpc])
        expect(response[2]["id"]).to be_nil
        expect(response[2]["error"].keys).to match_array(%w[code message])
        expect(response[2]["error"]["code"]).to eq(-32_600)

        expect(response[3].keys).to match_array(%w[id result jsonrpc])
        expect(response[3]["result"]).to eq(32)
        expect(response[3]["id"]).to eq(5)

        # Test a bad version

        bad_version_request = JSON.generate(
          jsonrpc: "1.5", method:,
          params: { name:,
                    arguments: { base: 2, exponent: 3 } },
          id: 6
        )

        io_in_writer.puts bad_version_request

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id error jsonrpc])
        expect(response["id"]).to eq(6)
        expect(response["error"].keys).to match_array(%w[code message])
        expect(response["error"]["code"]).to eq(-32_600)

        # test bad json
        io_in_writer.puts "{ asfdasfasdfasdf"

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id error jsonrpc])
        expect(response["id"]).to be_nil
        expect(response["error"].keys).to match_array(%w[code message])
        expect(response["error"]["code"]).to eq(-32_700)

        # test with a bad command name
        io_in_writer.puts JSON.generate(
          jsonrpc: "2.0",
          method: "tools/call",
          params: { name: "BadCommandName", arguments: { base: 2, exponent: 3 } },
          id: 7
        )

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id error jsonrpc])
        expect(response["id"]).to eq(7)
        expect(response["error"].keys).to match_array(%w[code message])
        expect(response["error"]["code"]).to eq(-32_601)

        # with command that explodes
        io_in_writer.puts JSON.generate(
          jsonrpc: "2.0", method:,
          params: { name: command_that_explodes_class.full_command_name },
          id: 8
        )

        response = JSON.parse(io_out_reader.readline)

        expect(response.keys).to match_array(%w[id error jsonrpc])
        expect(response["id"]).to eq(8)
        expect(response["error"].keys).to match_array(%w[code message])
        expect(response["error"]["code"]).to eq(-32_603)
        expect(response["error"]["message"]).to eq("kaboom!!")

        io_in_writer.close
      end
    end
  end
end
