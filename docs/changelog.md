# Changelog

### 2.3.0
- Add support for [ECDSA][27] certificates.
  - It is possible to have Nginx serve both ECDSA and RSA certificates at the
    same time for the same server. Read more in its
    [good to know section](./good_to_know.md#ecdsa-and-rsa-certificates).
- Made so that the the "primary domain"/"cert name" can be
  [whatever](./good_to_know.md#how-the-script-add-domain-names-to-certificate-requests)
  you want.
  - This was actually already possible from [`v0.12`](#012), but it is first
    now we allow it.

### 2.2.0
- Listen to IPv6 in the [redirector.conf](../src/nginx_conf.d/redirector.conf)
  in addition to IPv4.
  - PR by [@staticfloat][25].
- Add `reuseport` in the [redirector.conf](../src/nginx_conf.d/redirector.conf),
  which improves latency and parallelization.
  - PR by [@staticfloat][26].
- Add mentions in the changelog to people who have helped with issues.

### 2.1.0
- Made the `create_dhparams.sh` script capable of creating missing directories.
  - Our small [`/docker-entrypoint.d/40-create-dhparam-folder.sh`][17] script
    is therefore no longer necessary.
- Made so that we run `symlink_user_configs` at startup so we do not run into
  a [race condition][16] with Nginx.
- Some minor cleanup in the Dockerfiles related to the above changes.

### 2.0.1
- There now exist a Dockerfile for building from the Nginx Alpine image as well.
  - It is possible to use the Alpine version by appending `-alpine` to any
    of the tags from now on.
  - There are now so many tags available, see
    [dockerhub_tags.md](./dockerhub_tags.md) for the possible combinations.
  - NOTE: There exists a bug in Bash 5.1.0, which is described in detail
    [here][15].
  - Suggested by [@tudddorrr][24].
- Small fix to the `create_dhparams.sh` script to handle the use of libressl
  in Alpine.
- Added a small sleep in order to mitigate a rare race condition between Nginx
  startup and the symlink script.
- Fix an ugly printout in the case when the sleep function exited naturally.

### 2.0.0
- Big change on how we recommend users to get their `.conf` files into the
  container.
  - Created a script that [creates symlinks][10] from `conf.d/` to the files
    in `user_conf.d/`.
  - Users can now [start the container](../README.md#run-with-docker-run)
    without having to build anything.
  - Still compatible with [the old way](../README.md#build-it-yourself), but I
    still think it's a "major" change.
  - Suggested by [@MauriceNino][23].
- Examples are updated to reflect changes.
- Add more logging.
- Add more `"` around variables for extra safety.
- Big overhaul of how the documentation is structured.
- Even more tags now available on Docker Hub!
  - See [dockerhub_tags.md](./dockerhub_tags.md) for the list.

### 1.3.0
- Ignore values starting with `data:` and `engine:` when verifying that all
  files exists.
  - PR by [@bblanchon][1].
- Add a debug mode which is enabled by setting the environment variable
  `DEBUG=1`.

### 1.2.0
- Fix dependencies so that it is possible to build in 32-bit ARM architectures.
  - Reported by [RtKelleher][11].
- Added [Dependabot][20] to monitor and update the Dockerfiles.
  - PR by [@odin568][19].
- Added [GitHub Actions/Workflows](../.github/workflows) so that each [tag][2]
  now is built for multiple arches ([issue #28][3]).

### 1.1.0
- Fix that scripts inside [`/docker-entrypoint.d/`][4] were never run
  ([issue #21][5]).
  - Found while helping [@isomerpages][21] move from @staticfloats image.
- Fix for issue where the script failed in case the `/etc/letsencrypt/dhparams`
  folder was missing.
  - Reported by [@pmkyl][6].

### 1.0.0
- Move over to [semantic versioning][7].
  - The version number will now be given like this: `[MAJOR].[MINOR].[PATCH]`
  - This is done to signify that I feel like this code is stable, since I have
    been running this for quite a while.
- Build from a defined version of Nginx.
  - This is done to facilitate a way to lock this container to a more specific
    version.
  - This also allows us to more often trigger rebuilds of this container on
    Docker Hub.
- New tags are available on [Docker Hub][2].
  - There will now be tags on the following form:
    - latest
    - 1.0.0
    - 1.0.0-nginx1.19.7

### 0.16
- Container now listens to [`SIGHUP`](./advanced_usage.md#manualforce-renewal)
  and will reload all configs if this signal is received.
  - More details can be found in the commit message: [bf2c135][13]
- Made Docker image slightly smaller by including `--no-install-recommends`.
- There is now also a [`dev` branch][9]/tag if you are brave and want to run
  experimental builds.
- [JonasAlfredsson/docker-nginx-certbot][22] is now its own independent
  repository (i.e. no longer just a fork).

### 0.15
- It is now possible to
  [manually trigger](./advanced_usage.md#manualforce-renewal) a renewal of
  certificates.
  - It is also possible to include "force" to add `--force-renewal` to the
    request.
- The "clean exit" trap now handle that parent container changed to
  [`SIGQUIT`][12] as stop signal.
- The "certbot" server block (in Nginx) now prints to stdout by default.
- Massive refactoring of both code and files:
  - Our "start **command**" file is now called `start_nginx_certbot.sh` instead
    of `entrypoint.sh`.
  - Both `create_dhparams.sh` and `run_certbot.sh` can now be run by themselves
    inside the container.
  - I have added `set -e` in most of the files so the program exit as intended
    when unexpected errors occurs.
  - Added `{}` and `""` around most of the bash variables.
  - Change some log messages and where they appear.
- Our `/scripts/startup/` folder has been removed.
  - The parent container will run any `*.sh` file found inside the
    [`/docker-entrypoint.d/`][4] folder.

### 0.14
- Made so that the container now exits gracefully and reports the correct exit
  code.
  - More details can be found in the commit message: [43dde6e][8]
- Bash script now correctly monitors **both** the Nginx and the certbot renewal
  process PIDs.
  - If either one of these processes dies, the container will exit with the same
    exit code as that process.
  - This will also trigger a graceful exit for the rest of the processes.
- Removed unnecessary and empty `ENTRYPOINT` from Dockerfile.
- A lot of refactoring of the code, cosmetic changes and editing of comments.

### 0.13
- Fixed the regex used in all of the `sed` commands.
  - Now makes sure that the proper amount of spaces are present in the right
    places.
  - Now allows comments at the end of the lines in the configs. `# Nice!`
  - Made the expression a little bit more readable thanks to the `-r` flag.
- Now made certbot solely responsible for checking if the certificates needs to
  be renewed.
  - Certbot is actually smart enough to not send any renewal requests if it
    doesn't have to.
- The time interval used to trigger the certbot renewal check is now user
  configurable.
  - The environment variable to use is `RENEWAL_INTERVAL`.

### 0.12
- Added `--cert-name` flag to the certbot certificate request command.
  - This allows for both adding and subtracting domains to the same certificate
    file.
  - Makes it possible to have path names that are not domain names (but this
    is not allowed yet).
- Made the file parsing functions smarter so they only find unique file paths.
- Cleaned up some log output.
- Updated the `docker-compose` example.
- Fixed some spelling in the documentation.

### 0.11
- Python 2 is EOL, so it's time to move over to Python 3.
- From now on [Docker Hub][2] will also automatically build with tags.
  - Lock the version by specifying the tag: `jonasal/nginx-certbot:0.11`

### 0.10
- Update to new ACME v2 servers.
  - PR by [@seaneshbaugh][18].

### 0.9
- I am now confident enough to remove the version suffixes.
- `nginx:mainline` is now using Debian 10 Buster.
- Updated documentation.

### 0.9-gamma
- Make both Nginx and the update script child processes of the `entrypoint.sh`
  script.
- Container will now die along with Nginx like it should.
- The Diffie-Hellman parameters now have better permissions.
- Container now exist on [Docker Hub][2] under `jonasal/nginx-certbot:latest`
- More documentation.

### 0.9-beta
- `@JonasAlfredsson` enters the battle.
- Diffie-Hellman parameters are now automatically generated.
- Nginx now handles everything HTTP related -> certbot set to webroot mode.
- Better checking to see if necessary files exist.
- Will now request a certificate that includes all domain variants listed
  on the `server_name` line.
- More extensive documentation.

### 0.8
- Ditch cron, it never liked me anyway.  Just use `sleep` and a `while`
  loop instead.

### 0.7
- Complete rewrite, build this image on top of the `nginx` image, and run
  `cron`/`certbot` alongside `nginx` so that we can have Nginx configs
  dynamically enabled as we get SSL certificates.

### 0.6
- Add `nginx_auto_enable.sh` script to `/etc/letsencrypt/` so that users can
  bring Nginx up before SSL certs are actually available.

### 0.5
- Change the name to `docker-certbot-cron`, update documentation, strip out
  even more stuff I don't care about.

### 0.4
- Rip out a bunch of stuff because `@staticfloat` is a monster, and likes to
  do things his way

### 0.3
- Add support for webroot mode.
- Run certbot once with all domains.

### 0.2
- Upgraded to use certbot client
- Changed image to use alpine linux

### 0.1
- Initial release







[1]: https://github.com/JonasAlfredsson/docker-nginx-certbot/pull/32
[2]: https://hub.docker.com/r/jonasal/nginx-certbot
[3]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/28
[4]: https://github.com/nginxinc/docker-nginx/tree/master/entrypoint
[5]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/21
[6]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/20
[7]: https://semver.org/
[8]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/43dde6ec24f399fe49729b28ba4892665e3d7078
[9]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/dev
[10]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/91f8ecaa613f1e7c0dc4ece38fa8f38a004f61ec
[11]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/24
[12]: https://github.com/nginxinc/docker-nginx/commit/3fb70ddd7094c1fdd50cc83d432643dc10ab6243
[13]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/bf2c1354f55adffadc13b1f1792e205f9dd25f86

[15]: https://github.com/JonasAlfredsson/bash_fail-to-wait
[16]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/7c5e2108c89c9da5effda1c499fff6ff84f8b1d3
[17]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/9dfa927cda7244768445067993dc42e23b4e78da
[18]: https://github.com/JonasAlfredsson/docker-nginx-certbot/pull/11
[19]: https://github.com/JonasAlfredsson/docker-nginx-certbot/pull/22
[20]: https://dependabot.com/
[21]: https://github.com/isomerpages/isomer-redirection/pull/143
[22]: https://github.com/JonasAlfredsson/docker-nginx-certbot
[23]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/33
[24]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/35
[25]: https://github.com/JonasAlfredsson/docker-nginx-certbot/pull/44
[26]: https://github.com/JonasAlfredsson/docker-nginx-certbot/pull/45
[27]: https://sectigostore.com/blog/ecdsa-vs-rsa-everything-you-need-to-know/
[28]: https://github.com/JonasAlfredsson/docker-nginx-certbot/blob/master/docs/good_to_know.md#ecdsa-and-rsa-certificates
[29]: https://github.com/JonasAlfredsson/docker-nginx-certbot/blob/master/docs/good_to_know.md#how-the-script-add-domain-names-to-certificate-requests
