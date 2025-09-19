class Transcription < ApplicationRecord
  has_one_attached :audio
  STATUSES = %w[pending processing done].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  # generate summary via OpenAI Chat Completions.
  # This is synchronous; in prod you might do this in a background job.
  def generate_summary!(llm: :openai)
    return if raw_text.blank?

    update!(status: "processing")

    if llm == :openai && ENV["OPENAI_API_KEY"].present?
      require "net/http"
      require "uri"
      require "json"

      uri = URI("https://api.openai.com/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
      })

      prompt = <<~PROMPT
        Summarize the following conversation. Provide:
        1) a short 3-bullet summary (concise bullets),
        2) a one-sentence conclusion.

        Conversation:
        #{raw_text}
      PROMPT

      req.body = {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a helpful conversation summarizer." },
          { role: "user", content: prompt }
        ],
        max_tokens: 250,
        temperature: 0.2
      }.to_json

      res = http.request(req)
      body = JSON.parse(res.body) rescue {}
      summary_text = body.dig("choices", 0, "message", "content") || "Could not generate summary."

      update!(summary: summary_text, status: "done")
      summary_text
    else
      # fallback: simple naive summary (very short)
      short = raw_text.split(/\.\s+/).first(3).join(". ")
      update!(summary: "Auto-summary: #{short}", status: "done")
      summary
    end
  end
end
