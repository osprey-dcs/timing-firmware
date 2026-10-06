open_project EVG.xpr

reset_target {all} [get_files EVG.srcs/sources_1/bd/bd/bd.bd]
reset_target {all} [get_files EVG.srcs/sources_1/ip/mgt/mgt.xci]

upgrade_ip [get_ips]

validate_ip -verbose [get_ips]

generate_target -force -verbose {all} [get_files EVG.srcs/sources_1/bd/bd/bd.bd]
generate_target -force -verbose {all} [get_files EVG.srcs/sources_1/ip/mgt/mgt.xci]
