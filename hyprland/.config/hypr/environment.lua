-- set due to advice in wiki.hypr.land
-- https://wiki.hypr.land/0.55.0/Nvidia/
-- nvidia / nvidia-vaapi-driver / 
hl.env("NVD_BACKEND", "direct")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
