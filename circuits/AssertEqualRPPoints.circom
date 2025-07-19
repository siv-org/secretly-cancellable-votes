pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";
include "gates.circom";
include "./ChunkedSqrt.circom";

/** RistrettoPoints (& their under-the-hood Extended Form) have multiple representations (XYZT coords) for the same canonical point.
This func is a much cheaper check for equality of two points,
compared to encoding them to their canonical form. */
template AssertEqualRPPoints() {
  signal input p1[4][3], p2[4][3];

  var x = 0, y = 1;

  // const one = mod(a.x * b.y) === mod(a.y * b.x)
  signal X1Y2[3] <== ChunkedMulModP()(p1[x], p2[y]);
  signal Y1X2[3] <== ChunkedMulModP()(p1[y], p2[x]);
  signal one <== ChunkedIsEqual(3)(X1Y2, Y1X2);

  // const two = mod(a.y * b.y) === mod(a.x * b.x)
  signal Y1Y2[3] <== ChunkedMulModP()(p1[y], p2[y]);
  signal X1X2[3] <== ChunkedMulModP()(p1[x], p2[x]);
  signal two <== ChunkedIsEqual(3)(Y1Y2, X1X2);

  // (x1 * y2 == y1 * x2) | (y1 * y2 == x1 * x2)
  signal result <== OR()(one, two);
  result === 1; // Assert at least one of the two conditions passed
}
