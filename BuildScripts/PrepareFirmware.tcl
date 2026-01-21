open_project EVG.xpr

# The first time through, the DCP files are not present.
# However, vivado will barf if they are still referenced :(
# Will be automatically re-added after a successful run.
foreach dcp [get_files -quiet -filter file_type=="Design\ Checkpoint"] {
    if {[get_property IS_AVAILABLE $dcp] == 0} {
        puts "Remove reference to missing DCP $dcp"
        remove_files $dcp
    } else {
        puts "Found DCP: $dcp"
    }
}

validate_ip -verbose [get_ips]

generate_target all [get_files *.bd]
generate_target all [get_files "*/*.srcs/sources_1/ip/*/*.xci"]

#generate_target -force -verbose {instantiation_template synthesis} [get_files /home/developer/src/EVG/EVG.srcs/sources_1/bd/bd/bd.bd]
