# This is a small helper script used to extract and verify the tag that is to
# be set on the Docker container. This file expects that the GitHub Action
# variable GITHUB_REF is passed in as the one and only argument.

if [ -z "${1}" ]; then
    echo "Input argument was empty"
    exit 1
fi

app_version=$(echo ${1} | sed -n -r -e 's&^refs/.+/v([1-9]\.[0-9]+\.[0-9]+).*$&\1&p')
nginx_version=$(echo ${1} | sed -n -r -e 's&^refs/.+/.*-nginx([1-9]\.[0-9]+\.[0-9]+)$&\1&p')

if [ -n "${app_version}" -a -n "${nginx_version}" ]; then
    echo "::set-output name=APP_VERSION::${app_version}"
    echo "::set-output name=NGINX_VERSION::${nginx_version}"
else
    echo "Could not extract all expected values:"
    echo "APP_VERSION=${app_version}"
    echo "NGINX_VERSION=${nginx_version}"
    exit 1
fi
