pragma circom 2.0.0;

include "chunkedmul.circom";
include "chunkedadd.circom";
include "ChunkedSub.circom";
include "mux1.circom";

template ModulusWith25519Chunked51(n) {
  signal input in[n];
  signal output out[3];

  var i;
  var base=85;

  component mod2p;
  component mul;
  component mod;
  component adder;
  component mod2pfinal;

  if (n < 3) {
    for (i = 0; i < n; i++) {
      out[i] <== in[i];
    }

    for (i = n; i < 3; i++) {
      out[i] <== 0;
    }
  } else {
    mod2p = ModulusAgainst2PChunked51();
    for (i = 0; i < 3; i++) {
      mod2p.in[i] <== in[i];
    }

    mod2p.in[3] <== 0;

    mul = ChunkedMul(n-3, 1, base);
    for(i = 0; i < n-3; i++) {
      mul.in1[i] <== in[3+i];
    }

    mul.in2[0] <== 19;

    mod = ModulusWith25519Chunked51(n-3+1);
    for (i = 0; i < n-3+1; i++) {
      mod.in[i] <== mul.out[i];
    }

    adder = ChunkedAdd(3, 2, base);
    for (i = 0; i < 3; i++) {
      adder.in[0][i] <== mod2p.out[i];
      adder.in[1][i] <== mod.out[i];
    }

    mod2pfinal = ModulusAgainst2PChunked51();
    for (i = 0; i < 4; i++) {
      mod2pfinal.in[i] <== adder.out[i];
    }

    for (i = 0; i < 3; i++) {
      out[i] <== mod2pfinal.out[i];
    }
  }
}

template ModulusAgainst2PChunked51() {
  signal input in[4];
  signal output out[3];
  var i;
  var p[4] = [38685626227668133590597613, 38685626227668133590597631, 38685626227668133590597631, 0];
  var base = 85;

  component sub = ChunkedSub(4, base);

  in[3] * (in[3] - 1) === 0;
  for (i = 0; i < 4; i++) {
    sub.a[i] <== in[i];
    sub.b[i] <== p[i];
  }

  component mux = MultiMux1(4);
  for (i = 0; i < 4; i++) {
    mux.c[i][0] <== in[i];
    mux.c[i][1] <== sub.out[i];
  }

  mux.s <== 1 + sub.underflow - 2*sub.underflow;
  for (i = 0; i < 3; i++) {
    out[i] <== mux.out[i];
  }
}
