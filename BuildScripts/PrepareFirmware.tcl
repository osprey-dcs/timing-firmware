open_project EVG.xpr

generate_target -force -verbose {instantiation_template synthesis} [get_files EVG/EVG.srcs/sources_1/bd/bd/bd.bd]
