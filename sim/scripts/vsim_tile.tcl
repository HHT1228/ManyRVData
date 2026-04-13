# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create group for Tile $1
onerror {resume}

# Add waves for tcdm_mapper and csrs
add wave -noupdate -group tile[$1] -group CSR /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_snitch_cluster_peripheral/*
add wave -noupdate -group tile[$1] -group axi2reqrsp /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[0]/i_axi2reqrsp/*
# Add waves for xbars
add wave -noupdate -group tile[$1] -group narrow_xbar /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_axi_narrow_xbar/*
add wave -noupdate -group tile[$1] -group wide_xbar /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_axi_wide_xbar/*

# Add waces for cache controller
for {set c 0}  {$c < 4} {incr c} {
	onerror {resume}

# 	for {set p 0} {$p < 2} {incr p} {
# 		add wave -noupdate -group tile[$1] -group cache[$c] -group amo[$p] /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_cache_connect[$c]/gen_cache_amo[$p]/i_cache_amo/*
#   }

	# add wave -noupdate -group tile[$1] -group cache[$c] -group coalescer  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_par_coalescer_for_spatz/gen_extend_window/i_par_coalescer_extend_window/i_par_coalescer/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group controller			  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group core			  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/i_insitu_cache_core/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group core			  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/i_insitu_cache_core/NumCacheEntry
	add wave -noupdate -group tile[$1] -group cache[$c] -group core			  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/i_insitu_cache_core/SetAssociativity
	add wave -noupdate -group tile[$1] -group cache[$c] -group core			  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/i_insitu_cache_core/CacheLineWidth
	add wave -noupdate -group tile[$1] -group cache[$c] -group core	-group decoder		  /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/i_insitu_cache_core/i_insitu_cache_decoder/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_ctrl0	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[0]/i_access_ctrl_for_meta/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_ctrl1	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[1]/i_access_ctrl_for_meta/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_ctrl2	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[2]/i_access_ctrl_for_meta/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_ctrl3	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[3]/i_access_ctrl_for_meta/*

	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_0	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[0]/i_cache_meta_bank/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_1	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[1]/i_cache_meta_bank/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_2	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[2]/i_cache_meta_bank/*
	add wave -noupdate -group tile[$1] -group cache[$c] -group meta_3	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[3]/i_cache_meta_bank/*

	add wave -noupdate -group tile[$1] -group cache[$c] -group insitu_wrapper	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/*
	
	add wave -noupdate -group tile[$1] -group cache[$c] -group Internal   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/*

	add wave -noupdate -group tile[$1] -group cache[$c] -group l2_wrapper   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/*

	add wave -noupdate -group tile[$1] -group cache[$c] -group dir_tag_arb   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_tag_bank_req_arb/*

	add wave -noupdate -group tile[$1] -group cache[$c] -group dir_ctrl   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l2_directory_ctrl/*

	add wave -noupdate -group tile[$1] -group cache[$c] -group dir_ctrl   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l2_directory_ctrl/NumCacheEntry
	add wave -noupdate -group tile[$1] -group cache[$c] -group dir_ctrl   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l2_directory_ctrl/SetAssociativity
	add wave -noupdate -group tile[$1] -group cache[$c] -group dir_ctrl   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l2_directory_ctrl/CacheLineWidth

	for {set d 0} {$d < 4} {incr d} {		
		add wave -noupdate -group tile[$1] -group cache[$c] -group tag_access[$d] -group tag_access_ctrl	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l2_directory_ctrl/gen_tag_bank_access[$d]/i_access_ctrl_tag_bank/*
		
		add wave -noupdate -group tile[$1] -group cache[$c] -group tag_access[$d] -group tag_access	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l2_directory_ctrl/gen_tag_bank_access[$d]/i_tag_bank_access/*
	}

	# for {set e 0} {$e < 4} {incr e} {
	# 	add wave -noupdate -group tile[$1] -group cache[$c] -group insitu_tag_acces[$e]	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/i_l1_controller/i_insitu_cache_tcdm_wrapper/gen_cache_banks[3]/i_access_ctrl_for_meta/*
	# }


	# for {set b 0} {$b < 8} {incr b} {
	# 	add wave -noupdate -group tile[$1] -group cache[$c] -group data_bank[$b]   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l1_cache_ctrl[$c]/i_l2_cache/gen_l1_data_banks[$b]/i_data_bank/*
	# }
}

# Add waves for L0 HPDcache
for {set c 0} {$c < 4} {incr c} {
	onerror {resume}

	add wave -noupdate -group tile[$1] -group core_l0_coal[$c]   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache_req_coalescer[$c]/i_core_l0_coalescer/*
}

for {set c 0} {$c < 4} {incr c} {
	onerror {resume}

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group miss_handler	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_miss_handler_i/*
	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group mshr	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_miss_handler_i/hpdcache_mshr_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group cmo	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_cmo_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group ctrl	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group ctrl_pe	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_ctrl_pe_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group mem_ctrl	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_memctrl_i/*

	for {set b 0} {$b < 4} {incr b} {
		add wave -noupdate -group tile[$1] -group l0_cache[$c] -group mem_ctrl -group coh_bank[$b]	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_memctrl_i/gen_dir_sram[$b]/coherence_sram/*
	}

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group mem_ctrl -group victim_sel	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_memctrl_i/victim_sel_i/gen_plru_victim_sel/victim_plru_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group mem_ctrl -group coh_victim_sel	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_memctrl_i/i_coherence_victim_sel/gen_plru_victim_sel/victim_plru_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group rtab	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_rtab_i/*

	# add wave -noupdate -group tile[$1] -group l0_cache[$c] -group mem_ctrl -group dir_access_arb	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_memctrl_i/i_dir_access_arb/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group req_arbiter	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/core_req_arbiter_i/*

	# add wave -noupdate -group tile[$1] -group l0_cache[$c] -group dir_access_arb	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/hpdcache_ctrl_i/hpdcache_memctrl_i/i_dir_access_arb/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group wbuf	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/gen_wbuf/hpdcache_wbuf_i/*

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group Internal   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/core_req_i

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group Internal   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/core_req_ready_o

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group Internal   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/core_rsp_valid_o

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group Internal   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/core_rsp_o

	add wave -noupdate -group tile[$1] -group l0_cache[$c] -group Internal   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_cache[$c]/i_l0_cache/*

}

for {set c 0} {$c < 4} {incr c} {
	onerror {resume}

	add wave -noupdate -group tile[$1] -group l0_l1_arbiters[$c]   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_l1_req_arbiter[$c]/i_l0_l1_rr_arb/*
}

for {set c 0} {$c < 4} {incr c} {
	onerror {resume}

	add wave -noupdate -group tile[$1] -group l0_l1_strbreq_handler[$c]   /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_l0_l1_strb_handling[$c]/i_l0_l1_strbreq_handler/*
}

# for {set c 0} {$c < 5} {incr c} {
#   add wave -noupdate -group tile[$1] -group cache_xbar -group xbar[$c]	/tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/gen_cache_xbar[$c]/i_cache_xbar/*
# }
add wave -noupdate -group tile[$1] -group l0_l1_xbar /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_l0_l1_xbar/*
add wave -noupdate -group tile[$1] -group coherence_xbar /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_coherence_interco/*
add wave -noupdate -group tile[$1] -group coherence_fwd_xbar /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_coherence_fwd_xbar/*

for {set c 0} {$c < 4} {incr c} {
	onerror {resume}
	add wave -noupdate -group tile[$1] -group coherence_fwd_xbar -group fifo[$c] /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_coherence_fwd_xbar/gem_fwd_buffer[$c]/i_l2_l1_fwd_fifo/*
}
# add wave -noupdate -group tile[$1] -group coherence_xbar -rsp_stream_xbar /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/i_coherence_interco/i_coherence_xbar/i_cache_xbar/i_rsp_xbar/*

for {set c 0} {$c < 4} {incr c} {
	onerror {resume}

	# add wave -noupdate -group tile[$1] -group inv_cmo -group l1_inv_fifo[$c] /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/coherence_inv_cmo[$c]/i_l1_inv_fifo/*
	add wave -noupdate -group tile[$1] -group inv_cmo -group l1_coal_fifo[$c] /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/coherence_inv_cmo[$c]/i_l1_coal_fifo/*
	add wave -noupdate -group tile[$1] -group inv_cmo -group l0_req_inv_arb[$c] /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/coherence_inv_cmo[$c]/i_l0_req_inv_arb/*
}

# Add waves for remaining signals
add wave -noupdate -group tile[$1] -group Internal /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/*
add wave -noupdate -group tile[$1] -group Internal /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/l0_cache_rsp_coal

# add wave -noupdate -group tile[$1] -group Internal /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/l0_cache_req_inv
# add wave -noupdate -group tile[$1] -group Internal /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/l0_cache_req_final
# add wave -noupdate -group tile[$1] -group Internal /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/l0_cache_req_coal_buf
# add wave -noupdate -group tile[$1] -group Internal /tb_cachepool/i_cluster_wrapper/i_cluster/gen_tiles[$1]/i_tile/l0_cache_req_inv