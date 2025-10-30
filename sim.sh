#!/bin/bash
# If no argument is provided
if [[ $# -lt 1 ]]; then
    ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b-single_M1024
fi

# Take the first argument as the command
cmd="$1"
shift  # shift so $@ now contains only extra args for the command

case "$cmd" in
    fdotp_single_core)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b-single_M1024
        ;;
    fdotp_small)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b_M1024
        ;;
    fdotp_large)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b_M8192
        ;;
    fdotp_xlarge)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-fdotp-32b_M32768
        ;;
    idopt_small)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-idotp-32b_M1024
        ;;
    idopt_xlarge)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-idotp-32b_M32768
        ;;
    ls)
        ./sim/bin/cachepool_cluster.vsim.gui ./software/build/CachePoolTests/test-cachepool-load-store_M16
        ;;
    *)
        echo "Unknown command: $cmd"
        ;;
esac
