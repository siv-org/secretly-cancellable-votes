pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";
include "./ed25519/ChunkedSub.circom";
include "gates.circom";

/** This takes a 6-chunk input and outputs a 3-chunk result, mod P (2^255 - 19) */
template ChunkedModP() {
    signal input in[6]; // Multiplying 2x 3-chunked limbs together => max 6 chunks.

    // Step 1: Fold high limbs by multiplying by 19 and adding to low limbs
    signal fold3 <== ScalarChunkMul(19)(in[3]);
    signal fold4 <== ScalarChunkMul(19)(in[4]);
    signal fold5 <== ScalarChunkMul(19)(in[5]);

    // Add folded values to low limbs with proper carry handling
    signal folded[3], carry0, carry1, carry2;
    (folded[0], carry0) <== ChunkedAddSingle(85)(in[0], fold3);
    (folded[1], carry1) <== ChunkedAddSingle(85)(in[1], fold4 + carry0);
    (folded[2], carry2) <== ChunkedAddSingle(85)(in[2], fold5 + carry1);

    // Step 2: To mod into p, we may need to subtract p:
    signal folded_minus_p[3];
    (folded_minus_p, _) <== ChunkedSub(3, 85)(folded, [(2 ** 85 - 19), (2 ** 85 - 1), (2 ** 85 - 1)]);

    // Need to mod p if:
    // -    the biggest limb overflowed -- carry2
    // - or folded >= p (-19 to 0)
    signal needs_reduction <== OR()(carry2, ChunkedGreaterEqThanP()(folded));

    signal output out[3] <== Multiplexor2(3)(needs_reduction, [folded, folded_minus_p]);
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

/** Checks if a 3-chunk number is >= p (2^255 - 19) */
// There is a small window, congruent from -19 to 0, where this could be true.
template ChunkedGreaterEqThanP() {
    signal input in[3];

    // Check if: the lowest limb >= p's lowest limb
    var p0 = (1 << 85) - 19; // the low limb of p
    signal limb0_gte <== GreaterEqThan(85)([in[0], p0]);

    // Check if: limbs 1 & 2 are full
    var fullLimb = (1 << 85) - 1;
    signal limb1_full <== IsEqual()([in[1], fullLimb]);
    signal limb2_full <== IsEqual()([in[2], fullLimb]);
    signal two_limbs_full <== AND()(limb2_full, limb1_full);

    // Out = 1, if all conditions met
    signal output out <== AND()(two_limbs_full, limb0_gte);
}
