require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "Summaries", type: :request do
  before do
    # stub OpenAI chat completion call
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [
            { message: { content: "Bullet 1\nBullet 2\nBullet 3\nConclusion: Good." } }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it "creates transcription and returns summary" do
    t = Transcription.create!(raw_text: "Hello world. This is a test.", status: 'pending')

    get "/summary/#{t.id}"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["summary"]).to include("Bullet 1")
    t.reload
    expect(t.status).to eq("done")
  end
end
