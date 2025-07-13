pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";
include "./ed25519/ChunkedSub.circom";

/** This takes a 6-chunk input and outputs a 3-chunk result, mod P (2^255 - 19) */
template ChunkedModP() {
    signal input in[6];

    // Step 1: Fold high limbs by multiplying by 19 and adding to low limbs
    signal fold3 <== ScalarChunkMul(19)(in[3]);
    signal fold4 <== ScalarChunkMul(19)(in[4]);
    signal fold5 <== ScalarChunkMul(19)(in[5]);

    // Add folded values to low limbs with proper carry handling
    signal add0, carry0;
    (add0, carry0) <== ChunkedAddSingle(85)(in[0], fold3);

    signal add1, carry1;
    (add1, carry1) <== ChunkedAddSingle(85)(in[1], fold4 + carry0);

    signal add2, carry2;
    (add2, carry2) <== ChunkedAddSingle(85)(in[2], fold5 + carry1);

    // Create intermediate signals for the folded result
    signal folded[3] <== [add0, add1, add2];

    // Step 2: Handle potential overflow in the last limb
    // If carry2 > 0, we need to subtract p (2^255 - 19)
    signal diff[3];
    (diff, _) <== ChunkedSub(3, 85)(folded, [(2 ** 85 - 19), (2 ** 85 - 1), (2 ** 85 - 1)]);

    signal needs_reduction <== carry2;
    signal output out[3] <== Multiplexor2(3)(needs_reduction, [folded, diff]);
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


template ChunkedAddSingle(base) {
    signal input in1;
    signal input in2;
    signal output out;

    var power = 2 ** base;
    signal output carry;

    carry <-- (in1 + in2) \ power;
    out   <-- (in1 + in2) % power;

    // Enforce modular relationship
    in1 + in2 === out + carry * power;

    // Constrain range of out
    component lt = LessThanPower(base);
    lt.in <== out;
    out * lt.out === out;
}
