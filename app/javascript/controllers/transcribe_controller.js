import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startBtn","stopBtn","live","final","summary"]

  connect() {
    this.recognition = null
    this.mediaRecorder = null
    this.chunks = []
    this.fullTranscript = ""
  }

  async start() {
    console.log("Start clicked")

    // Web Speech API
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (SpeechRecognition) {
      this.recognition = new SpeechRecognition()
      this.recognition.continuous = true
      this.recognition.interimResults = true
      this.recognition.onresult = event => {
        let interim = ""
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const res = event.results[i]
          if (res.isFinal) {
            this.fullTranscript += res[0].transcript + " "
          } else {
            // Filter short/interim fragments
            const t = res[0].transcript.trim()
            if (t.length > 2) interim += t + " "
          }
        }
        this.liveTarget.textContent = interim
        this.finalTarget.textContent = this.fullTranscript
      }
      this.recognition.onerror = e => console.error(e)
      try { this.recognition.start() } catch(e){}
    } else {
      alert("Browser does not support live transcription")
    }

    // MediaRecorder for audio
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream)
      this.chunks = []
      this.mediaRecorder.ondataavailable = e => { if(e.data.size>0) this.chunks.push(e.data) }
      this.mediaRecorder.start()
      this.startBtnTarget.disabled = true
      this.stopBtnTarget.disabled = false
    } catch(e) {
      alert("Microphone access required")
      console.error(e)
    }
  }

  async stop() {
    if(this.recognition) this.recognition.stop()
    if(this.mediaRecorder && this.mediaRecorder.state !== "inactive") this.mediaRecorder.stop()
    this.stopBtnTarget.disabled = true
    this.startBtnTarget.disabled = false

    await new Promise(r=>setTimeout(r,300))

    const blob = new Blob(this.chunks, { type: "audio/webm" })
    const form = new FormData()
    form.append("audio", blob, "recording.webm")
    form.append("raw_text", this.fullTranscript)
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content')

    const res = await fetch("/transcriptions", { method:"POST", headers:{"X-CSRF-Token": token}, body: form })
    if(!res.ok){ alert("Upload failed"); return }
    const body = await res.json()
    this.finalTarget.textContent = this.fullTranscript

    // fetch summary
    const sres = await fetch(`/summary/${body.id}`)
    if(sres.ok){
      const sjson = await sres.json()
      this._fadeInSummary(sjson.summary)
    } else {
      this.summaryTarget.textContent = "Summary generation failed."
    }
  }

  _fadeInSummary(text){
    this.summaryTarget.textContent = ""
    const lines = text.split(/\n|\. /).filter(Boolean)
    lines.forEach(line => {
      const p = document.createElement("p")
      p.textContent = "• " + line
      p.style.marginBottom = "5px"
      this.summaryTarget.appendChild(p)
    })
    this.summaryTarget.classList.remove("animate-fadeIn")
    void this.summaryTarget.offsetWidth
    this.summaryTarget.classList.add("animate-fadeIn")
  }

  _typeWriter(el, text){
    el.textContent = ""
    let i=0
    const speed=15
    const interval = setInterval(()=>{
      if(i<text.length){ el.textContent += text.charAt(i); i++ } else { clearInterval(interval) }
    }, speed)
  }

  toggleSummary(){
    if(!this.summaryTarget.style.display || this.summaryTarget.style.display==="block")
      this.summaryTarget.style.display="none"
    else
      this.summaryTarget.style.display="block"
  }
}
