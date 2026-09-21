open_project EVG.xpr

upgrade_ip [get_ips]

validate_ip -verbose [get_ips]

generate_target -force -verbose {all} [get_files EVG.srcs/sources_1/bd/bd/bd.bd]
