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

@test "parse_config_files_for_certs works for single server block, single server name, single certificate name" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_server_single_name_single_cert.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates
  
  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 2 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
}

@test "parse_config_files_for_certs works for single server block, multiple server names, single certificate name" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_server_multi_name_single_cert.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  
  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 3 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
  [ "${server_names[2]}" == "another.example.org" ]
}

@test "parse_config_files_for_certs works for single server block, single server name, multiple certificate names" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/single_server_single_name_multi_cert.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
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

@test "parse_config_files_for_certs works for multiple server blocks, single server name, single certificate name" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/multi_server_single_name_single_cert.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 3 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
  [ "${server_names[2]}" == "another.example.org" ]
}

@test "parse_config_files_for_certs works for multiple server blocks, multiple server names, multiple certificate names" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/multi_server_multi_name_multi_cert.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 2 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 4 ]
  [ "${server_names_cert1[0]}" == "example.org" ]
  [ "${server_names_cert1[1]}" == "www.example.org" ]
  [ "${server_names_cert1[2]}" == "another.example.org" ]
  [ "${server_names_cert1[3]}" == "anew.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 1 ]
  [ "${server_names_cert2[0]}" == "anew.example.org" ]
}

@test "parse_config_files_for_certs supports wildcards" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/wildcard_with_conflict.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates
  
  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 3 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
  [ "${server_names[2]}" == "*.example.org" ]
}

@test "parse_config_files_for_certs filters out unsupported server names (regex, suffix wildcards, catchall, etc.)" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/unsupported_server_names.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates
  
  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 2 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
}

@test "parse_config_files_for_certs supports the cert:add_domains directive" {
  local fixture="${FIXTURES_DIR}/nginx_config/single_files/cert_add_domains_directive.conf"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates
  
  [ ${#certificates[@]} -eq 1 ]
  [ -n "${certificates[my-cert]}" ]

  local server_names=(${certificates[my-cert]})
  [ ${#server_names[@]} -eq 5 ]
  [ "${server_names[0]}" == "example.org" ]
  [ "${server_names[1]}" == "www.example.org" ]
  [ "${server_names[2]}" == "another.example.org" ]
  [ "${server_names[3]}" == "*.example.org" ]
  [ "${server_names[4]}" == "anew.example.org" ]
}

@test "parse_config_files_for_certs works over multiple files" {
  local fixture="${FIXTURES_DIR}/nginx_config/multi_files/*.conf*"

  local -A certificates
  parse_config_files_for_certs "${fixture}" certificates
  local -p certificates

  [ ${#certificates[@]} -eq 3 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]
  [ -n "${certificates[my-cert3]}" ]

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 4 ]
  [ "${server_names_cert1[0]}" == "example.org" ]
  [ "${server_names_cert1[1]}" == "www.example.org" ]
  [ "${server_names_cert1[2]}" == "another.example.org" ]
  [ "${server_names_cert1[3]}" == "anew.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 3 ]
  [ "${server_names_cert2[0]}" == "anew.example.org" ]
  [ "${server_names_cert2[1]}" == "example.com" ]
  [ "${server_names_cert2[2]}" == "*.example.com" ]

  local server_names_cert3=(${certificates[my-cert3]})
  [ ${#server_names_cert3[@]} -eq 2 ]
  [ "${server_names_cert3[0]}" == "example.net" ]
  [ "${server_names_cert3[1]}" == "*.example.net" ]
}

@test "remove_duplicates does not add or remove any certificate name" {
  local -A certificates
  certificates[my-cert1]="server1 server2 server3 server1 server4"
  certificates[my-cert2]="server2 server1"

  remove_duplicates certificates
  local -p certificates

  [ ${#certificates[@]} -eq 2 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]
}

@test "remove_duplicates removes duplicate server names in a cert" {
  local -A certificates
  certificates[my-cert1]="server1 server2 server3 server1 server4"
  certificates[my-cert2]="server2 server1"

  remove_duplicates certificates
  local -p certificates

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 4 ]
  [ "${server_names_cert1[0]}" == "server1" ]
  [ "${server_names_cert1[1]}" == "server2" ]
  [ "${server_names_cert1[2]}" == "server3" ]
  [ "${server_names_cert1[3]}" == "server4" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 2 ]
  [ "${server_names_cert2[0]}" == "server2" ]
  [ "${server_names_cert2[1]}" == "server1" ]
}

@test "handle_wildcard_conflicts does not add or remove any certificate name" {
  local -A certificates
  certificates[my-cert1]="a.example.org a.example.com b.example.org *.example.org b.a.example.org"
  certificates[my-cert2]="a.example.org *.a.example.org c.a.example.org"

  handle_wildcard_conflicts certificates
  local -p certificates

  [ ${#certificates[@]} -eq 2 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]
}

@test "handle_wildcard_conflicts removes server names from a cert that already has a wildcard covering them" {
  local -A certificates
  certificates[my-cert1]="a.example.org a.example.com b.example.org *.example.org b.a.example.org"
  certificates[my-cert2]="a.example.org *.a.example.org c.a.example.org"

  handle_wildcard_conflicts certificates
  local -p certificates

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 3 ]
  [ "${server_names_cert1[0]}" == "a.example.com" ]
  [ "${server_names_cert1[1]}" == "*.example.org" ]
  [ "${server_names_cert1[2]}" == "b.a.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 2 ]
  [ "${server_names_cert2[0]}" == "a.example.org" ]
  [ "${server_names_cert2[1]}" == "*.a.example.org" ]
}

@test "force_wildcards does not add or remove any certificate name" {
  local -A certificates
  certificates[my-cert1]="a.example.org a.example.com b.example.org b.a.example.org"
  certificates[my-cert2]="a.example.org d.a.example.org c.a.example.org b.example.com c.example.com"
  certificates[my-cert3.no-wildcards]="a.example.net b.example.net c.example.net"

  export FORCE_WILDCARDS=1
  force_wildcards certificates
  local -p certificates

  [ ${#certificates[@]} -eq 3 ]
  [ -n "${certificates[my-cert1]}" ]
  [ -n "${certificates[my-cert2]}" ]
  [ -n "${certificates[my-cert3.no-wildcards]}" ]
}

@test "force_wildcards collapses server names in all certs when FORCE_WILDCARDS is set to 1, except if 'no-wildcards' in the cert name" {
  local -A certificates
  certificates[my-cert1]="a.example.org a.example.com b.example.org b.a.example.org"
  certificates[my-cert2]="a.example.org d.a.example.org c.a.example.org b.example.com c.example.com"
  certificates[my-cert3.no-wildcards]="a.example.net b.example.net c.example.net"

  export FORCE_WILDCARDS=1
  force_wildcards certificates
  local -p certificates

  local server_names_cert1=(${certificates[my-cert1]})
  [ ${#server_names_cert1[@]} -eq 3 ]
  [ "${server_names_cert1[0]}" == "*.example.org" ]
  [ "${server_names_cert1[1]}" == "a.example.com" ]
  [ "${server_names_cert1[2]}" == "b.a.example.org" ]

  local server_names_cert2=(${certificates[my-cert2]})
  [ ${#server_names_cert2[@]} -eq 3 ]
  [ "${server_names_cert2[0]}" == "a.example.org" ]
  [ "${server_names_cert2[1]}" == "*.a.example.org" ]
  [ "${server_names_cert2[2]}" == "*.example.com" ]

  local server_names_cert3=(${certificates[my-cert3.no-wildcards]})
  [ ${#server_names_cert3[@]} -eq 3 ]
  [ "${server_names_cert3[0]}" == "a.example.net" ]
  [ "${server_names_cert3[1]}" == "b.example.net" ]
  [ "${server_names_cert3[2]}" == "c.example.net" ]
}

@test "force_wildcards only collapses the server names of cert names with 'force-wildcards' if FORCE_WILDCARDS is set to 0" {
  local -A certificates
  certificates[my-cert1.force-wildcards]="a.example.org a.example.com b.example.org b.a.example.org"
  certificates[my-cert2.force-wildcards]="a.example.org d.a.example.org c.a.example.org b.example.com c.example.com"
  certificates[my-cert3]="a.example.net b.example.net c.example.net"

  export FORCE_WILDCARDS=0
  force_wildcards certificates
  local -p certificates

  local server_names_cert1=(${certificates[my-cert1.force-wildcards]})
  [ ${#server_names_cert1[@]} -eq 3 ]
  [ "${server_names_cert1[0]}" == "*.example.org" ]
  [ "${server_names_cert1[1]}" == "a.example.com" ]
  [ "${server_names_cert1[2]}" == "b.a.example.org" ]

  local server_names_cert2=(${certificates[my-cert2.force-wildcards]})
  [ ${#server_names_cert2[@]} -eq 3 ]
  [ "${server_names_cert2[0]}" == "a.example.org" ]
  [ "${server_names_cert2[1]}" == "*.a.example.org" ]
  [ "${server_names_cert2[2]}" == "*.example.com" ]

  local server_names_cert3=(${certificates[my-cert3]})
  [ ${#server_names_cert3[@]} -eq 3 ]
  [ "${server_names_cert3[0]}" == "a.example.net" ]
  [ "${server_names_cert3[1]}" == "b.example.net" ]
  [ "${server_names_cert3[2]}" == "c.example.net" ]
}

