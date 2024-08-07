#!/bin/sh

DEFAULT_HEIGHT="18"

print_colors() {
    height="$1"

    awk \
        -v term_cols="${width:-$(tput cols || echo 80)}" \
        -v term_lines="${height:-1}" \
        'BEGIN{
            s="/\\";
            total_cols=term_cols*term_lines;
            for (colnum = 0; colnum<total_cols; colnum++) {
                r = 255-(colnum*255/total_cols);
                g = (colnum*510/total_cols);
                b = (colnum*255/total_cols);
                if (g>255) g = 510-g;
                printf "\033[48;2;%d;%d;%dm", r,g,b;
                printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
                printf "%s\033[0m", substr(s,colnum%2+1,1);
                if (colnum%term_cols==term_cols) printf "\n";
            }
            printf "\n";
        }'
}

main() {
    height="$1"

    if [ -z "$height" ] || [ "$height" -lt "1" ]; then
        height="$DEFAULT_HEIGHT"
    fi

    print_colors "$height"
}

main "$@"
