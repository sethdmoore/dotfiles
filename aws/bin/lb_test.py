#!/usr/bin/env python3

import sys
import argparse
import ipaddress
from subprocess import Popen, PIPE

# curl -k https://names.nomisinternal.com --resolve "names.nomissinternal.com:443:10.129.1.67"

# Wrapper around Popen, run a shell command
# cmd is a slice[]
def cmd(cmd):
    p = Popen(cmd, stdout=PIPE, stderr=PIPE)
    out, err = p.communicate()
    if err:
        print('STDERR: {}'.format(str(err)), file=sys.stderr)
        sys.exit(2)

    return out.decode('ASCII').rstrip().split('\n')


# determine if input is an ipv4 address
def is_ip(ip):
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError as e:
        return False
    except Exception as e:
        return False


# return a config{} dictionary from input URL
# contains ['proto'], ['domain'] and ['route']
def parse_url(url):
    # use a packed tuple of order proto, use_https
    config = {}
    protos = ['http://', 'https://']

    # iterate over supported protocols
    for proto in protos:
        if url.startswith(proto):
            # return whether the proto was https or not
            config['domain'] = url[len(proto):]
            config['proto'] = proto

    # if the domain to curl did not specify proto://, we will
    # use http://
    if 'proto' not in config:
        config['proto'] = 'http://'
        config['domain'] = url

    if '/' in config['domain']:
        # grab the index of the first slash

        # parsing the proto:// should have removed any preceded slashes unless user
        # inserted some garbage
        i = config['domain'].index('/')

        # anything up until the first slash is our domain
        domain = config['domain'][:i]
        # anything after the first slash is the route
        route = config['domain'][i:]

        # set config object
        config['domain'] = domain
        # set route
        config['route'] = route
    else:
        # default to '/' if there are no slashes
        config['route'] = '/'

    return config


# resolve ALB to ipv4 addresses
def resolve(url, verbose=False):
    dig = ['dig', '+short', url]
    ips = []
    output = cmd(dig)

    for ip in output:
        if is_ip(ip):
            ips.append(ip)

    if not ips:
        print("ERROR: Could not resolve {0} to an IPv4".format(url))
        sys.exit(2)

    if verbose:
        print("Found {0} IP(s): {1}".format(
            len(ips),
            ", ".join((ips))
        ))
    return ips


# invoke curl
def curl(config, ip=None, verbose=False):
    # rebuild the URL from config{}
    url = "{0}{1}{2}".format(
        config['proto'],
        config['domain'],
        config['route']
    )

    # initial curl command
    curl = [
        'curl', '-s', '{0}'.format(url),
    ]

    # add resolve flags to curl command
    if ip:
        curl.extend(['--resolve', '{0}:443:{1}'.format(config['domain'], ip)])

    # write our body to /dev/null
    curl.extend([
        '-o', '/dev/null'
    ])

    # if verbose, print the curl command we're going to use
    if verbose:
        print(" ".join((curl)))

    # Don't print the curl JSON formatting for verbose, as it is not that relevant
    curl.extend([
        '-w', '{"remote_ip": "%{remote_ip}", "time_total": %{time_total}, "http_code": %{http_code}}'
    ])

    # join the output back into a string from a slice[]
    return "".join((cmd(curl)))


def main():
    parser = argparse.ArgumentParser(description='Curl a domain and all of its A records')
    parser.add_argument('url', help='URL to curl, EG: https://google.com')
    parser.add_argument('--verbose', '-v', help='Verbose printing', action='store_true')
    args = parser.parse_args()

    config = parse_url(args.url)

    # only resolve the bare domain as dig(1) will fail if proto:// or /route is
    # specified
    ips = resolve(config['domain'], args.verbose)

    print(curl(config, verbose=args.verbose))
    for ip in ips:
        print(curl(config, ip=ip, verbose=args.verbose))


if __name__ == '__main__':
    main()
