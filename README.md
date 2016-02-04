# Nvjorn

A network services monitor written in Elixir using Poolboy.

### Supported services

- [x] HTTP
- [ ] SSH
- [ ] ICMP
- [ ] FTP
- [ ] SOCKS5
- [ ] ???

### Configuration

See [config.exs](config/config.exs).

#### Concerning `gen_icmp`

Please read [this page about the icmp socket capability](https://github.com/msantos/procket#setuid-vs-sudo-vs-capabilities)

### Services List

See [README.services.md](priv/README.services.md).
