#!/usr/bin/env python3
from subprocess import Popen, PIPE
import sys

CAPTURE_MOUSE=False
RESOLUTIONS = {
        "480p": ["854", "480"],
        "720p": ["1280", "720"],
        "1080p": ["1920", "1080"]
}

class Config(object):
    def __init__(self,
                 capture_mouse=False,
                 resolution="480p",
                 temp_file="/tmp/region_cap.mp4",
                 file_limit="10M",
                 quant="26",
                 enable_max_width=True
                 ):
        self.capture_mouse=capture_mouse
        self.resolution=resolution
        self.temp_file=temp_file
        self.file_limit=file_limit
        self.quant=quant
        self.enable_max_width=enable_max_width

        # initialize some resolution variables
        if self.resolution in RESOLUTIONS:
            self.max_width = RESOLUTIONS[self.resolution][0]
        else:
            self.max_width = RESOLUTIONS["480p"][0]

def shell_out(args, suppress_output=False):
    command = args[0]
    print(args)
    p = Popen(args, stdout=PIPE, stderr=PIPE, universal_newlines=True)
    out, err = p.communicate()

    if p.returncode != 0:
        if err:
            print(err, file=sys.stderr)
        print(command + " exited %s" % p.returncode)
        sys.exit(1)

    if out and not suppress_output:
        return out
    else:
        return None


def ffmpeg(c):
    ffmpeg_input = ":0.0+%s,%s" % (c.x, c.y)

    capture_mouse = 0

    if c.capture_mouse:
        capture_mouse = 1

    if c.enable_max_width:
        if c.w > c.max_width:
            c.scale_w = c.max_width
        else:
            c.scale_w = c.w
    else:
        c.scale_w = c.w

    command = [
        "ffmpeg",
        "-vsync", "passthrough",
        "-frame_drop_threshold", "4",
        "-f", "x11grab",
        "-draw_mouse", str(capture_mouse),
        "-video_size", "%sx%s" % (c.w, c.h),
        "-framerate", "60",
        "-i", ffmpeg_input,
        "-vcodec", "libx264",
        "-vf", "scale=%s:-2" % c.scale_w,
        "-preset", "ultrafast",
        "-crf:v", str(c.quant),
        "-fs", c.file_limit,
        "-y",
        c.temp_file
    ]
    shell_out(command)


def slop(c):
    # don't need to return anything since it's pass-by-reference...
    flags = shell_out(["slop", "-f", '%x %y %w %h %g %i'])
    c.x, c.y, c.w, c.h, c.g, c.id = flags.split(" ")


def main():
    conf = Config()
    slop(conf)
    ffmpeg(conf)


if __name__ == '__main__':
    main()
