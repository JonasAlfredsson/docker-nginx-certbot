# This is a small helper script used to extract and verify the tag that is to
# be set on the Docker container. This file expects that the GitHub Action
# variable GITHUB_REF is passed in as the one and only argument.

if [ -z "${1}" ]; then
    >&2 echo "Input argument was empty"
    exit 1
fi

app_major=$(echo ${1} | sed -n -r -e 's&^refs/.+/v([1-9])\.[0-9]+\.[0-9]+.*$&\1&p')
app_minor=$(echo ${1} | sed -n -r -e 's&^refs/.+/v[1-9]\.([0-9]+)\.[0-9]+.*$&\1&p')
app_patch=$(echo ${1} | sed -n -r -e 's&^refs/.+/v[1-9]\.[0-9]+\.([0-9]+).*$&\1&p')
nginx_version=$(echo ${1} | sed -n -r -e 's&^refs/.+/.*-nginx([1-9]\.[0-9]+\.[0-9]+)$&\1&p')

if [ -n "${app_major}" -a -n "${app_minor}" -a -n "${app_patch}" -a -n "${nginx_version}" ]; then
    echo "APP_MAJOR=${app_major}"
    echo "APP_MINOR=${app_minor}"
    echo "APP_PATCH=${app_patch}"
    echo "NGINX_VERSION=${nginx_version}"
else
    >&2 echo "Received the following input argument: '${1}'"
    >&2 echo "Could not extract all expected values: v${app_major}.${app_minor}.${app_patch}-${nginx_version}"
    exit 1
fi
