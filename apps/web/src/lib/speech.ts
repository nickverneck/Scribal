export type SpeechCallbacks = {
  onTranscript: (text: string, isFinal: boolean) => void;
  onError?: (err: any) => void;
};

export function startSpeechRecognition({ onTranscript, onError }: SpeechCallbacks) {
  const SpeechRecognition: any = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
  if (!SpeechRecognition) {
    console.warn('Web Speech API not supported in this browser.');
    return null;
  }
  const recognition = new SpeechRecognition();
  recognition.lang = 'en-US';
  recognition.continuous = true;
  recognition.interimResults = true;

  recognition.onresult = (event: any) => {
    let interim = '';
    let final = '';
    for (let i = event.resultIndex; i < event.results.length; ++i) {
      const res = event.results[i];
      if (res.isFinal) final += res[0].transcript;
      else interim += res[0].transcript;
    }
    if (final) onTranscript(final.trim(), true);
    if (interim) onTranscript(interim.trim(), false);
  };
  recognition.onerror = (e: any) => onError?.(e);

  recognition.start();
  return recognition;
}

