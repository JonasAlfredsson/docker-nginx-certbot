# Changelog

### 1.3.0
- Ignore values starting with `data:` and `engine:` when verifying that all
  files exists ([pull request 32][1]).
- Add a debug mode which is enabled by setting the environment variable
  `DEBUG=1`.

### 1.2.0
- Fix dependencies so that it is possible to build in 32-bit ARM architectures
  ([issue #24][11]).
- Added [GitHub Actions/Workflows][workflows] so that each [tag][2]
  now is built for multiple arches ([issue #28][3]).

### 1.1.0
- Fix that scripts inside [`/docker-entrypoint.d/`][4] were never run
  ([issue #21][5]).
- Fix for issue where the script failed in case the `/etc/letsencrypt/dhparams`
  folder was missing ([issue #20][6]).

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
- Container now listens to [`SIGHUP`][manualforce-renewal] and will reload
  all configs if this signal is received.
  - More details can be found in the commit message: [bf2c135][18]
- Made Docker image slightly smaller by including `--no-install-recommends`.
- There is now also a [`dev` branch][9]/tag if you are brave and want to run
  experimental builds.
- JonasAlfredsson/docker-nginx-certbot is now its own independent repository
  (i.e. no longer just a fork).

### 0.15
- It is now possible to [manually trigger][manualforce-renewal] a renewal of
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






[run-with-docker-run]: https://github.com/JonasAlfredsson/docker-nginx-certbot#run-with-docker-run
[build-it-yourself]: https://github.com/JonasAlfredsson/docker-nginx-certbot#build-it-yourself
[workflows]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/.github/workflows
[manualforce-renewal]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#manualforce-renewal

[1]: https://github.com/JonasAlfredsson/docker-nginx-certbot/pull/32
[2]: https://hub.docker.com/r/jonasal/nginx-certbot/tags?page=1&ordering=last_updated
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
