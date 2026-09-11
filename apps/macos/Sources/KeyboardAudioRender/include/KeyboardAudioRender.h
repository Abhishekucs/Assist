#ifndef KEYBOARD_AUDIO_RENDER_H
#define KEYBOARD_AUDIO_RENDER_H
#include <stdbool.h>
#include <stdint.h>

typedef struct KeyboardAudioRenderer KeyboardAudioRenderer;
KeyboardAudioRenderer *keyboard_audio_create(uint32_t sample_count);
void keyboard_audio_destroy(KeyboardAudioRenderer *renderer);
// Load immutable samples before connecting the render callback.
bool keyboard_audio_set_sample(KeyboardAudioRenderer *, uint32_t index, const float *, uint32_t frames);
// Single producer: the main run loop. Single consumer: the audio render thread.
bool keyboard_audio_enqueue(KeyboardAudioRenderer *, uint32_t sample, float gain, float pan, float rate);
bool keyboard_audio_enqueue_after(KeyboardAudioRenderer *, uint32_t sample, float gain, float pan, float rate, uint32_t delay_frames);
void keyboard_audio_set_volume(KeyboardAudioRenderer *, float volume);
void keyboard_audio_reset(KeyboardAudioRenderer *);
void keyboard_audio_render(KeyboardAudioRenderer *, float *left, float *right, uint32_t frames);
#endif
