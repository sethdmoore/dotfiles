-- set due to advice in wiki.hypr.land
-- https://wiki.hypr.land/0.55.0/Nvidia/
-- nvidia / nvidia-vaapi-driver / 
-- hl.env("NVD_BACKEND", "direct")
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- HyprLand Explicit Settings
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- NVIDIA settings
-- GBM > EGLStreams
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- enable gsync
hl.env("__GL_GSYNC_ALLOWED", "1")

-- QT settings
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- automatic scaling, based on the monitor’s pixel density
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
-- wayland, fall back to x11 oth3erwise
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Disables window decorations on Qt applications
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")


hl.env("BROWSER", "firefox")
hl.env("GNUPGHOME", os.getenv("XDG_DATA_HOME") .. "/gnupg")
hl.env("PASSWORD_STORE_DIR", os.getenv("XDG_DATA_HOME") .. "/pass")

-- force proton to run in wayland
hl.env("PROTON_ENABLE_WAYLAND", "1")
-- force electron / discord to run in wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
