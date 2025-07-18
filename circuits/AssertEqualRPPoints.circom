pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";

/** RistrettoPoints (& their under-the-hood Extended Form) have multiple representations (XYZT coords) for the same canonical point.
This func is a much cheaper check for equality of two points,
compared to encoding them to their canonical form. */
template AssertEqualRPPoints() {
  signal input p1[4][3], p2[4][3];

  var x = 0, y = 1, z = 2;

  // X1Z2 === X2Z1
  signal X1Z2[3] <== ChunkedMulModP()(p1[x], p2[z]);
  signal X2Z1[3] <== ChunkedMulModP()(p2[x], p1[z]);
  X1Z2 === X2Z1;

  // Y1Z2 === Y2Z1
  signal Y1Z2[3] <== ChunkedMulModP()(p1[y], p2[z]);
  signal Y2Z1[3] <== ChunkedMulModP()(p2[y], p1[z]);  
  Y1Z2 === Y2Z1;
}
