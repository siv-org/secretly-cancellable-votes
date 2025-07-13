pragma circom 2.2.2;

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
    signal input a[3], b[3];

    // 1. Get difference: a - b
    signal diff[3], underflow;
    (diff, underflow) <== ChunkedSub(3, 85)(a, b);

    // 2. If underflow (a < b), add p (2^255 - 19)
    var p[3] = [2 ** 85 - 19, 2 ** 85 - 1, 2 ** 85 - 1];
    signal with_p[4] <== ChunkedAdd(3, 2, 85)([diff, p]);

    // 3. Select between orig diff & with_p
    signal output out[3] <== Multiplexor2(3)(underflow, [diff, [with_p[0], with_p[1], with_p[2]]]);
    // `with_p` has an extra 4th limb, but we ignore it,
    // because the underflow implies it's empty.
}

template ModSub(base) {
  signal input a, b;
  signal output borrow <== LessThanBounded(base)([a, b]);
  signal output out <== borrow * (1 << base) + a - b;
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