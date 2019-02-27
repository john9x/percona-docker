#!/bin/bash
set -eo pipefail

dir="$(dirname "$(realpath "$BASH_SOURCE")")"

image="$1"

export MYSQL_ROOT_PASSWORD='this is an example test password'
export MYSQL_USER='0123456789012345' # "ERROR: 1470  String 'my cool mysql user' is too long for user name (should be no longer than 16)"
export MYSQL_PASSWORD='my cool mysql password'
export MYSQL_DATABASE='my cool mysql database'

cname="mysql-container-$RANDOM-$RANDOM"
cid="$(
	docker run -d \
		-e MYSQL_ROOT_HOST="host-$RANDOM" \
		-e MYSQL_ROOT_PASSWORD \
		-e MYSQL_USER \
		-e MYSQL_PASSWORD \
		-e MYSQL_DATABASE \
		--name "$cname" \
		"$image"
)"
trap "docker rm -vf $cid > /dev/null" EXIT

# connect as MYSQL_USER, needed for retry.sh
mysql() {
	docker run --rm -i \
		--link "$cname":mysql \
		--entrypoint mysql \
		-e MYSQL_PWD="$MYSQL_PASSWORD" \
		"$image" \
		-hmysql \
		-u"$MYSQL_USER" \
		--silent \
		"$@" \
		"$MYSQL_DATABASE"
}
. "$dir/../../retry.sh" --tries 20 "echo 'SELECT 1' | mysql"

# connect as root user, needed for hostname check
mysql_root() {
	docker run --rm -i \
		--link "$cname":mysql \
		--entrypoint mysql \
		-e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
		"$image" \
		-hmysql \
		-uroot \
		--silent \
		"$@" \
		"$MYSQL_DATABASE" \
		2>&1
}
[[ $(echo 'SELECT 1' | mysql_root) =~ ^'ERROR 1045 (28000): Access denied for user' ]]
