# dank-selfhosted

<img src="https://i.imgur.com/A46hkpd.gif" width="300">

Hi! This is my ansible playbook for self-hosting your own email, web hosting, XMPP chat,
and DNS records using [OpenBSD](https://www.openbsd.org/). I use it to host everything on
[c0ffee.net](https://www.c0ffee.net), but you can easily adapt it for your own domain by
setting a few variables in `vars.yml`.

## TLDR

1. Configure a [secondary DNS provider](https://cp.dnsmadeeasy.com/u/122648) and set them as your nameservers at your registrar. Set up reverse DNS for your server.
2. `./scripts/bootstrap_openbsd.sh`
3. `cp vars-sample.yml vars.yml && vi vars.yml`
4. `ansible-playbook site.yml`
5. `./scripts/ds_records.sh YOURDOMAIN` and set DS records at your registrar for DNSSEC.

## Assumptions

- You have a public-facing server (probably a VPS) running OpenBSD, with an IPv4 and IPv6 address. I recommend [Vultr](https://www.vultr.com/?ref=6845125).
- You have your own domain name, and a registrar that supports DNSSEC. I recommend [Namecheap](https://affiliate.namecheap.com/?affId=108349).
- You have a secondary DNS provider that supports DNSSEC. I recommend [DNS Made Easy](https://cp.dnsmadeeasy.com/u/122648). ([Why do I need this?](https://www.c0ffee.net/blog/dns-hidden-master/))
- You're crazy enough to run your own mail server :-)

## Goals

- A small and secure OpenBSD platform to host email, DNS, XMPP chat, and some web sites.
    - **Scale:** you and your family members, and maybe a few technically oriented friends.
    - Really not suited for the general public, no automated password reset, no web GUIs...

- Use as much of the OpenBSD base system as possible:
    - [acme-client(1)](https://man.openbsd.org/acme-client.1) for [LetsEncrypt](https://letsencrypt.org/) certificates
    - [smtpd(8)](https://man.openbsd.org/smtpd.8) for mail handling
    - [spamd(8)](https://man.openbsd.org/spamd) for spam filtering
    - [nsd(8)](https://man.openbsd.org/nsd.8) for authoritative DNS server
    - [httpd(8)](https://man.openbsd.org/httpd.8) for web server
    - basic [passwd(5)](https://man.openbsd.org/passwd.5) authentication for all services (maybe I should look into [ldapd(8)](https://man.openbsd.org/ldapd.8)?)

- Of course, some packages from the ports tree will be necessary:
    - [prosody](http://prosody.im/) for XMPP chat
    - [postgresql](https://www.postgresql.org/) for Prosody data storage
    - [ldns-utils](https://www.nlnetlabs.nl/projects/ldns/about/) for DNSSEC zone signing
    - [dovecot](https://dovecot.org/) for IMAP access
    - [dkimproxy](http://dkimproxy.sourceforge.net/) for [DKIM](http://www.dkim.org/) signing of outgoing mail

- Encryption Everywhere:
    - Automated DNSSEC with `nsd` and cron tasks using `ldns-signzone` for daily zone re-signing and slave `NOTIFYs`
    - TLS for all public-facing services using LetsEncrypt certificates with automated renewal and daemon reload hooks
    - Automatic publishing of [SSHFP](https://tools.ietf.org/html/rfc4255) records for authoritative SSH fingerprints
    - Automatic publishing of [TLSA](https://tools.ietf.org/html/rfc6698) records for [DANE email encryption](https://halon.io/blog/what-is-dane/)
    - Automatic publishing of DKIM records for outgoing email verification

- Keep it Simple
    - Unopinionated baseline for what most people want from a personal domain
    - Keep dependencies to a minimum and stick to UNIX conventions (simple `passwd` auth, mail stored in `~/Maildir`, etc)
    - Automate the tedious stuff, so you can focus on hacking!

## Usage

1. Boot up your OpenBSD server.
2. Create at least one user account. You will use this account to administer the system, so make sure to add yourself to the `wheel` group.
3. Run `scripts/bootstrap_openbsd.sh` as root to add a package repo URL and set up [doas](http://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man1/doas.1) for your user (required for Ansible).
4. Configure your secondary DNS provider to accept `NOTIFYs` and perform zone transfers from your server's IP address.
5. `cp vars-sample.yml vars.yml` and edit the configuration to your liking.
6. Run the playbook! `ansible-playbook site.yml`
7. Ensure you have reverse DNS in place for your server's IP address. This is a critical step to avoid your outgoing mail being flagged as spam. At Vultr, this is configured under "Settings > IPv4". You should set one for your primary IPv6 address as well.
8. The last step is to configure DS records for DNSSEC at your domain registrar. Run `scripts/ds_records.sh YOURDOMAIN` to generate the records. At Namecheap, this is configured under "Advanced DNS > DNSSEC" in the web portal.
9. Yell at me on [Twitter](https://twitter.com/cullumsmith) when you inevitably find bugs in my code.

## Operational Notes

- **Login info:** the credentials for SMTP (STARTTLS, port 587) and IMAP (SSL, port 993) are simply your username (*without* the @domain.com portion) and login password. XMPP uses the `username@domain.com` syntax for logins, but the password is the same. Mail is stored under `~/Maildir` in each user's home directory for easy access using local clients like `mutt`.

- **Email Filtering**: add a [sieve script](https://wiki2.dovecot.org/Pigeonhole/Sieve/Examples) to `~/.dovecot.sieve` to apply filters to your incoming mail.

- **XMPP Chat:** the XMPP server, Prosody, is really slick. As configured here, it supports HTTP file upload for image sharing, delivery to multiple devices via carbons, push notifications, group chats, message history, and basically everything you'd expect from a modern chat solution. XMPP isn't all that bad! The best clients are [ChatSecure](https://chatsecure.org/) for iOS, [Conversations](https://conversations.im/) for Android, and [Gajim](https://gajim.org/) for *nix and Windows. No decent clients for OS X, sadly. All those clients support end-to-end crypto via [OMEMO](https://conversations.im/omemo/). Easily federate with others on separate XMPP servers for truly decentralized, open communication!

- **Additional accounts**: to add more accounts, just use `adduser`. Unless they need a shell, it's probably best to set their shell to `/sbin/nologin`.

- **IPv6:** `spamd` does not currently support IPv6, so don't go adding a AAAA record for `mail` in the zonefile!

- **Monitoring spamd**: just run `spamdb` to see a list of senders currently greylisted/whitelisted.

- **Virtual Hosts**: a default vhost will be created for `www.domain.com`, with a bare domain redirect. Shove HTML files into `/var/www/htdocs/www.domain.com` to start sharing your worthless opinions with the internet! To add more vhosts, just put a configuration file in `/etc/sites` and include it in `/etc/httpd.d/sites.conf`.

- **Greylisting pitfalls:** `spamd` works by [greylisting](https://www.greylisting.org/). Unfortunately, big mailers like GMail often don't retry delivery from the same address, resulting in a greylist black hole described [here](https://poolp.org/posts/2018-01-08/spfwalk/). To alleviate this, I included a daily cron job that whitelists the IP addresses found in the SPF records for some of the big mailers like GMail and Yahoo. If you notice any other problematic domains, override the to the `bigmailers` list defined in [roles/spamd/deaults/main.yml](roles/spamd/defaults/main.yml) to have their IP ranges whitelisted. (And be sure to send me a pull request!)

- **Password Resets:** I'm leaving password management up to you. Since this configuration uses plain UNIX accounts, you won't be able to add a password reset webpage without some kind of crappy setuid CGI script (yikes!). Look into LDAP authentication if you have a bunch of non-neckbeard users. Otherwise, `man login.conf` for information on enforcing password expiration and complexity.

## Resources

- [How to Run Your Own Mail Server](https://www.c0ffee.net/blog/mail-server-guide/): my original email guide. Written for FreeBSD, but still lots of great info about mail hosting. [HN Discussion](https://news.ycombinator.com/item?id=16238937)

- [DNS Hosting Guide: Hidden Master with DNSSEC](https://www.c0ffee.net/blog/dns-hidden-master/): my original guide for running your own DNS. Again, written for FreeBSD, but gives a lot of details about why you'd want a hidden master setup.
