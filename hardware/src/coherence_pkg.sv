// Author: Ho Tin Hung

package coherence_pkg;

  typedef enum logic [1:0] {
    CACHE_INVALID   = 2'b00,
    CACHE_SHARED    = 2'b01,
    CACHE_EXCLUSIVE = 2'b10,
    CACHE_MODIFIED  = 2'b11
  } l0_line_state_t;

  // Typedefs for cache coherence
  // typedef enum logic [1:0] {
  //   INV       = 2'b00,
  //   GET       = 2'b01,
  //   INV_ACK   = 2'b10,
  //   GET_ACK   = 2'b11
  // } fwd_msg_type_t;

endpackage : coherence_pkg