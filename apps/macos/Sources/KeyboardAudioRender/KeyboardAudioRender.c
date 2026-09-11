#include "KeyboardAudioRender.h"
#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

enum { queue_capacity = 256, voice_capacity = 32 };
typedef struct { float *data; uint32_t frames; } Sample;
typedef struct { uint32_t sample, generation, delay_frames; float gain, pan, rate; } Hit;
typedef struct { uint32_t sample; double position; float left, right, rate; bool active; } Voice;
struct KeyboardAudioRenderer {
    Sample *samples;
    uint32_t sample_count;
    Hit queue[queue_capacity];
    _Atomic uint32_t read_index, write_index, generation;
    _Atomic float volume;
    uint32_t rendered_generation;
    Voice voices[voice_capacity];
};

KeyboardAudioRenderer *keyboard_audio_create(uint32_t count) {
    KeyboardAudioRenderer *r = calloc(1, sizeof(*r));
    if (!r) return NULL;
    r->samples = calloc(count, sizeof(Sample));
    if (!r->samples) { free(r); return NULL; }
    r->sample_count = count;
    atomic_init(&r->read_index, 0); atomic_init(&r->write_index, 0);
    atomic_init(&r->generation, 0); atomic_init(&r->volume, 0.35f);
    if (!atomic_is_lock_free(&r->volume) || !atomic_is_lock_free(&r->write_index)) {
        keyboard_audio_destroy(r); return NULL;
    }
    return r;
}
void keyboard_audio_destroy(KeyboardAudioRenderer *r) {
    if (!r) return;
    for (uint32_t i = 0; i < r->sample_count; i++) free(r->samples[i].data);
    free(r->samples); free(r);
}
bool keyboard_audio_set_sample(KeyboardAudioRenderer *r, uint32_t index, const float *data, uint32_t frames) {
    if (index >= r->sample_count || !frames || !data) return false;
    float *copy = malloc(sizeof(float) * frames);
    if (!copy) return false;
    memcpy(copy, data, sizeof(float) * frames);
    free(r->samples[index].data);
    r->samples[index] = (Sample){ copy, frames };
    return true;
}
bool keyboard_audio_enqueue(KeyboardAudioRenderer *r, uint32_t sample, float gain, float pan, float rate) {
    return keyboard_audio_enqueue_after(r, sample, gain, pan, rate, 0);
}
bool keyboard_audio_enqueue_after(KeyboardAudioRenderer *r, uint32_t sample, float gain, float pan, float rate, uint32_t delay_frames) {
    if (sample >= r->sample_count || !r->samples[sample].data || !isfinite(gain) || gain < 0 || gain > 8 || !isfinite(pan) || !isfinite(rate) || rate < 0.25f || rate > 4 || delay_frames > 48000) return false;
    uint32_t w = atomic_load_explicit(&r->write_index, memory_order_relaxed);
    uint32_t next = (w + 1) % queue_capacity;
    if (next == atomic_load_explicit(&r->read_index, memory_order_acquire)) return false;
    r->queue[w] = (Hit){ sample, atomic_load(&r->generation), delay_frames, gain, fmaxf(-1, fminf(1, pan)), rate };
    atomic_store_explicit(&r->write_index, next, memory_order_release);
    return true;
}
void keyboard_audio_set_volume(KeyboardAudioRenderer *r, float volume) {
    atomic_store(&r->volume, isfinite(volume) ? fmaxf(0, fminf(1, volume)) : 0);
}
void keyboard_audio_reset(KeyboardAudioRenderer *r) { atomic_fetch_add(&r->generation, 1); }

void keyboard_audio_render(KeyboardAudioRenderer *r, float *left, float *right, uint32_t frames) {
    memset(left, 0, sizeof(float) * frames); memset(right, 0, sizeof(float) * frames);
    uint32_t generation = atomic_load(&r->generation);
    if (generation != r->rendered_generation) {
        memset(r->voices, 0, sizeof(r->voices)); r->rendered_generation = generation;
    }
    uint32_t read = atomic_load_explicit(&r->read_index, memory_order_relaxed);
    // Bound work to the queue snapshot; a producer cannot prolong this callback.
    uint32_t write = atomic_load_explicit(&r->write_index, memory_order_acquire);
    while (read != write) {
        Hit hit = r->queue[read]; read = (read + 1) % queue_capacity;
        if (hit.generation != generation) continue;
        Voice *voice = NULL;
        for (uint32_t i = 0; i < voice_capacity; i++) {
            if (!r->voices[i].active) { voice = &r->voices[i]; break; }
        }
        // Drop excess hits instead of cutting an audible tail or allocating.
        if (!voice) continue;
        float angle = (hit.pan + 1) * 0.78539816339f;
        *voice = (Voice){ hit.sample, -(double)hit.delay_frames, cosf(angle) * hit.gain, sinf(angle) * hit.gain, hit.rate, true };
    }
    atomic_store_explicit(&r->read_index, read, memory_order_release);
    for (uint32_t v = 0; v < voice_capacity; v++) {
        Voice *voice = &r->voices[v];
        if (!voice->active) continue;
        Sample sample = r->samples[voice->sample];
        for (uint32_t f = 0; f < frames; f++) {
            if (voice->position < 0) { voice->position += 1; continue; }
            uint32_t position = (uint32_t)voice->position;
            if (position + 1 >= sample.frames) { voice->active = false; break; }
            float fraction = (float)(voice->position - position);
            float value = sample.data[position] + fraction * (sample.data[position + 1] - sample.data[position]);
            left[f] += value * voice->left; right[f] += value * voice->right;
            voice->position += voice->rate;
        }
    }
    float volume = atomic_load(&r->volume);
    for (uint32_t f = 0; f < frames; f++) {
        // Soft saturation protects the output when many keys overlap.
        float l = left[f] * volume, rr = right[f] * volume;
        left[f] = l / (1 + fabsf(l)); right[f] = rr / (1 + fabsf(rr));
    }
}
