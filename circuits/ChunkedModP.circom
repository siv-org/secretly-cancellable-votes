pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";
include "./ed25519/ChunkedSub.circom";
include "gates.circom";

/** This takes a 6-chunk input and outputs a 3-chunk result, mod P (2^255 - 19) */
template ChunkedModP() {
    signal input in[6]; // Multiplying 2x 3-chunked limbs together => max 6 chunks.

    /** 1. Modulo p is how many times p divides in[6] (510-bits).
           Each p division leaves a residue of 19.
           Thus, we can fold the high limbs into our 3-chunk base limbs,
              by multiplying each by 19, and adding to low limbs.
           With proper carry handling:
            Because our chunks are 85-bits, multiplying by 19 means:
            `19 * 2^85 ≈ 2^89`, so the extra 4-bits of overflow need to be added to the next limb. */
    signal folded[3], overflow0, overflow1, overflow2;
    (folded[0], overflow0) <== ChunkedAddSingle(85)(in[0], 19 * in[3]);
    (folded[1], overflow1) <== ChunkedAddSingle(85)(in[1], 19 * in[4] + overflow0);
    (folded[2], overflow2) <== ChunkedAddSingle(85)(in[2], 19 * in[5] + overflow1);

    /** 2. But we may still have overflow, and need to subtract p one last time: */
    signal folded_minus_p[3];
    (folded_minus_p, _) <== ChunkedSub(3, 85)(folded, [(2 ** 85 - 19), (2 ** 85 - 1), (2 ** 85 - 1)]);

    /** 2b. Use our folded_minus_p if: */
    signal needs_reduction <== OR()(
        overflow2, // the biggest limb overflowed
        ChunkedGreaterEqThanP()(folded) // or folded >= p (-19 to 0)
    );

    signal output out[3] <== Multiplexor2(3)(needs_reduction, [folded, folded_minus_p]);
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
// There is a small window, congruent (-19 to 0), where this could be true.
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
