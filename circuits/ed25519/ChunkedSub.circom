pragma circom 2.2.2;

include "./lt.circom";
include "./chunkedadd.circom";

template ChunkedSub(k, base) {
  signal input a[k], b[k];
  signal output out[k];

  // Subtract `a - b`, borrowing from previous limb as needed
  signal borrow[k + 1];
  borrow[0] <== 0; // First limb can't borrow
  for (var i = 0; i < k; i++)
    (borrow[i + 1], out[i]) <== ModSubThree(base)(a[i], b[i], borrow[i]);

  // Underflow bit
  signal output underflow <== borrow[k];
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
    signal output out[3] <== ChunkedMultiplexor2(3)(underflow, [diff, [with_p[0], with_p[1], with_p[2]]]);
    // `with_p` has an extra 4th limb, but we ignore it,
    // because the underflow implies it's empty.
}

template ModSubThree(base) {
  signal input a, b, c;
  assert(a - b - c + (1 << base) >= 0);

  signal output borrow <== LessThanBounded(base+1)([a, b + c]);
  signal output out <== borrow * (1 << base) + a - b - c;
}