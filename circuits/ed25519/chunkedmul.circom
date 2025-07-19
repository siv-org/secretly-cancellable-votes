pragma circom 2.2.2;

include "./lt.circom";
include "../ChunkedModP.circom";

template ChunkedMul(m, n, base){
  signal input in1[m], in2[n];
  signal output out[m+n];

  var cols = m + n - 1;

  // Confirm all input limbs are less than 2^base
  AssertAllChunksAreLessThanPower(base, m)(in1);
  AssertAllChunksAreLessThanPower(base, n)(in2);

  var i, j;
  // Compute PartialProducts table (chunk-level cross multiplications)
   // m=3 x n=4 example => 6 total columns (m + n - 1)
   // Enough total cols needed for all n's to shift up to (i - 1) spots
   //     0     1     2     3     4     5  <- j = 6 cols
   // +-----------------------------------
   // 0 | p0,0  p0,1  p0,2  p0,3  0     0
   // 1 | 0     p1,0  p1,1  p1,2  p1,3  0
   // 2 | 0     0     p2,0  p2,1  p2,2  p2,3
   // i = 3 rows
  signal pp[n][cols];
  for (i = 0; i < n; i++) {
    for (j = 0; j < cols; j++) {
      if (j < i) {
        pp[i][j] <== 0; // bottom left triangle
      } else if (j <= m + i - 1) { // shift up to (i - 1) spots
        pp[i][j] <== in1[j - i] * in2[i];
      } else {
        pp[i][j] <== 0; // top right triangle
      }
    }
  }

  var vsum = 0;
  signal sum[cols];
  for (j = 0; j < cols; j++) {
    vsum = 0;
    for (i = 0; i < n; i++) {
      vsum += pp[i][j];
    }
    sum[j] <== vsum;
  }

  signal carry[m+n];
  carry[0] <== 0;
  var power = 2 ** base;
  for (j = 0; j < cols; j++) {
    out[j] <-- (sum[j] + carry[j]) % power;
    carry[j+1] <-- (sum[j] + carry[j]) \ power;
    //Note: removing this line does not change the no of constraints
    sum[j]+carry[j] === carry[j+1] * power + out[j];
  }
  out[cols] <-- carry[cols];

  component lt[m+n];
  for(i = 0; i< m+n; i++) {
    lt[i] = LessThanPower(base);
    lt[i].in <== out[i];
    out[i] * lt[i].out === out[i];
  }
}

// Confirm all input limbs are less than 2^base
template AssertAllChunksAreLessThanPower(base, chunks) {
  signal input in[chunks];
  signal lt[chunks];
  for (var i = 0; i < chunks; i++) {
    lt[i] <== LessThanPower(base)(in[i]);
    lt[i] === 1;
  }
}

/** Assumes 3-limbs of base 85 */
template ChunkedMulModP() {
  signal input in1[3], in2[3];
  signal output out[3] <== ChunkedModP()(ChunkedMul(3, 3, 85)(in1, in2));
}
