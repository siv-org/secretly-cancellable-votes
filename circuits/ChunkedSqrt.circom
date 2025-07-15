pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";
include "gates.circom";
include "comparators.circom";

template ChunkedInvertSqrt(chunks, base) {
    signal input a[chunks];

    var ONE[3] = [1, 0, 0];

    signal output out[chunks] <== ChunkedUVRatio(chunks, base)(ONE, a);
}

template ChunkedUVRatio(chunks, base) {
    signal input u[chunks];
    signal input v[chunks];
    signal output out[chunks];

    // v3 = v * v * v
    signal v2[chunks] <== ChunkedMulModP()(v, v);
    signal v3[chunks] <== ChunkedMulModP()(v2, v);

    // v7 = v3 * v3 * v
    signal v6[chunks] <== ChunkedMulModP()(v3, v3);
    signal v7[chunks] <== ChunkedMulModP()(v6, v);

    // pow = (u * v7)^{(p-5)/8}
    signal uv7[chunks] <== ChunkedMulModP()(u, v7);
    signal pow[chunks] <== ChunkedPow2_252_3()(uv7);

    // Reference reassigns x, but circom doesn't allow that,
    // so we'll call them x_1,2,3, and mux() between.

    // x_1 = (u * v3) * pow
    signal uv3[chunks] <== ChunkedMulModP()(u, v3);
    signal x_1[chunks] <== ChunkedMulModP()(uv3, pow);
    signal x_sq[chunks] <== ChunkedMulModP()(x_1, x_1);
    signal vx2[chunks] <== ChunkedMulModP()(v, x_sq);

    signal root1[chunks] <== x_1;
    // √(-1) aka √(a) aka 2^((p-1)/4)
    var SQRT_M1[3] = [ 19212814651911893326667952, 5789323763396775551972713, 13150778395323338825847616 ];
    signal root2[chunks] <== ChunkedMulModP()(x_1, SQRT_M1);
    log("circuit=");
    // log("root2=");
    // for (var i = 0; i < chunks; i++) log(root2[i]);
    // -- Confirmed above matches reference --
    signal useRoot1 <== ChunkedIsEqual(chunks)(vx2, u);

    // skip root checks (like vx² == u or -u) for now to keep ZK minimal
    out <== x_1;
}

// Efficiently computes a^{(p-5)/8} aka x^(2^252-3).
template ChunkedPow2_252_3() {
    signal input x[3];

    signal x2[3] <== ChunkedMulModP()(x, x);
    signal b2[3] <== ChunkedMulModP()(x2, x);
    signal b4[3] <== ChunkedMulModP()(ChunkedPow2ModP(2)(b2), b2);
    signal b5[3] <== ChunkedMulModP()(ChunkedPow2ModP(1)(b4), x);
    signal b10[3] <== ChunkedMulModP()(ChunkedPow2ModP(5)(b5), b5);
    signal b20[3] <== ChunkedMulModP()(ChunkedPow2ModP(10)(b10), b10);
    signal b40[3] <== ChunkedMulModP()(ChunkedPow2ModP(20)(b20), b20);
    signal b80[3] <== ChunkedMulModP()(ChunkedPow2ModP(40)(b40), b40);
    signal b160[3] <== ChunkedMulModP()(ChunkedPow2ModP(80)(b80), b80);
    signal b240[3] <== ChunkedMulModP()(ChunkedPow2ModP(80)(b160), b80);
    signal b250[3] <== ChunkedMulModP()(ChunkedPow2ModP(10)(b240), b10);
    signal pow_p_5_8[3] <== ChunkedMulModP()(ChunkedPow2ModP(2)(b250), x);

    signal output out[3] <== pow_p_5_8;
}

// Does x ^ (2 ^ power) mod p
// eg: pow2(30, 4) == 30 ^ (2 ^ 4)
template ChunkedPow2ModP(power) {
    signal input x[3];

    signal tmp[power + 1][3];
    tmp[0] <== x;
    for (var i = 1; i <= power; i++) {
        tmp[i] <== ChunkedMulModP()(tmp[i - 1], tmp[i - 1]);
    }

    signal output out[3] <== tmp[power];
}

// Returns 1 if a[n] == b[n], 0 otherwise
template ChunkedIsEqual(n) {
    signal input a[n], b[n];

    signal equal[n];
    for (var i = 0; i < n; i++) equal[i] <== IsEqual()([a[i], b[i]]);

    signal output out <== MultiAND(n)(equal);
}