/* TODO port to Odin

from PIL import Image
import numpy as np
from scipy.io.wavfile import write

bmp_path = "audio_hilbert.bmp"
wav_path = "out.wav"
sample_rate = 48000

image = Image.open(bmp_path)
image_data = np.array(image)

audio_bytes = image_data.flatten()

if len(audio_bytes) % 2 != 0:
    audio_bytes = audio_bytes[:-1]

audio_data = np.frombuffer(audio_bytes.tobytes(), dtype='u1')
# audio_data = audio_data[::2]

write(wav_path, sample_rate, audio_data)

*/