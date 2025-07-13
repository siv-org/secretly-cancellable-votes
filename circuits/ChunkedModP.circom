pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";

template ChunkedModP() {
    signal input in[6];
    signal output out[3];

    var i;

    // prepare folds
    component fold3 = ScalarChunkMul(19);
    fold3.in <== in[3];

    component fold4 = ScalarChunkMul(19);
    fold4.in <== in[4];

    component fold5 = ScalarChunkMul(19);
    fold5.in <== in[5];

    // sum low chunks
    component add0 = ChunkedAddSingle(85);
    add0.in1 <== in[0];
    add0.in2 <== fold3.out;

    component add1 = ChunkedAddSingle(85);
    add1.in1 <== in[1];
    add1.in2 <== fold4.out + add0.carry;

    component add2 = ChunkedAddSingle(85);
    add2.in1 <== in[2];
    add2.in2 <== fold5.out + add1.carry;

    signal folded[3];

    // sum low chunks
    folded[0] <== add0.out;
    folded[1] <== add1.out;
    folded[2] <== add2.out;

    // finally reduce if folded >= p
    component finalReduce = ChunkedSubModP(3, 85);
    for (i = 0; i < 3; i++) {
        finalReduce.a[i] <== folded[i];
        finalReduce.b[i] <== 0;  // compare against p inside ChunkedSubModP
    }
    for (i = 0; i < 3; i++) {
        out[i] <== finalReduce.out[i];
    }
}

/** Because the chunks are ≤ 2^85, multiplying by 19 means:
`19 * 2^85 ≈ 2^89`
So it can fit in a slightly wider chunk (or can be reduced by carry into next limb if needed).
For now, since we’re only folding these back into an addition, we can just multiply and let the next ChunkedAddSingle take care of overflow. */
template ScalarChunkMul(scalar) {
    signal input in;
    signal output out;

    out <== in * scalar;
}


template ChunkedAddSingle(chunkBits) {
    signal input in1;
    signal input in2;
    signal output out;

    var power = 2 ** chunkBits;
    signal output carry;

    carry <-- (in1 + in2) \ power;
    out   <-- (in1 + in2) % power;

    // Enforce modular relationship
    in1 + in2 === out + carry * power;

    // Constrain range of out
    component lt = LessThanPower(chunkBits);
    lt.in <== out;
    out * lt.out === out;
}
