#!/bin/bash
# If no argument is provided
if [[ $# -lt 1 ]]; then
    ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b-single_M1024
fi

# Take the first argument as the command
cmd="$1"
shift  # shift so $@ now contains only extra args for the command

case "$cmd" in
    rebuild)
        make clean init generate config=cachepool_fpu_512 vsim
        ;;
    rebuild_sw)
        make clean.sw sw config=cachepool_fpu_512
        ;;
    fdotp_single_core)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b-single_M1024
        ;;
    fdotp_single_core_large)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b-single_M8192
        ;;
    fdotp_1k)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b_M1024
        ;;
    fdotp_8k)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b_M8192
        ;;
    fdotp_32k)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b_M32768
        ;;
    idopt_1024)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-idotp-32b_M1024
        ;;
    idopt_32k)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-idotp-32b_M32768
        ;;
    ls)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-load-store_M16
        ;;
    ls_single)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-load-store-single_M8
        ;;
    fmatmul_32)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fmatmul-32b_M32_N32_K32
        ;;
    fmatmul_64)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fmatmul-32b_M64_N64_K64
        ;;
    fmatmul_128)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fmatmul-32b_M128_N128_K128
        ;;
    gemv_128)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-gemv-col_M128_N128_K32
        ;;
    gemv_256)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-gemv-col_M256_N128_K32
        ;;
    gemv_512)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-gemv-col_M512_N128_K32
        ;;
    *)
        echo "Unknown command: $cmd"
        ;;
esac
