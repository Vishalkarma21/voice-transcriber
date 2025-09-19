class TranscriptionsController < ApplicationController
  # If you send requests from the same origin with CSRF meta tag included
  # you won't need to skip verify_authenticity_token. The JS will include the token.
  protect_from_forgery with: :exception

  def create
    # Accepts:
    # - params[:audio] => uploaded file (audio/webm)
    # - params[:raw_text] => raw transcript from client (optional)
    @transcription = Transcription.create!(raw_text: params[:raw_text], status: "pending")

    if params[:audio].present?
      @transcription.audio.attach(params[:audio])
    end

    render json: { id: @transcription.id }, status: :created
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    t = Transcription.find(params[:id])
    render json: {
      id: t.id,
      raw_text: t.raw_text,
      summary: t.summary,
      status: t.status,
      audio_url: (url_for(t.audio) if t.audio.attached?)
    }
  end

  # GET /summary/:id
  def summary
    t = Transcription.find(params[:id])
    if t.summary.blank?
      t.generate_summary!
    end
    render json: { id: t.id, summary: t.summary }
  end
end
