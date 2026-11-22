#include <array>
#include <cstdint>
#include <limits>
#include <memory>
#include <string_view>
#include <sys/stat.h>
#include <unistd.h>

#include <multimedia/player_framework/native_avbuffer.h>
#include <multimedia/player_framework/native_avdemuxer.h>
#include <multimedia/player_framework/native_avmuxer.h>
#include <multimedia/player_framework/native_avsource.h>
#include <napi/native_api.h>

namespace {
constexpr int32_t SAMPLE_CAPACITY = 12 * 1024 * 1024;
constexpr int64_t MAX_CLIP_MS = 60000;
constexpr int64_t MAX_INPUT_BYTES = 500 * 1024 * 1024;

using Source = std::unique_ptr<OH_AVSource, decltype(&OH_AVSource_Destroy)>;
using Format = std::unique_ptr<OH_AVFormat, decltype(&OH_AVFormat_Destroy)>;
using Demuxer = std::unique_ptr<OH_AVDemuxer, decltype(&OH_AVDemuxer_Destroy)>;
using Muxer = std::unique_ptr<OH_AVMuxer, decltype(&OH_AVMuxer_Destroy)>;
using Buffer = std::unique_ptr<OH_AVBuffer, decltype(&OH_AVBuffer_Destroy)>;

struct Track {
    uint32_t sourceIndex = 0;
    int32_t outputIndex = -1;
    Buffer buffer{nullptr, OH_AVBuffer_Destroy};
    OH_AVCodecBufferAttr sample{};
    bool done = false;
};

struct ClipWork {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    int inputFd = -1;
    int outputFd = -1;
    int64_t startMs = 0;
    int64_t lengthMs = 0;
    int64_t actualStartMs = -1;

    ~ClipWork()
    {
        if (inputFd >= 0) {
            close(inputFd);
        }
        if (outputFd >= 0) {
            close(outputFd);
        }
    }
};

bool AddTrack(OH_AVDemuxer *demuxer, OH_AVMuxer *muxer, OH_AVFormat *format, uint32_t index, Track &track)
{
    track.sourceIndex = index;
    track.buffer.reset(OH_AVBuffer_Create(SAMPLE_CAPACITY));
    return track.buffer && OH_AVMuxer_AddTrack(muxer, &track.outputIndex, format) == AV_ERR_OK &&
        OH_AVDemuxer_SelectTrackByID(demuxer, index) == AV_ERR_OK;
}

bool ReadSample(OH_AVDemuxer *demuxer, Track &track)
{
    while (true) {
        if (OH_AVDemuxer_ReadSampleBuffer(demuxer, track.sourceIndex, track.buffer.get()) != AV_ERR_OK ||
            OH_AVBuffer_GetBufferAttr(track.buffer.get(), &track.sample) != AV_ERR_OK) {
            return false;
        }
        if (track.sample.flags & AVCODEC_BUFFER_FLAGS_EOS) {
            track.done = true;
            return true;
        }
        if (track.sample.size > 0 && !(track.sample.flags & AVCODEC_BUFFER_FLAGS_CODEC_DATA)) {
            return true;
        }
    }
}

bool FindVideoStart(OH_AVDemuxer *demuxer, Track &video)
{
    while (ReadSample(demuxer, video) && !video.done) {
        if ((video.sample.flags & AVCODEC_BUFFER_FLAGS_SYNC_FRAME) && video.sample.pts >= 0) {
            return true;
        }
    }
    return false;
}

bool WriteSamples(OH_AVDemuxer *demuxer, OH_AVMuxer *muxer, Track &video, Track &audio, int64_t lengthUs)
{
    const int64_t firstPts = video.sample.pts;
    if (firstPts > std::numeric_limits<int64_t>::max() - lengthUs) {
        return false;
    }
    const int64_t endPts = firstPts + lengthUs;
    if (audio.outputIndex < 0) {
        audio.done = true;
    } else if (!ReadSample(demuxer, audio)) {
        return false;
    }
    bool videoWritten = false;
    while (!video.done || !audio.done) {
        auto &track = audio.done || (!video.done && video.sample.pts <= audio.sample.pts) ? video : audio;
        if (track.sample.pts >= endPts) {
            track.done = true;
            continue;
        }
        if (track.sample.pts >= firstPts) {
            OH_AVCodecBufferAttr outputSample = track.sample;
            outputSample.pts -= firstPts;
            if (OH_AVBuffer_SetBufferAttr(track.buffer.get(), &outputSample) != AV_ERR_OK ||
                OH_AVMuxer_WriteSampleBuffer(muxer, track.outputIndex, track.buffer.get()) != AV_ERR_OK) {
                return false;
            }
            videoWritten = videoWritten || &track == &video;
        }
        if (!ReadSample(demuxer, track)) {
            return false;
        }
    }
    return videoWritten;
}

int64_t Export(const ClipWork &work)
{
    struct stat info {};
    if (fstat(work.inputFd, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size <= 0 || info.st_size > MAX_INPUT_BYTES) {
        return -1;
    }
    Source source(OH_AVSource_CreateWithFD(work.inputFd, 0, info.st_size), OH_AVSource_Destroy);
    if (!source) {
        return -1;
    }
    Format infoFormat(OH_AVSource_GetSourceFormat(source.get()), OH_AVFormat_Destroy);
    int32_t count = 0;
    if (!infoFormat || !OH_AVFormat_GetIntValue(infoFormat.get(), OH_MD_KEY_TRACK_COUNT, &count) ||
        count <= 0 || count > 32) {
        return -1;
    }
    Demuxer demuxer(OH_AVDemuxer_CreateWithSource(source.get()), OH_AVDemuxer_Destroy);
    Muxer muxer(OH_AVMuxer_Create(work.outputFd, AV_OUTPUT_FORMAT_MPEG_4), OH_AVMuxer_Destroy);
    if (!demuxer || !muxer) {
        return -1;
    }
    Track video;
    Track audio;
    for (int32_t index = 0; index < count; ++index) {
        Format format(OH_AVSource_GetTrackFormat(source.get(), index), OH_AVFormat_Destroy);
        const char *mime = nullptr;
        if (!format || !OH_AVFormat_GetStringValue(format.get(), OH_MD_KEY_CODEC_MIME, &mime) || !mime) {
            continue;
        }
        const std::string_view codec(mime);
        if ((codec == "video/avc" || codec == "video/hevc") && video.outputIndex < 0) {
            if (!AddTrack(demuxer.get(), muxer.get(), format.get(), index, video)) {
                return -1;
            }
        } else if (codec == "audio/mp4a-latm" && audio.outputIndex < 0) {
            if (!AddTrack(demuxer.get(), muxer.get(), format.get(), index, audio)) {
                return -1;
            }
        }
    }
    if (video.outputIndex < 0 ||
        (work.startMs > 0 && OH_AVDemuxer_SeekToTime(demuxer.get(), work.startMs, SEEK_MODE_CLOSEST_SYNC) != AV_ERR_OK) ||
        !FindVideoStart(demuxer.get(), video) || OH_AVMuxer_Start(muxer.get()) != AV_ERR_OK) {
        return -1;
    }
    const int64_t startMs = video.sample.pts / 1000;
    const bool written = WriteSamples(demuxer.get(), muxer.get(), video, audio, work.lengthMs * 1000);
    const bool stopped = OH_AVMuxer_Stop(muxer.get()) == AV_ERR_OK;
    return written && stopped ? startMs : -1;
}

void Execute(napi_env, void *data)
{
    auto *work = static_cast<ClipWork *>(data);
    work->actualStartMs = Export(*work);
}

void Complete(napi_env env, napi_status status, void *data)
{
    std::unique_ptr<ClipWork> work(static_cast<ClipWork *>(data));
    napi_value result = nullptr;
    if (status == napi_ok && work->actualStartMs >= 0) {
        napi_create_int64(env, work->actualStartMs, &result);
        napi_resolve_deferred(env, work->deferred, result);
    } else {
        napi_value message = nullptr;
        napi_create_string_utf8(env, "Unable to export the selected video range", NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &result);
        napi_reject_deferred(env, work->deferred, result);
    }
    napi_delete_async_work(env, work->work);
}

napi_value ExportClip(napi_env env, napi_callback_info info)
{
    std::array<napi_value, 4> values{};
    size_t count = values.size();
    int32_t input = -1;
    int32_t output = -1;
    auto work = std::make_unique<ClipWork>();
    if (napi_get_cb_info(env, info, &count, values.data(), nullptr, nullptr) != napi_ok || count != values.size() ||
        napi_get_value_int32(env, values[0], &input) != napi_ok || napi_get_value_int32(env, values[1], &output) != napi_ok ||
        napi_get_value_int64(env, values[2], &work->startMs) != napi_ok ||
        napi_get_value_int64(env, values[3], &work->lengthMs) != napi_ok ||
        input < 0 || output < 0 || input == output || work->startMs < 0 ||
        work->lengthMs <= 0 || work->lengthMs > MAX_CLIP_MS) {
        napi_throw_type_error(env, nullptr, "Invalid clip range or file");
        return nullptr;
    }
    work->inputFd = dup(input);
    work->outputFd = dup(output);
    napi_value promise = nullptr;
    napi_value label = nullptr;
    if (work->inputFd < 0 || work->outputFd < 0 ||
        napi_create_promise(env, &work->deferred, &promise) != napi_ok ||
        napi_create_string_utf8(env, "HarmonyX video clip", NAPI_AUTO_LENGTH, &label) != napi_ok ||
        napi_create_async_work(env, nullptr, label, Execute, Complete, work.get(), &work->work) != napi_ok ||
        napi_queue_async_work(env, work->work) != napi_ok) {
        if (work->work) {
            napi_delete_async_work(env, work->work);
        }
        napi_throw_error(env, nullptr, "Unable to schedule video clip");
        return nullptr;
    }
    work.release();
    return promise;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor method = {"exportClip", nullptr, ExportClip, nullptr, nullptr, nullptr, napi_default, nullptr};
    napi_define_properties(env, exports, 1, &method);
    return exports;
}

napi_module module = {1, 0, nullptr, Init, "harmonyx_video_clip", nullptr, {0}};
} // namespace

extern "C" __attribute__((constructor)) void RegisterHarmonyXVideoClip()
{
    napi_module_register(&module);
}
