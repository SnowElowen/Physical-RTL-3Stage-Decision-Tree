set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_project]

create_project deterministic_tree_4stage_verified $project_dir \
    -part xczu15eg-ffvb1156-2-i -force

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

add_files -fileset sources_1 [list \
    [file join $script_dir deterministic_tree_4stage.sv] \
    [file join $script_dir deterministic_tree_4stage_verify_top.sv]]

add_files -fileset sim_1 [list \
    [file join $script_dir tb_deterministic_tree_4stage_verify_top.sv]]

add_files -fileset constrs_1 [list \
    [file join $script_dir deterministic_tree_4stage_verify_top.xdc]]

set_property file_type SystemVerilog \
    [get_files deterministic_tree_4stage.sv]
set_property file_type SystemVerilog \
    [get_files deterministic_tree_4stage_verify_top.sv]
set_property file_type SystemVerilog \
    [get_files tb_deterministic_tree_4stage_verify_top.sv]

set_property top deterministic_tree_4stage_verify_top [get_filesets sources_1]
set_property top tb_deterministic_tree_4stage_verify_top [get_filesets sim_1]

puts "DESIGN TOP = [get_property top [get_filesets sources_1]]"
puts "SIM TOP    = [get_property top [get_filesets sim_1]]"

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
save_project_as deterministic_tree_4stage_verified $project_dir -force
