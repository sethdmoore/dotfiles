#!/usr/bin/env python3

import sys
import time
from subprocess import Popen, PIPE


def print_help():
    print("Usage: lb_test.py [URL]")
    print("./lb_test.py https://example.com")
    sys.exit(0)


def strip(url):
    if "http://" in url:
        url = url.split("http://")[1]

    if "https://" in url:
        url = url.split("https://")[1]

    if '/' in url:
        url = url.split('/')[0]

    return url


def run(cmd):
    start_time = time.time()
    p = Popen(cmd, stdout=PIPE, stderr=PIPE)
    out, err = p.communicate()
    if err:
        print("STDERR: {0}".format(err))
    if out:
        return out.decode('ascii').rstrip(), time.time() - start_time
    else:
        print("ERR: {0} returned no output!".format(" ".join(cmd)))
        sys.exit(2)


def curl_all(url, bare_domain, a_records, port):
    for record in a_records:
        resolve_string = "{0}:{1}:{2}".format(bare_domain, port, record)
        cmd = [
               'curl',
               '-s',
               '--resolve', resolve_string,
               url,
               '-o', '/dev/null',
               '-w', '%{http_code}'
              ]
        print("About to {0}".format(" ".join(cmd)))
        out, time = run(cmd)
        if out:
            print("Time: {0}".format(time))
            print("HTTP Code: {0}".format(out))


def transform_dig_output(blob):
    new_output = []
    # lazy man's way of filtering CNAME
    # could regex this, but lazy
    for line in blob.split('\n'):
        if 'com' in line:
            continue
        elif 'amazon' in line:
            continue
        new_output.append(line)
    return new_output


def main():
    if len(sys.argv) != 2:
        print_help()

    url = sys.argv[1]

    if 'http://' in url:
        port = 80
    elif 'https://' in url:
        port = 443
    else:
        print_help()

    bare_domain = strip(url)

    dig_cmd = ['dig', '+short', bare_domain]
    a_records, _ = run(dig_cmd)
    a_record_array = transform_dig_output(a_records)
    # print(a_records)
    curl_all(url, bare_domain, a_record_array, port)


if __name__ == '__main__':
    main()
