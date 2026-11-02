#!/usr/bin/env lua

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv = opencv_lua.cv

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")()
end

local download_utils = mediapipe.tasks.lua.core.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local SAMPLES_PATH = allegro5_lua.fs_utils.findFile("samples") ---@type string

local PIC1_FILE = SAMPLES_PATH .. "/data/pic1.png"
local PIC1_HASH = "sha256=0244e20a34fa2d30c60e60928d6d71f89d32e0e0266b4644980798cc2368765a"
local PIC1_URL = "https://raw.githubusercontent.com/opencv/opencv/refs/heads/5.x/samples/data/pic1.png"

local BUSINESS_PERSON_FILE = SAMPLES_PATH .. "/data/business-person.png"
local BUSINESS_PERSON_URL = "https://storage.googleapis.com/mediapipe-assets/business-person.png"
local BUSINESS_PERSON_HASH = "sha256=1f61cf0603cef77ffca4e24848ddf8290b5651d03b957e93b742c9ef963b5c11"

local FACE_LANDMARKER_TASK_FILE = SAMPLES_PATH .. "/data/face_landmarker.task"
local FACE_LANDMARKER_TASK_URL = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
local FACE_LANDMARKER_TASK_HASH = "sha256=64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"

download_test_files({
    {
        output = PIC1_FILE,
        hash = PIC1_HASH,
        url = PIC1_URL,
    },
    {
        output = BUSINESS_PERSON_FILE,
        url = BUSINESS_PERSON_URL,
        hash = BUSINESS_PERSON_HASH,
    },
    {
        output = FACE_LANDMARKER_TASK_FILE,
        url = FACE_LANDMARKER_TASK_URL,
        hash = FACE_LANDMARKER_TASK_HASH,
    },
})

local function pixel_format_to_string(format)
    local format_to_string = {
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY] = "ALLEGRO_PIXEL_FORMAT_ANY",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_NO_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_NO_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_WITH_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_WITH_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_15_NO_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_15_NO_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_16_NO_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_16_NO_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_16_WITH_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_16_WITH_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_24_NO_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_24_NO_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_32_NO_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_32_NO_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ANY_32_WITH_ALPHA] = "ALLEGRO_PIXEL_FORMAT_ANY_32_WITH_ALPHA",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_8888] = "ALLEGRO_PIXEL_FORMAT_ARGB_8888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGBA_8888] = "ALLEGRO_PIXEL_FORMAT_RGBA_8888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_4444] = "ALLEGRO_PIXEL_FORMAT_ARGB_4444",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGB_888] = "ALLEGRO_PIXEL_FORMAT_RGB_888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGB_565] = "ALLEGRO_PIXEL_FORMAT_RGB_565",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGB_555] = "ALLEGRO_PIXEL_FORMAT_RGB_555",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGBA_5551] = "ALLEGRO_PIXEL_FORMAT_RGBA_5551",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_1555] = "ALLEGRO_PIXEL_FORMAT_ARGB_1555",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888] = "ALLEGRO_PIXEL_FORMAT_ABGR_8888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_XBGR_8888] = "ALLEGRO_PIXEL_FORMAT_XBGR_8888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888] = "ALLEGRO_PIXEL_FORMAT_BGR_888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_BGR_565] = "ALLEGRO_PIXEL_FORMAT_BGR_565",
        [allegro5.ALLEGRO_PIXEL_FORMAT_BGR_555] = "ALLEGRO_PIXEL_FORMAT_BGR_555",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGBX_8888] = "ALLEGRO_PIXEL_FORMAT_RGBX_8888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_XRGB_8888] = "ALLEGRO_PIXEL_FORMAT_XRGB_8888",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_F32] = "ALLEGRO_PIXEL_FORMAT_ABGR_F32",
        [allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE] = "ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE",
        [allegro5.ALLEGRO_PIXEL_FORMAT_RGBA_4444] = "ALLEGRO_PIXEL_FORMAT_RGBA_4444",
        [allegro5.ALLEGRO_PIXEL_FORMAT_SINGLE_CHANNEL_8] = "ALLEGRO_PIXEL_FORMAT_SINGLE_CHANNEL_8",
        [allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT1] = "ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT1",
        [allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT3] = "ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT3",
        [allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT5] = "ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT5",
    }

    return format_to_string[format]
end

local function bitmap_locked_region_mat_view(lock, width, height)
    -- Conversion between OpenCV array type and ALLEGRO_PIXEL_FORMAT
    -- see https://love2d.org/wiki/PixelFormat
    local PIXEL_FORMAT_TO_OPENCV_ARRAY_TYPE = {
        [allegro5.ALLEGRO_PIXEL_FORMAT_SINGLE_CHANNEL_8] = cv.CV_8UC1,
        [allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888] = cv.CV_8UC3,
        [allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888] = cv.CV_8UC4,
        [allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE] = cv.CV_8UC4,
    }

    local arrayType = PIXEL_FORMAT_TO_OPENCV_ARRAY_TYPE[lock.format]
    if arrayType == nil then
        error(string.format("Unsupported ALLEGRO_PIXEL_FORMAT %s", pixel_format_to_string(lock.format)))
    end

    -- Matrix constructors that take data and step parameters do not allocate matrix data.
    -- Instead, they just initialize the matrix header that points to the specified data, which means that no data is copied.
    -- This operation is very efficient and can be used to process external data using OpenCV functions.
    -- see https://docs.opencv.org/4.x/d3/d63/classcv_1_1Mat.html#a9fa74fb14362d87cb183453d2441948f
    return cv.Mat(opencv_lua.kwargs({
        ["size"] = { width, height },
        ["type"] = arrayType,
        ["data"] = lock.data,
        ["step"] = lock.pitch,
    }))
end

local function create_bitmap_from_mat(mat)
    -- Conversion between ALLEGRO_PIXEL_FORMAT and OpenCV array type
    -- see https://liballeg.org/a5docs/trunk/graphics.html#allegro_pixel_format
    local OPENCV_ARRAY_TYPE_TO_PIXEL_FORMAT = {
        [cv.CV_8UC1] = allegro5.ALLEGRO_PIXEL_FORMAT_SINGLE_CHANNEL_8,
        [cv.CV_8UC3] = allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888,
        [cv.CV_8UC4] = allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE,
    }

    local format = OPENCV_ARRAY_TYPE_TO_PIXEL_FORMAT[mat:type()]
    if format == nil then
        error(string.format("Unable get ALLEGRO_PIXEL_FORMAT from cv::Mat array type from %i", mat:type()))
    end

    local width, height = mat.width, mat.height

    local old_flags = allegro5.al_get_new_bitmap_flags()
    local old_format = allegro5.al_get_new_bitmap_format()

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    allegro5.al_set_new_bitmap_format(format)

    local bitmap = allegro5.al_create_bitmap(width, height)

    allegro5.al_set_new_bitmap_flags(old_flags)
    allegro5.al_set_new_bitmap_format(old_format)

    local lock = allegro5.al_lock_bitmap(bitmap, allegro5.ALLEGRO_PIXEL_FORMAT_ANY, allegro5.ALLEGRO_LOCK_WRITEONLY)
    mat:copyTo(bitmap_locked_region_mat_view(lock, width, height))
    allegro5.al_unlock_bitmap(bitmap)

    return bitmap
end

local function create_opencv_image()
    local img = cv.imread(PIC1_FILE)

    -- Process the image with OpenCV
    local img_grey = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
    local ret, thresh = cv.threshold(img_grey, 100, 255, cv.THRESH_BINARY)
    local contours, hierarchy = cv.findContours(thresh, cv.RETR_TREE, cv.CHAIN_APPROX_SIMPLE)

    -- Draw red contours
    cv.drawContours(img, contours, -1, { 0, 0, 255 }, 2)

    return img
end

local function resize_and_show(image, title, show)
    if title == nil then title = "" end
    if show == nil then show = true end

    local DESIRED_HEIGHT = 480
    local DESIRED_WIDTH = 480
    local w = image.width
    local h = image.height

    if h < w then
        h = math.floor(h / (w / DESIRED_WIDTH))
        w = DESIRED_WIDTH
    else
        w = math.floor(w / (h / DESIRED_HEIGHT))
        h = DESIRED_HEIGHT
    end

    local interpolation = (function()
        if DESIRED_WIDTH > image.width or DESIRED_HEIGHT > image.height then
            return cv.INTER_CUBIC
        end
        return cv.INTER_AREA
    end)()

    local img = cv.resize(image, { w, h }, opencv_lua.kwargs(({ interpolation = interpolation })))

    if show then
        cv.imshow(title, img)
    end

    return w / image.width, img
end

local vision = mediapipe.tasks.lua.vision
local drawing_utils = mediapipe.tasks.lua.vision.drawing_utils
local drawing_styles = mediapipe.tasks.lua.vision.drawing_styles

local function draw_landmarks_on_image(rgb_image, detection_result)
    -- Compute the scale to make drawn elements visible when the image is resized for display
    local scale = 1 / resize_and_show(rgb_image, nil, false)

    local face_landmarks_list = detection_result.face_landmarks
    local annotated_image = cv.cvtColor(rgb_image, cv.COLOR_RGB2BGR)

    -- Loop through the detected faces to visualize.
    for _, face_landmarks in ipairs(face_landmarks_list) do
        -- Draw the face landmarks.


        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_TESSELATION,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_tesselation_style(scale)
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_CONTOURS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_contours_style(mediapipe_lua.kwargs({ style = 1, scale = scale }))
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_LEFT_IRIS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_iris_connections_style(scale)
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_RIGHT_IRIS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_iris_connections_style(scale)
        }))
    end

    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua

local function create_mediapipe_image()
    -- STEP 2: Create a FaceLandmarker object.
    local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = FACE_LANDMARKER_TASK_FILE }))
    local options = vision.FaceLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_face_blendshapes = true,
        output_facial_transformation_matrixes = true,
        num_faces = 1
    }))
    local detector = vision.FaceLandmarker.create_from_options(options)

    -- STEP 3: Load the input image.
    local image = mp.Image.create_from_file(BUSINESS_PERSON_FILE)

    -- STEP 4: Detect face landmarks from the input image.
    local detection_result = detector:detect(image)

    -- STEP 5: Process the detection result. In this case, visualize it.
    local annotated_image = draw_landmarks_on_image(image:mat_view(), detection_result)
    local _, resized = resize_and_show(annotated_image, nil, false)

    return resized
end

local function main()
    local FPS = 60
    local w, h = 1280, 720
    local done = false
    local redraw = true

    if not allegro5.al_init() then
        error("Failed to init Allegro.\n")
    end

    --[[ Allegro requires installing drivers for all input devices before
     - they can be used.
     --]]
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()

    allegro5.al_init_font_addon()
    local font = allegro5.al_create_builtin_font()

    local display = allegro5.al_create_display(w, h)
    if not display then
        error("Error creating display.\n")
    end

    allegro5.al_install_keyboard()

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    -- OpenCV uses BGR color space
    -- our allegro5 functions expects RGBA color space
    local bitmap_opencv = create_bitmap_from_mat(cv.cvtColor(create_opencv_image(), cv.COLOR_BGR2RGBA))
    local bitmap_mediapipe = create_bitmap_from_mat(cv.cvtColor(create_mediapipe_image(), cv.COLOR_BGR2RGBA))

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.0, 0.0, 0.0))

            allegro5.al_draw_bitmap(bitmap_opencv, 10, 10, 0)
            allegro5.al_draw_bitmap(bitmap_mediapipe, w - allegro5.al_get_bitmap_width(bitmap_mediapipe) - 10, h - allegro5.al_get_bitmap_height(bitmap_mediapipe) - 10, 0)

            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1.0, 1.0, 1.0),
                allegro5.al_get_display_width(display) / 2, allegro5.al_get_display_height(display) / 2,
                allegro5.ALLEGRO_ALIGN_CENTER, "Welcome to Allegro!")

            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end
    end

    allegro5.al_destroy_bitmap(bitmap_opencv)
    allegro5.al_destroy_bitmap(bitmap_mediapipe)
end

main()
