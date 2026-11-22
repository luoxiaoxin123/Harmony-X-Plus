cmake_minimum_required(VERSION 3.16)
project(harmonyx_video_clip LANGUAGES CXX)

add_library(harmonyx_video_clip SHARED video_clip.cpp)
target_compile_features(harmonyx_video_clip PRIVATE cxx_std_17)
target_link_libraries(harmonyx_video_clip PRIVATE
    ace_napi.z
    native_media_avsource
    native_media_avdemuxer
    native_media_avmuxer
    native_media_core
    native_media_codecbase
)
