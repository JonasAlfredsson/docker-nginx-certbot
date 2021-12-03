#!/usr/bin/env bats

SCRIPTS_DIR="$(cd -- "${BATS_TEST_DIRNAME}/../src/scripts" &> /dev/null && pwd)"
FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

load "${SCRIPTS_DIR}/util.sh"


@test "is_ipv4 detects what is an IPv6 address" {
  local ipv4addresses=($(<"${FIXTURES_DIR}/ipv4_addresses.txt"))

  for ipv4addr in ${ipv4addresses[@]}; do
    echo "Testing '$ipv4addr'" >&2
    is_ipv4 "$ipv4addr"
  done
}

@test "is_ipv4 detects what is not an IPv6 address" {
  local notipv4addresses=($(<"${FIXTURES_DIR}/not_ip_addresses.txt"))
  notipv4addresses+=($(<"${FIXTURES_DIR}/ipv6_addresses.txt"))

  for notipv4addr in ${notipv4addresses[@]}; do
    echo "Testing '$notipv4addr'" >&2
    ! is_ipv4 "$notipv4addr"
  done
}

@test "is_ipv6 detects what is an IPv6 address" {
  local ipv6addresses=($(<"${FIXTURES_DIR}/ipv6_addresses.txt"))

  for ipv6addr in ${ipv6addresses[@]}; do
    echo "Testing '$ipv6addr'" >&2
    is_ipv6 "$ipv6addr"
  done
}

@test "is_ipv6 detects what is not an IPv6 address" {
  local notipv6addresses=($(<"${FIXTURES_DIR}/not_ip_addresses.txt"))
  notipv6addresses+=($(<"${FIXTURES_DIR}/ipv4_addresses.txt"))

  for notipv6addr in ${notipv6addresses[@]}; do
    echo "Testing '$notipv6addr'" >&2
    ! is_ipv6 "$notipv6addr"
  done
}

@test "is_ip detects what is an IPv4 or an IPv6 address" {
  local ipaddresses=($(<"${FIXTURES_DIR}/ipv4_addresses.txt"))
  ipaddresses+=($(<"${FIXTURES_DIR}/ipv6_addresses.txt"))

  for ipaddr in ${ipaddresses[@]}; do
    echo "Testing '$ipaddr'" >&2
    is_ip "$ipaddr"
  done
}

@test "is_ip detects what is not an IPv4 or an IPv6 address" {
  local notipaddresses=($(<"${FIXTURES_DIR}/not_ip_addresses.txt"))

  for notipaddr in ${notipaddresses[@]}; do
    echo "Testing '$notipaddr'" >&2
    ! is_ip "$notipaddr"
  done
}

@test "parse_config_file works for single server block, single certificate name, single server name" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_server_single_cert_single_name.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 2 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
}

@test "parse_config_file works for single server block, single certificate name, multiple server names" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_server_single_cert_multi_name.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 3 ]
  [ "${server_names[0]}" == "another.example.org" ]
  [ "${server_names[1]}" == "example.org" ]
  [ "${server_names[2]}" == "www.example.org" ]
}

@test "parse_config_file works for single server block, multiple certificate names, single server name" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_server_multi_cert_single_name.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 2 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 2 ]
  [ "${server_names_cert1[0]}" == "example.org" ]
  [ "${server_names_cert1[1]}" == "www.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 2 ]
  [ "${server_names_cert2[0]}" == "example.org" ]
  [ "${server_names_cert2[1]}" == "www.example.org" ]
}

@test "parse_config_file works for multiple server blocks, single certificate name, single server name" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/multi_server_single_cert_single_name.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 3 ]
  [ "${server_names[0]}" == "another.example.org" ]
  [ "${server_names[1]}" == "example.org" ]
  [ "${server_names[2]}" == "www.example.org" ]
}

@test "parse_config_file works for multiple server blocks, multiple certificate names, multiple server names" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/multi_server_multi_cert_multi_name.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 2 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 4 ]
  [ "${server_names_cert1[0]}" == "anew.example.org" ]
  [ "${server_names_cert1[1]}" == "another.example.org" ]
  [ "${server_names_cert1[2]}" == "example.org" ]
  [ "${server_names_cert1[3]}" == "www.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 4 ]
  [ "${server_names_cert1[0]}" == "anew.example.org" ]
  [ "${server_names_cert1[1]}" == "another.example.org" ]
  [ "${server_names_cert1[2]}" == "example.org" ]
  [ "${server_names_cert1[3]}" == "www.example.org" ]

}

@test "parse_config_file supports a single certbot_domain directive" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_certbot_domain_directive.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 1 ]
  [ "${server_names[0]}" == "*.example.org" ]
}

@test "parse_config_file supports multiple certbot_domain directives" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/multi_certbot_domain_directive.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 3 ]
  [ "${server_names[0]}" == "*.example.org" ]
  [ "${server_names[1]}" == "*.sub.example.org" ]
  [ "${server_names[2]}" == "example.org" ]
}

@test "parse_config_file ignores regex names" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/regex_server_names.conf"

  local -A certificates
  parse_config_file "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  echo "${certificates[@]}"
  [ ${#server_names[@]} -eq 5 ]
  [ "${server_names[0]}" == "192.168.0.1" ]
  [ "${server_names[1]}" == "1:2:3:4:5:6:7:8" ]
  [ "${server_names[2]}" == "_" ]
  [ "${server_names[3]}" == "example.org" ]
  [ "${server_names[4]}" == "www.example.org" ]
}

@test "parse_config_file works over multiple files (with duplicates)" {
  local -A certificates
  for conf_file in ${FIXTURES_DIR}/nginx_config/multi_files/*.conf*; do
    parse_config_file "${conf_file}" certificates
  done

  local -p certificates
  [ ${#certificates[@]} -eq 3 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]
  [ -n "${certificates[my-cert3]}" ]

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 3 ]
  [ "${server_names_cert1[0]}" == "anew.example.org" ]
  [ "${server_names_cert1[1]}" == "example.org" ]
  [ "${server_names_cert1[2]}" == "www.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 3 ]
  [ "${server_names_cert2[0]}" == "*.example.com" ]
  [ "${server_names_cert2[1]}" == "anew.example.org" ]
  [ "${server_names_cert2[2]}" == "example.com" ]

  local server_names_cert3=(${certificates[my-cert3]})
  [ ${#server_names_cert3[@]} -eq 4 ]
  [ "${server_names_cert3[0]}" == "*.example.net" ]
  [ "${server_names_cert3[1]}" == "example.net" ]
  [ "${server_names_cert3[2]}" == "new.example.net" ]
  [ "${server_names_cert3[3]}" == "www.example.net" ]
}
