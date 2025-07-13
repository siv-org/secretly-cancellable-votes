pragma circom 2.0.0;
include "./lt.circom";

template ChunkedSub(k, base) {
  signal input a[k];
  signal input b[k];
  signal output out[k];
  signal output underflow;

  component unit0 = ModSub(base);
  unit0.a <== a[0];
  unit0.b <== b[0];
  out[0] <== unit0.out;

  component unit[k - 1];
  for (var i = 1; i < k; i++) {
    unit[i - 1] = ModSubThree(base);
    unit[i - 1].a <== a[i];
    unit[i - 1].b <== b[i];
    if (i == 1) {
        unit[i - 1].c <== unit0.borrow;
    } else {
        unit[i - 1].c <== unit[i - 2].borrow;
    }
    out[i] <== unit[i - 1].out;
  }
  underflow <== unit[k - 2].borrow;
}

template ChunkedSubModP() {
    signal input a[3];
    signal input b[3];
    signal output out[3];

    // p = 2^255 - 19, chunked
    var p_chunks[3] = [2 ** 85 - 19, 2 ** 85 - 1, 2 ** 85 - 1];

    component sub = ChunkedSub(3, 85);
    for (var i = 0; i < 3; i++) {
        sub.a[i] <== a[i];
        sub.b[i] <== b[i];
    }

    // Always add p if underflow
    component p_add = ChunkedAdd(3, 2, 85);
    for (var i = 0; i < 3; i++) {
        p_add.in[0][i] <== sub.out[i];
        p_add.in[1][i] <== p_chunks[i]; // p represented in k chunks of base bits
    }

    component mux = Multiplexor2(3);
    mux.sel <== sub.underflow;
    for (var i = 0; i < 3; i++) {
        mux.in[0][i] <== sub.out[i];       // no underflow, keep result
        mux.in[1][i] <== p_add.out[i];     // underflow, add p
    }

    out <== mux.out;
}

template ModSub(base) {
  signal input a;
  signal input b;
  signal output out;
  signal output borrow;
  component lt = LessThanBounded(base);
  lt.in[0] <== a;
  lt.in[1] <== b;
  borrow <== lt.out;
  out <== borrow * (1 << base) + a - b;
}

template ModSubThree(base) {
  signal input a;
  signal input b;
  signal input c;
  assert(a - b - c + (1 << base) >= 0);
  signal output out;
  signal output borrow;
  signal b_plus_c;
  b_plus_c <== b + c;
  component lt = LessThanBounded(base+1);
  lt.in[0] <== a;
  lt.in[1] <== b_plus_c;
  borrow <== lt.out;
  out <== borrow * (1 << base) + a - b_plus_c;
}