pragma circom 2.2.2;

include "./lt.circom";

template ChunkedMul(m, n, base){
  signal input in1[m], in2[n];
  signal output out[m+n];

  component lt1[m];
  var i;
  for (i = 0; i < m; i++) {
    lt1[i] = LessThanPower(base);
    lt1[i].in <== in1[i];
    lt1[i].out === 1;
  }

  component lt2[n];
  for (i = 0; i < n; i++) {
    lt2[i] = LessThanPower(base);
    lt2[i].in <== in2[i];
    lt2[i].out === 1;
  }

  signal pp[n][m+n-1];
  var j;
  for (i = 0; i < n; i++){
    for (j = 0; j < m+n-1; j++){
      if (j<i){
        pp[i][j] <== 0;
      }
      else if (j>=i && j<=m-1+i){
        pp[i][j] <== in1[j-i] * in2[i];
      }
      else {
        pp[i][j] <== 0;
      }
    }
  }

  var vsum = 0;
  signal sum[m+n-1];
  for (j=0; j<m+n-1; j++){
    vsum = 0;
    for (i=0; i<n; i++){
      vsum = vsum + pp[i][j];
    }
    sum[j] <== vsum;
  }

  signal carry[m+n];
  carry[0] <== 0;
  var power = 2 ** base;
  for (j = 0; j < m+n-1; j++) {
    out[j] <-- (sum[j] + carry[j]) % power;
    carry[j+1] <-- (sum[j] + carry[j]) \ power;
    //Note: removing this line does not change the no of constraints
    sum[j]+carry[j] === carry[j+1] * power + out[j];
  }
  out[m+n-1] <-- carry[m+n-1];

  component lt[m+n];
  for(i = 0; i< m+n; i++) {
    lt[i] = LessThanPower(base);
    lt[i].in <== out[i];
    out[i] * lt[i].out === out[i];
  }
}

/** Assumes 3-limbs of base 85 */
template ChunkedMulModP() {
  signal input in1[3], in2[3];
  signal output out[3] <== ChunkedModP()(ChunkedMul(3, 3, 85)(in1, in2));
}
