#-----------------------------------------------------------------------------#
# For better integration with vcpkg, prefer config modules.
# Because targets will only be visible to targets created in addons subdirectoy,
# making them unusabe to the monolith target.
# Therefore, use find_package at top to make them available to the monolith target.

# ================
# image
# ================
if (NOT IPHONE)
    option(WANT_IMAGE_JPG "Enable JPEG support in image addon" on)
    option(WANT_IMAGE_PNG "Enable PNG support in image addon" on)
    option(WANT_IMAGE_FREEIMAGE "Enable FreeImage support in image addon" on)
endif (NOT IPHONE)
option(WANT_IMAGE_WEBP "Enable WebP support in image addon" on)

if (WANT_IMAGE_JPG)
    find_package(JPEG)
endif()

if (WANT_IMAGE_PNG)
    find_package(PNG)
endif()

if (WANT_IMAGE_FREEIMAGE)
    find_package(FreeImage CONFIG)
endif()

if (WANT_IMAGE_WEBP)
    find_package(WebP CONFIG)
endif()

# ================
# ttf
# ================
option(WANT_TTF "Enable TTF addon" on)
if (WANT_TTF)
    find_package(Freetype)
endif()

# ================
# physfs
# ================
option(WANT_PHYSFS "Enable PhysicsFS addon" on)
if (WANT_PHYSFS)
    find_package(PhysFS CONFIG)
endif()

# ================
# acodec
# ================
option(WANT_FLAC "Enable FLAC support" on)
if (WANT_FLAC)
    find_package(FLAC CONFIG)
endif()

option(WANT_VORBIS "Enable Ogg Vorbis support using libvorbis" on)
if (WANT_VORBIS)
    find_package(Vorbis CONFIG)
endif()

option(WANT_OPUS "Enable Opus support using libopus" on)
if (WANT_OPUS)
    find_package(Opus CONFIG)
    find_package(OpusFile CONFIG)
endif()

option(WANT_OPENMPT "Enable mod audio support using OpenMPT" on)
if (WANT_OPENMPT)
    find_package(OpenMPT CONFIG NAMES libopenmpt)
endif()

# ================
# audio
# ================
option(WANT_ALSA "Enable ALSA digital audio driver (Unix)" on)
if(WANT_ALSA AND UNIX AND NOT APPLE AND NOT ANDROID)
    find_package(ALSA)
endif()

option(WANT_OPENAL "Enable OpenAL digital audio driver" on)
if (WANT_OPENAL)
    find_package(OpenAL CONFIG)
endif()

# ================
# video
# ================
option(WANT_OGG_VIDEO "Enable Ogg video (requires Theora and Vorbis)" on)
if (WANT_OGG_VIDEO)
    find_package(Ogg CONFIG)
    find_package(unofficial-theora CONFIG)
    find_package(Vorbis CONFIG)
endif()
#-----------------------------------------------------------------------------#
