# Examples from https://www.jsonrpc.org/specification#examples

RSpec.describe Foobara::JsonrpcConnector do
  after { Foobara.reset_alls }

  let(:command_connector) { described_class.new(capture_unknown_error:) }
  let(:connect_command) do
    command_connector.connect(command_class)
  end
  let(:capture_unknown_error) { true }
  let(:jsonrpc_inputs) do
    h = { jsonrpc: json_rpc_version, method:, params: inputs }

    if request_id
      h.merge!(id: request_id)
    end

    h
  end
  let(:method) { command_class.full_command_name }
  let(:json_rpc_version) { "2.0" }
  let(:request_id) { 100 }
  let(:input_json) do
    JSON.generate(jsonrpc_inputs)
  end

  let(:command_class) do
    stub_class "Subtract", Foobara::Command do
      inputs do
        subtrahend :number, :required
        minuend :number, :required
      end

      result :number

      def execute
        minuend - subtrahend
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

  # We will skip positional parameters since Foobara commands don't support them yet
  context "when rpc call with named parameters" do
    let(:method) { "Subtract" }
    let(:inputs) do
      { subtrahend: 23, minuend: 42 }
    end
    let(:request_id) { 3 }

    it "gives a successful response with the expected answer" do
      expect(response_body).to eq("jsonrpc" => "2.0", "result" => 19, "id" => request_id)
    end
  end

  context "when a Notification that fails" do
    let(:inputs) do
      { foo: "bar" }
    end
    let(:method) { "some_method" }
    let(:request_id) { nil }

    it "returns nil" do
      expect(response).to be_nil
    end

    context "without params" do
      let(:jsonrpc_inputs) do
        super().except(:params)
      end

      it "returns nil" do
        expect(response).to be_nil
      end
    end
  end

  context "when rpc call of non-existent method" do
    let(:method) { "some_non_existent_method" }
    let(:inputs) do
      { foo: "bar" }
    end
    let(:request_id) { 1 }

    it "returns -32601" do
      expect(response_body.keys).to match_array(%w[jsonrpc error id])
      expect(response_body["error"]["code"]).to eq(-32_601)
      expect(response_body["error"]["message"]).to be_a(String)
      expect(response_body["id"]).to be(1)
    end
  end

  context "when rpc call with invalid JSON" do
    let(:input_json) { '{"jsonrpc": "2.0", "method": "foobar, "params": "bar", "baz]' }

    it "returns -32700" do
      expect(response_body.keys).to match_array(%w[jsonrpc error id])
      expect(response_body["error"]["code"]).to eq(-32_700)
      expect(response_body["error"]["message"]).to be_a(String)
      expect(response_body["id"]).to be_nil
    end
  end

  context "when rpc call with invalid Request object" do
    let(:method) { 1 }
    let(:inputs) { "bar" }
    let(:request_id) { nil }

    # Hmmmm... seems like htis should be nil according to the docs but their example has an error
    it "returns -32600" do
      expect(response_body.keys).to match_array(%w[jsonrpc error id])
      expect(response_body["error"]["code"]).to eq(-32_600)
      expect(response_body["error"]["message"]).to be_a(String)
      expect(response_body["id"]).to be_nil
    end

    context "with only a inputs" do
      let(:method) { "Subtract" }

      it "returns -32600" do
        expect(response_body.keys).to match_array(%w[jsonrpc error id])
        expect(response_body["error"]["code"]).to eq(-32_600)
        expect(response_body["error"]["message"]).to be_a(String)
        expect(response_body["id"]).to be_nil
      end
    end
  end

  context "when rpc call Batch, invalid JSON" do
    let(:input_json) do
      '[
         {"jsonrpc": "2.0", "method": "sum", "params": [1,2,4], "id": "1"},
         {"jsonrpc": "2.0", "method"
       ]'
    end

    it "is a -32700 error" do
      expect(response_body.keys).to match_array(%w[jsonrpc error id])
      expect(response_body["error"]["code"]).to eq(-32_700)
      expect(response_body["error"]["message"]).to be_a(String)
      expect(response_body["id"]).to be_nil
    end
  end

  context "when rpc call with an empty Array" do
    let(:input_json) { "[]" }

    it "is a -32600 error" do
      expect(response_body.keys).to match_array(%w[jsonrpc error id])
      expect(response_body["error"]["code"]).to eq(-32_600)
      expect(response_body["error"]["message"]).to be_a(String)
      expect(response_body["id"]).to be_nil
    end
  end

  context "when rpc call with an invalid Batch (but not empty)" do
    let(:input_json) { "[1]" }

    it "is a -32600 error" do
      expect(response_body).to be_a(Array)
      expect(response_body.size).to eq(1)

      response = response_body[0]

      expect(response.keys).to match_array(%w[jsonrpc error id])
      expect(response["error"]["code"]).to eq(-32_600)
      expect(response["error"]["message"]).to be_a(String)
      expect(response["id"]).to be_nil
    end
  end

  context "when rpc call with invalid Batch" do
    let(:input_json) { "[1,2,3]" }

    it "results in -32600 errors" do
      expect(response_body).to be_a(Array)
      expect(response_body.size).to eq(3)

      response_body.each do |response|
        expect(response.keys).to match_array(%w[jsonrpc error id])
        expect(response["error"]["code"]).to eq(-32_600)
        expect(response["error"]["message"]).to be_a(String)
        expect(response["id"]).to be_nil
      end
    end
  end

  context "when rpc call Batch" do
    let(:input_json) do
      '[
         {"jsonrpc": "2.0", "method": "Subtract", "params": { "subtrahend": 23, "minuend": 42 }, "id": "1"},
         {"jsonrpc": "2.0", "method": "Subtract", "params": { "subtrahend": 23, "minuend": 42 }},
         {"jsonrpc": "2.0", "method": "Subtract", "params": { "subtrahend": 23, "minuend": 42 }, "id": "2"},
         {"foo": "boo"},
         {"jsonrpc": "2.0", "method": "no_such_method", "params": {"name": "myself"}, "id": "5"},
         {"jsonrpc": "2.0", "method": "Subtract", "params": { "subtrahend": 23, "minuend": 42 }, "id": "9"}
       ]'
    end

    it "gives the correct set of results and errors" do
      expect(response_body).to be_a(Array)
      expect(response_body.size).to eq(5)

      expect(response_body[0]).to eq("jsonrpc" => "2.0", "result" => 19, "id" => "1")
      expect(response_body[1]).to eq("jsonrpc" => "2.0", "result" => 19, "id" => "2")

      expect(response_body[2]["id"]).to be_nil
      error = response_body[2]["error"]
      expect(error["code"]).to eq(-32_600)
      expect(error["message"]).to be_a(String)

      expect(response_body[3]["id"]).to eq("5")
      error = response_body[3]["error"]
      expect(error["code"]).to eq(-32_601)
      expect(error["message"]).to be_a(String)

      expect(response_body[4]).to eq("jsonrpc" => "2.0", "result" => 19, "id" => "9")
    end
  end

  context "when rpc call Batch (all notifications)" do
    let(:input_json) do
      '[
         {"jsonrpc": "2.0", "method": "Subtract", "params": {"foo": "bar"}},
         {"jsonrpc": "2.0", "method": "Subtract", "params": {"baz": "baz"}}
       ]'
    end

    it "is nil" do
      expect(response).to be_nil
    end
  end
end
