# Nvjorn [![Deps Status](https://beta.hexfaktor.org/badge/all/github/tchoutri/Nvjorn.svg)](https://beta.hexfaktor.org/github/tchoutri/Nvjorn)

A network services monitor written in Elixir using Poolboy.

### Supported services

- [x] HTTP
    - [x] Started
    - [x] Finished
- [ ] SSH
    - [x] Started
    - [ ] Finished
- [x] ICMP
    - [x] Started
    - [x] Finished
- [x] FTP
    - [x] Started
    - [x] Finished
- [ ] SOCKS5
    - [ ] Started
    - [ ] Finished
- [ ] ???

### Configuration

See [config.exs](config/config.exs).

#### Concerning `gen_icmp`

Please read [this page about the icmp socket capability](https://github.com/msantos/procket#setuid-vs-sudo-vs-capabilities)

(TL;DR → `setcap cap_net_raw=ep /usr/lib/erlang/erts-8.0/bin/beam.smp` [or whatever is your `erts` version] as root or using `sudo`)

### Services List

See [README.services.md](priv/README.services.md).

### Running it

```Shell
mix run --sname nvjorn --no-halt
```
